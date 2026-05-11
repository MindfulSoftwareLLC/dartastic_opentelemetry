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
import '../../../../trace/export/otlp/http/http_client_factory.dart';
import '../../../../util/zip/gzip.dart';
import '../../../readable_log_record.dart';
import '../../log_record_exporter.dart';
import '../log_record_transformer.dart';
import 'otlp_http_log_record_exporter_config.dart';

/// An OpenTelemetry log record exporter that exports logs using OTLP over HTTP/protobuf.
class OtlpHttpLogRecordExporter implements LogRecordExporter {
  static const _retryableStatusCodes = [
    429, // Too Many Requests
    503, // Service Unavailable
  ];

  final OtlpHttpLogRecordExporterConfig _config;
  bool _isShutdown = false;
  final Random _random = Random();
  final List<Future<void>> _pendingExports = [];
  late final http.Client _client;

  /// Creates a new OTLP HTTP log record exporter with the specified configuration.
  /// If no configuration is provided, default settings will be used.
  ///
  /// @param config Optional configuration for the exporter
  OtlpHttpLogRecordExporter([OtlpHttpLogRecordExporterConfig? config])
      : _config = config ?? OtlpHttpLogRecordExporterConfig() {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpHttpLogRecordExporter: Created with endpoint: ${_config.endpoint}');
      OTelLog.debug(
          'OtlpHttpLogRecordExporter: Configured headers count: ${_config.headers.length}');
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
  /// Delegated to a platform-conditional factory: native gets an
  /// `IOClient` wrapping an `HttpClient` with a custom `SecurityContext`;
  /// web gets a `BrowserClient` (the browser handles TLS).
  http.Client _createHttpClient() => createOtlpHttpClient(
        exporterName: 'OtlpHttpLogRecordExporter',
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
    // Ensure the endpoint ends with /v1/logs
    var endpoint = _config.endpoint;
    if (!endpoint.endsWith('/v1/logs')) {
      if (endpoint.endsWith('/')) {
        endpoint = endpoint.substring(0, endpoint.length - 1);
      }
      endpoint = '$endpoint/v1/logs';
    }
    return endpoint;
  }

  Future<ExportResult> _tryExport(List<ReadableLogRecord> logRecords) async {
    if (_isShutdown) {
      return ExportResult.failure;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpHttpLogRecordExporter: Preparing to export ${logRecords.length} log records');
    }

    final request = OtlpLogRecordTransformer.transformLogRecords(logRecords);
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpHttpLogRecordExporter: Successfully transformed log records');
    }

    // Prepare headers + body. Wire format is selected by config.protocol —
    // protobuf (default) or JSON via proto3-JSON mapping. See
    // `OtlpHttpProtocol` for the conformance rationale.
    final headers = Map<String, String>.from(_config.headers);
    Uint8List messageBytes;
    if (_config.protocol == OtlpHttpProtocol.httpJson) {
      headers['Content-Type'] = 'application/json';
      final jsonValue = request.toProto3Json();
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
          'OtlpHttpLogRecordExporter: Sending export request to $endpointUrl');
      OTelLog.debug('OtlpHttpLogRecordExporter: Request headers:');
      headers.forEach((key, value) {
        if (key.toLowerCase() == 'authorization') {
          OTelLog.debug('  $key: [REDACTED - length: ${value.length}]');
        } else {
          OTelLog.debug('  $key: $value');
        }
      });
    }

