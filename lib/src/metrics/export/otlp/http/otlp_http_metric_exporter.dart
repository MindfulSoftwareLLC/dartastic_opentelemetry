// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/metrics/export/otlp/metric_transformer.dart';
import 'package:http/http.dart' as http;

import '../../../../../proto/collector/metrics/v1/metrics_service.pb.dart';
import '../../../../../proto/metrics/v1/metrics.pb.dart' as metrics_pb;
import '../../../../util/zip/gzip.dart';

/// An OpenTelemetry metric exporter that exports metrics using OTLP over HTTP/protobuf
class OtlpHttpMetricExporter implements MetricExporter {
  static const _retryableStatusCodes = [
    429, // Too Many Requests
    503, // Service Unavailable
  ];

  final OtlpHttpMetricExporterConfig _config;
  bool _isShutdown = false;
  final Random _random = Random();
  final List<Future<void>> _pendingExports = [];

  /// Creates a new OTLP HTTP metric exporter with the specified configuration.
  /// If no configuration is provided, default settings will be used.
  /// 
  /// @param config Optional configuration for the exporter
  OtlpHttpMetricExporter([OtlpHttpMetricExporterConfig? config])
      : _config = config ?? OtlpHttpMetricExporterConfig();

  Duration _calculateJitteredDelay(int retries) {
    final baseMs = _config.baseDelay.inMilliseconds;
    final delay = baseMs * pow(2, retries);
    final jitter = _random.nextDouble() * delay;
    return Duration(milliseconds: (delay + jitter).toInt());
  }

  String _getEndpointUrl() {
    // Ensure the endpoint ends with /v1/metrics
    String endpoint = _config.endpoint;
    if (!endpoint.endsWith('/v1/metrics')) {
      // Ensure there's no trailing slash before adding path
      if (endpoint.endsWith('/')) {
        endpoint = endpoint.substring(0, endpoint.length - 1);
      }
      endpoint = '$endpoint/v1/metrics';
    }
    return endpoint;
  }

  @override
  Future<bool> export(MetricData metrics) async {
    if (_isShutdown) {
      throw StateError('Exporter is shutdown');
    }

    if (metrics.metrics.isEmpty) {
      if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: No metrics to export');
      return true;
    }

    if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Beginning export of ${metrics.metrics.length} metrics');

    try {
      final result = await _export(metrics);
      if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Export completed successfully');
      return result;
    } catch (e) {
      if (_isShutdown && e is StateError && e.message.contains('shut down during')) {
        // Gracefully handle the case where shutdown interrupted the export
        if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Export was interrupted by shutdown, suppressing error');
        return false;
      } else {
        // Re-throw other errors
        rethrow;
      }
    }
  }

  Future<bool> _export(MetricData metrics) async {
    if (_isShutdown) {
      throw StateError('Exporter was shut down during export');
    }

    if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Attempting to export ${metrics.metrics.length} metrics to ${_config.endpoint}');

    var attempts = 0;
    final maxAttempts = _config.maxRetries + 1; // Initial attempt + retries

    while (attempts < maxAttempts) {
      // Allow the export to continue even during shutdown, so we complete in-flight requests
      final wasShutdownDuringRetry = _isShutdown;

      try {
        // Only check for shutdown on retry attempts to ensure in-progress exports can complete
        if (wasShutdownDuringRetry && attempts > 0) {
          if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Export interrupted by shutdown');
          throw StateError('Exporter was shut down during export');
        }

        final success = await _tryExport(metrics);
        if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Successfully exported metrics');
        return success;
      } on http.ClientException catch (e, stackTrace) {
        if (OTelLog.isError()) OTelLog.error('OtlpHttpMetricExporter: HTTP error during export: $e');
        if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');

        // Check if the exporter was shut down while we were waiting
        if (wasShutdownDuringRetry) {
          if (OTelLog.isError()) OTelLog.error('OtlpHttpMetricExporter: Export interrupted by shutdown');
          throw StateError('Exporter was shut down during export');
        }

        // Handle status code-based retries
        bool shouldRetry = false;
        if (e.message.contains('status code')) {
          for (final code in _retryableStatusCodes) {
            if (e.message.contains('status code $code')) {
              shouldRetry = true;
              break;
            }
          }
        }

        if (!shouldRetry) {
          if (OTelLog.isError()) OTelLog.error('OtlpHttpMetricExporter: Non-retryable HTTP error, stopping retry attempts');
          return false;
        }

        if (attempts >= maxAttempts - 1) {
          if (OTelLog.isError()) OTelLog.error('OtlpHttpMetricExporter: Max attempts reached ($attempts out of $maxAttempts), giving up');
          return false;
        }

        final delay = _calculateJitteredDelay(attempts);
        if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Retrying export after ${delay.inMilliseconds}ms...');
        await Future<void>.delayed(delay);
        attempts++;
      } catch (e, stackTrace) {
        if (OTelLog.isError()) OTelLog.error('OtlpHttpMetricExporter: Unexpected error during export: $e');
        if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');

        // Check if we should stop retrying due to shutdown
        if (wasShutdownDuringRetry) {
          throw StateError('Exporter was shut down during export');
        }

        if (attempts >= maxAttempts - 1) {
          return false;
        }

        final delay = _calculateJitteredDelay(attempts);
        if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Retrying export after ${delay.inMilliseconds}ms...');
        await Future<void>.delayed(delay);
        attempts++;
      }
    }

    return false;
  }

