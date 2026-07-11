// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;
import 'package:http/http.dart' as http;

import '../../../../export/otlp_http_protocol.dart';
import '../../../../export/otlp_json.dart';
import '../../../../util/zip/gzip.dart';
import '../../../span.dart';
import '../../../span_logger.dart';
import '../../span_exporter.dart';
import '../span_transformer.dart';
import 'http_client_factory.dart';
import 'otlp_http_span_exporter_config.dart';

/// An OpenTelemetry span exporter that exports spans using OTLP over HTTP/protobuf
class OtlpHttpSpanExporter implements SpanExporter {
  static const _retryableStatusCodes = [
    429, // Too Many Requests
    503, // Service Unavailable
  ];

  final OtlpHttpExporterConfig _config;
  bool _isShutdown = false;
  final Random _random = Random();
  final List<Future<void>> _pendingExports = [];
  late final http.Client _client;

  /// Creates a new OTLP HTTP span exporter with the specified configuration.
  /// If no configuration is provided, default settings will be used.
  ///
  /// @param config Optional configuration for the exporter
  OtlpHttpSpanExporter([OtlpHttpExporterConfig? config])
      : _config = config ?? OtlpHttpExporterConfig() {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
        'OtlpHttpSpanExporter: Created with endpoint: ${_config.endpoint}',
      );
      OTelLog.debug(
        'OtlpHttpSpanExporter: Configured headers count: ${_config.headers.length}',
      );
      _config.headers.forEach((key, value) {
        if (key.toLowerCase() == 'authorization') {
          OTelLog.debug('  $key: [REDACTED - length: ${value.length}]');
        } else {
          OTelLog.debug('  $key: $value');
        }
      });
    }
    _client = _createHttpClient();
  }

  /// Creates an HTTP client with custom certificates if configured.
  ///
  /// Delegated to a platform-conditional factory: native gets an
  /// `IOClient` wrapping an `HttpClient` with a custom `SecurityContext`;
  /// web gets a `BrowserClient` (the browser handles TLS).
  http.Client _createHttpClient() => createOtlpHttpClient(
        exporterName: 'OtlpHttpSpanExporter',
        certificate: _config.certificate,
        clientKey: _config.clientKey,
        clientCertificate: _config.clientCertificate,
      );

  Duration _calculateJitteredDelay(int retries) {
    final baseMs = _config.baseDelay.inMilliseconds;
    final delay = baseMs * pow(2, retries);
    final jitter = _random.nextDouble() * delay;
    return Duration(milliseconds: (delay + jitter).toInt());
  }

  String _getEndpointUrl() {
    // Ensure the endpoint ends with /v1/traces
    var endpoint = _config.endpoint;
    if (!endpoint.endsWith('/v1/traces')) {
      // Ensure there's no trailing slash before adding path
      if (endpoint.endsWith('/')) {
        endpoint = endpoint.substring(0, endpoint.length - 1);
      }
      endpoint = '$endpoint/v1/traces';
    }
    return endpoint;
  }

  Future<void> _tryExport(List<Span> spans) async {
    if (_isShutdown) {
      throw StateError('Exporter is shutdown');
    }

    if (OTelLog.isLogSpans()) {
      logSpans(spans, 'Exporting spans via HTTP.');
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
        'OtlpHttpSpanExporter: Preparing to export ${spans.length} spans',
      );
      for (var span in spans) {
        OTelLog.debug(
          '  Span: ${span.name}, spanId: ${span.spanContext.spanId}, traceId: ${span.spanContext.traceId}',
        );
      }
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpHttpSpanExporter: Transforming ${spans.length} spans');
    }
    final request = OtlpSpanTransformer.transformSpans(spans);
    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpHttpSpanExporter: Successfully transformed spans');
    }

    // Prepare headers + body. Wire format is selected by config.protocol:
    // protobuf (default) writes the message as its compact binary encoding
    // with Content-Type application/x-protobuf; JSON uses the OTLP/JSON
    // encoding — proto3-JSON PLUS the spec's deviations, the critical one
    // being hex-encoded (not base64) trace/span ids. Strict receivers
    // (OTel Collector ≥ ~0.15x) reject base64 ids with HTTP 400.
    final headers = Map<String, String>.from(_config.headers);
    Uint8List messageBytes;
    if (_config.protocol == OtlpHttpProtocol.httpJson) {
      headers['Content-Type'] = 'application/json';
      final jsonValue = otlpProto3JsonWithHexIds(request);
      messageBytes = Uint8List.fromList(utf8.encode(jsonEncode(jsonValue)));
    } else {
      headers['Content-Type'] = 'application/x-protobuf';
      messageBytes = request.writeToBuffer();
    }

    if (_config.compression) {
      headers['Content-Encoding'] = 'gzip';
    }

    var bodyBytes = messageBytes;

    // Apply gzip compression if configured
    if (_config.compression) {
      final gZip = GZip();
      final listInt = await gZip.compress(messageBytes);
      bodyBytes = Uint8List.fromList(listInt);
    }

    // Get the endpoint URL with the correct path
    final endpointUrl = _getEndpointUrl();
    if (OTelLog.isDebug()) {
      OTelLog.debug(
        'OtlpHttpSpanExporter: Sending export request to $endpointUrl',
      );
      OTelLog.debug('OtlpHttpSpanExporter: Request headers:');
      headers.forEach((key, value) {
        // Mask authorization header value for security, but show it exists
        if (key.toLowerCase() == 'authorization') {
          OTelLog.debug('  $key: [REDACTED - length: ${value.length}]');
        } else {
          OTelLog.debug('  $key: $value');
        }
      });
    }

    try {
      final response = await _client
          .post(Uri.parse(endpointUrl), headers: headers, body: bodyBytes)
          .timeout(_config.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
            'OtlpHttpSpanExporter: Export request completed successfully',
          );
        }
      } else {
        final errorMessage =
            'OtlpHttpSpanExporter: Export request failed with status code ${response.statusCode}';
        if (OTelLog.isError()) OTelLog.error(errorMessage);
        throw http.ClientException(errorMessage);
      }
    } catch (e, stackTrace) {
      if (OTelLog.isError()) {
        OTelLog.error('OtlpHttpSpanExporter: Export request failed: $e');
        OTelLog.error('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  @override
  Future<void> export(List<Span> spans) async {
    if (_isShutdown) {
      throw StateError('Exporter is shutdown');
    }

    if (spans.isEmpty) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('OtlpHttpSpanExporter: No spans to export');
      }
      return;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
        'OtlpHttpSpanExporter: Beginning export of ${spans.length} spans',
      );
    }
    final exportFuture = _export(spans);

    // Track the pending export but don't throw if it fails during shutdown
    _pendingExports.add(exportFuture);
    try {
      await exportFuture;
      if (OTelLog.isDebug()) {
        OTelLog.debug('OtlpHttpSpanExporter: Export completed successfully');
      }
    } catch (e) {
      if (_isShutdown &&
          e is StateError &&
          e.message.contains('shut down during')) {
        // Gracefully handle the case where shutdown interrupted the export
        if (OTelLog.isDebug()) {
          OTelLog.debug(
            'OtlpHttpSpanExporter: Export was interrupted by shutdown, suppressing error',
          );
        }
      } else {
        // Re-throw other errors
        rethrow;
      }
    } finally {
      _pendingExports.remove(exportFuture);
    }
  }

  Future<void> _export(List<Span> spans) async {
    if (_isShutdown) {
      throw StateError('Exporter was shut down during export');
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
        'OtlpHttpSpanExporter: Attempting to export ${spans.length} spans to ${_config.endpoint}',
      );
    }

    var attempts = 0;
    final maxAttempts = _config.maxRetries + 1; // Initial attempt + retries

    while (attempts < maxAttempts) {
      // Allow the export to continue even during shutdown, so we complete in-flight requests
      final wasShutdownDuringRetry = _isShutdown;

      try {
        // Only check for shutdown on retry attempts to ensure in-progress exports can complete
        if (wasShutdownDuringRetry && attempts > 0) {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
              'OtlpHttpSpanExporter: Export interrupted by shutdown',
            );
          }
          throw StateError('Exporter was shut down during export');
        }

        await _tryExport(spans);
        if (OTelLog.isDebug()) {
          OTelLog.debug('OtlpHttpSpanExporter: Successfully exported spans');
        }
        return;
      } on http.ClientException catch (e, stackTrace) {
        if (OTelLog.isError()) {
          OTelLog.error('OtlpHttpSpanExporter: HTTP error during export: $e');
        }
        if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');

        // Check if the exporter was shut down while we were waiting
        if (wasShutdownDuringRetry) {
          if (OTelLog.isError()) {
            OTelLog.error(
              'OtlpHttpSpanExporter: Export interrupted by shutdown',
            );
          }
          throw StateError('Exporter was shut down during export');
        }

        // Handle status code-based retries
        var shouldRetry = false;
        if (e.message.contains('status code')) {
          for (final code in _retryableStatusCodes) {
            if (e.message.contains('status code $code')) {
              shouldRetry = true;
              break;
            }
          }
        }

        if (!shouldRetry) {
          if (OTelLog.isError()) {
            OTelLog.error(
              'OtlpHttpSpanExporter: Non-retryable HTTP error, stopping retry attempts',
            );
          }
          rethrow;
        }

        if (attempts >= maxAttempts - 1) {
          if (OTelLog.isError()) {
            OTelLog.error(
              'OtlpHttpSpanExporter: Max attempts reached ($attempts out of $maxAttempts), giving up',
            );
          }
          rethrow;
        }

        final delay = _calculateJitteredDelay(attempts);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
            'OtlpHttpSpanExporter: Retrying export after ${delay.inMilliseconds}ms...',
          );
        }
        await Future<void>.delayed(delay);
        attempts++;
      } catch (e, stackTrace) {
        if (OTelLog.isError()) {
          OTelLog.error(
            'OtlpHttpSpanExporter: Unexpected error during export: $e',
          );
        }
        if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');

        // Check if we should stop retrying due to shutdown
        if (wasShutdownDuringRetry) {
          throw StateError('Exporter was shut down during export');
        }

        if (attempts >= maxAttempts - 1) {
          rethrow;
        }

        final delay = _calculateJitteredDelay(attempts);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
            'OtlpHttpSpanExporter: Retrying export after ${delay.inMilliseconds}ms...',
          );
        }
        await Future<void>.delayed(delay);
        attempts++;
      }
    }
  }

  /// Force flush any pending spans
  @override
  Future<void> forceFlush() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpHttpSpanExporter: Force flush requested');
    }
    if (_isShutdown) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'OtlpHttpSpanExporter: Exporter is already shut down, nothing to flush',
        );
      }
      return;
    }

    // Wait for any pending export operations to complete
    if (_pendingExports.isNotEmpty) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'OtlpHttpSpanExporter: Waiting for ${_pendingExports.length} pending exports to complete',
        );
      }
      try {
        await Future.wait(_pendingExports);
        if (OTelLog.isDebug()) {
          OTelLog.debug('OtlpHttpSpanExporter: All pending exports completed');
        }
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error('OtlpHttpSpanExporter: Error during force flush: $e');
        }
      }
    } else {
      if (OTelLog.isDebug()) {
        OTelLog.debug('OtlpHttpSpanExporter: No pending exports to flush');
      }
    }
  }

  @override
  Future<void> shutdown() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpHttpSpanExporter: Shutdown requested');
    }
    if (_isShutdown) {
      return;
    }
    if (OTelLog.isDebug()) {
      OTelLog.debug(
        'OtlpHttpSpanExporter: Shutting down - waiting for ${_pendingExports.length} pending exports',
      );
    }

    // Set shutdown flag first
    _isShutdown = true;

    // Create a safe copy of pending exports to avoid concurrent modification
    final pendingExportsCopy = List<Future<void>>.of(_pendingExports);

    // Wait for pending exports but don't start any new ones
    // Use a timeout to prevent hanging if exports take too long
    if (pendingExportsCopy.isNotEmpty) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'OtlpHttpSpanExporter: Waiting for ${pendingExportsCopy.length} pending exports with timeout',
        );
      }
      try {
        // Use a generous timeout but don't wait forever
        await Future.wait(pendingExportsCopy).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (OTelLog.isDebug()) {
              OTelLog.debug(
                'OtlpHttpSpanExporter: Timeout waiting for exports to complete',
              );
            }
            return Future.value([]);
          },
        );
      } catch (e) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
            'OtlpHttpSpanExporter: Error during shutdown while waiting for exports: $e',
          );
        }
      }
    }

    // Close the HTTP client to release resources
    _client.close();

    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpHttpSpanExporter: Shutdown complete');
    }
  }
}