    try {
      final response = await _client
          .post(
            Uri.parse(endpointUrl),
            headers: headers,
            body: bodyBytes,
          )
          .timeout(_config.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpHttpLogRecordExporter: Export request completed successfully');
        }
        return ExportResult.success;
      } else {
        final errorMessage =
            'OtlpHttpLogRecordExporter: Export request failed with status code ${response.statusCode}';
        if (OTelLog.isError()) OTelLog.error(errorMessage);
        throw http.ClientException(errorMessage);
      }
    } catch (e, stackTrace) {
      if (OTelLog.isError()) {
        OTelLog.error('OtlpHttpLogRecordExporter: Export request failed: $e');
        OTelLog.error('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  @override
  Future<ExportResult> export(List<ReadableLogRecord> logRecords) async {
    if (_isShutdown) {
      return ExportResult.failure;
    }

    if (logRecords.isEmpty) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('OtlpHttpLogRecordExporter: No log records to export');
      }
      return ExportResult.success;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpHttpLogRecordExporter: Beginning export of ${logRecords.length} log records');
    }

    final exportFuture = _export(logRecords);
    _pendingExports.add(exportFuture);

    try {
      final result = await exportFuture;
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpHttpLogRecordExporter: Export completed with result: $result');
      }
      return result;
    } catch (e) {
      if (_isShutdown &&
          e is StateError &&
          e.message.contains('shut down during')) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpHttpLogRecordExporter: Export was interrupted by shutdown');
        }
        return ExportResult.failure;
      }
      return ExportResult.failure;
    } finally {
      _pendingExports.remove(exportFuture);
    }
  }

  Future<ExportResult> _export(List<ReadableLogRecord> logRecords) async {
    if (_isShutdown) {
      return ExportResult.failure;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpHttpLogRecordExporter: Attempting to export ${logRecords.length} log records to ${_config.endpoint}');
    }

    var attempts = 0;
    final maxAttempts = _config.maxRetries + 1;

    while (attempts < maxAttempts) {
      final wasShutdownDuringRetry = _isShutdown;

      try {
        if (wasShutdownDuringRetry && attempts > 0) {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'OtlpHttpLogRecordExporter: Export interrupted by shutdown');
          }
          return ExportResult.failure;
        }

        return await _tryExport(logRecords);
      } on http.ClientException catch (e, stackTrace) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpHttpLogRecordExporter: HTTP error during export: $e');
          OTelLog.error('Stack trace: $stackTrace');
        }

        if (wasShutdownDuringRetry) {
          return ExportResult.failure;
        }

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
                'OtlpHttpLogRecordExporter: Non-retryable HTTP error, stopping retry attempts');
          }
          return ExportResult.failure;
        }

        if (attempts >= maxAttempts - 1) {
          if (OTelLog.isError()) {
            OTelLog.error(
                'OtlpHttpLogRecordExporter: Max attempts reached, giving up');
          }
          return ExportResult.failure;
        }

        final delay = _calculateJitteredDelay(attempts);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpHttpLogRecordExporter: Retrying export after ${delay.inMilliseconds}ms...');
        }
        await Future<void>.delayed(delay);
        attempts++;
      } catch (e, stackTrace) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpHttpLogRecordExporter: Unexpected error during export: $e');
          OTelLog.error('Stack trace: $stackTrace');
        }

        if (wasShutdownDuringRetry) {
          return ExportResult.failure;
        }

        if (attempts >= maxAttempts - 1) {
          return ExportResult.failure;
        }

        final delay = _calculateJitteredDelay(attempts);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpHttpLogRecordExporter: Retrying export after ${delay.inMilliseconds}ms...');
        }
        await Future<void>.delayed(delay);
        attempts++;
      }
    }

    return ExportResult.failure;
  }

  @override
  Future<void> forceFlush() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpHttpLogRecordExporter: Force flush requested');
    }
    if (_isShutdown) {
      return;
    }

    if (_pendingExports.isNotEmpty) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpHttpLogRecordExporter: Waiting for ${_pendingExports.length} pending exports');
      }
      try {
        await Future.wait(_pendingExports);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpHttpLogRecordExporter: All pending exports completed');
        }
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpHttpLogRecordExporter: Error during force flush: $e');
        }
      }
    }
  }

  @override
  Future<void> shutdown() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpHttpLogRecordExporter: Shutdown requested');
    }
    if (_isShutdown) {
      return;
    }

    _isShutdown = true;

    final pendingExportsCopy = List<Future<void>>.of(_pendingExports);

    if (pendingExportsCopy.isNotEmpty) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpHttpLogRecordExporter: Waiting for ${pendingExportsCopy.length} pending exports');
      }
      try {
        await Future.wait(pendingExportsCopy)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'OtlpHttpLogRecordExporter: Timeout waiting for exports to complete');
          }
          return Future.value([]);
        });
      } catch (e) {
        if (OTelLog.isDebug()) {
          OTelLog.debug('OtlpHttpLogRecordExporter: Error during shutdown: $e');
        }
      }
    }

    _client.close();

    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpHttpLogRecordExporter: Shutdown complete');
    }
  }
}