  Future<bool> _tryExport(MetricData metrics) async {
    if (_isShutdown) {
      throw StateError('Exporter is shutdown');
    }

    if (OTelLog.isLogMetrics()) {
      OTelLog.logMetric("Exporting metrics via HTTP: ${metrics.metrics.length} metrics");
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpHttpMetricExporter: Preparing to export ${metrics.metrics.length} metrics');
    }

    if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Transforming metrics');

    // Create the export request
    final request = ExportMetricsServiceRequest();
    final resourceMetrics = metrics_pb.ResourceMetrics();

    // Add resource
    if (metrics.resource != null) {
      resourceMetrics.resource = MetricTransformer.transformResource(metrics.resource!);
    } else {
      resourceMetrics.resource = MetricTransformer.transformResource(OTel.resource(null));
    }

    // Create scope metrics
    final scopeMetrics = metrics_pb.ScopeMetrics();

    // Add instrumentation scope
    scopeMetrics.scope.name = '@dart/dartastic_opentelemetry';
    scopeMetrics.scope.version = '1.0.0';

    // Add metrics to scope
    for (final metric in metrics.metrics) {
      scopeMetrics.metrics.add(MetricTransformer.transformMetric(metric));
    }

    // Add scope metrics to resource metrics
    resourceMetrics.scopeMetrics.add(scopeMetrics);

    // Add resource metrics to request
    request.resourceMetrics.add(resourceMetrics);

    if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Successfully transformed metrics');

    // Prepare headers
    final headers = Map<String, String>.from(_config.headers);
    headers['Content-Type'] = 'application/x-protobuf';

    if (_config.compression) {
      headers['Content-Encoding'] = 'gzip';
    }

    // Convert protobuf to bytes
    final Uint8List messageBytes = request.writeToBuffer();
    Uint8List bodyBytes = messageBytes;

    // Apply gzip compression if configured
    if (_config.compression) {
      final gzip = GZip();
      final compressedBytes = await gzip.compress(messageBytes);
      bodyBytes = Uint8List.fromList(compressedBytes);
    }

    // Get the endpoint URL with the correct path
    final endpointUrl = _getEndpointUrl();
    if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Sending export request to $endpointUrl');

    try {
      final http.Response response = await http.post(
        Uri.parse(endpointUrl),
        headers: headers,
        body: bodyBytes,
      ).timeout(_config.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Export request completed successfully');
        return true;
      } else {
        final String errorMessage = 'OtlpHttpMetricExporter: Export request failed with status code ${response.statusCode}';
        if (OTelLog.isError()) OTelLog.error(errorMessage);
        throw http.ClientException(errorMessage);
      }
    } catch (e, stackTrace) {
      if (OTelLog.isError()) {
        OTelLog.error('OtlpHttpMetricExporter: Export request failed: $e');
        OTelLog.error('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  @override
  Future<bool> forceFlush() async {
    if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Force flush requested');
    if (_isShutdown) {
      if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Exporter is already shut down, nothing to flush');
      return true;
    }

    // Wait for any pending export operations to complete
    if (_pendingExports.isNotEmpty) {
      if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Waiting for ${_pendingExports.length} pending exports to complete');
      try {
        await Future.wait(_pendingExports);
        if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: All pending exports completed');
        return true;
      } catch (e) {
        if (OTelLog.isError()) OTelLog.error('OtlpHttpMetricExporter: Error during force flush: $e');
        return false;
      }
    } else {
      if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: No pending exports to flush');
      return true;
    }
  }

  @override
  Future<bool> shutdown() async {
    if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Shutdown requested');
    if (_isShutdown) {
      return true;
    }
    if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Shutting down - waiting for ${_pendingExports.length} pending exports');

    // Set shutdown flag first
    _isShutdown = true;

    // Create a safe copy of pending exports to avoid concurrent modification
    final pendingExportsCopy = List<Future<void>>.of(_pendingExports);

    // Wait for pending exports but don't start any new ones
    // Use a timeout to prevent hanging if exports take too long
    if (pendingExportsCopy.isNotEmpty) {
      if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Waiting for ${pendingExportsCopy.length} pending exports with timeout');
      try {
        // Use a generous timeout but don't wait forever
        await Future.wait(pendingExportsCopy).timeout(const Duration(seconds: 10), onTimeout: () {
          if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Timeout waiting for exports to complete');
          return Future.value([]);
        });
        return true;
      } catch (e) {
        if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Error during shutdown while waiting for exports: $e');
        return false;
      }
    }

    if (OTelLog.isDebug()) OTelLog.debug('OtlpHttpMetricExporter: Shutdown complete');
    return true;
  }
}
