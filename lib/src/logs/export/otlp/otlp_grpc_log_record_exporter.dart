// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:math';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;
import 'package:grpc/grpc.dart';

import '../../../../proto/opentelemetry_proto_dart.dart' as proto;
import '../../../trace/export/otlp/certificate_utils.dart';
import '../../readable_log_record.dart';
import '../log_record_exporter.dart';
import 'log_record_transformer.dart';
import 'otlp_grpc_log_record_exporter_config.dart';

/// An OpenTelemetry log record exporter that exports logs using OTLP over gRPC.
///
/// This exporter sends log data to an OpenTelemetry collector or compatible backend
/// using the OpenTelemetry Protocol (OTLP) over gRPC. It supports features such as:
/// - Retrying failed exports with exponential backoff
/// - Secure and insecure connections
/// - Custom headers and timeouts
/// - Compression
class OtlpGrpcLogRecordExporter implements LogRecordExporter {
  static const _retryableStatusCodes = [
    StatusCode.resourceExhausted, // Maps to HTTP 429
    StatusCode.unavailable, // Maps to HTTP 503
  ];

  final OtlpGrpcLogRecordExporterConfig _config;
  ClientChannel? _channel;
  proto.LogsServiceClient? _logsService;
  bool _isShutdown = false;
  final Random _random = Random();
  final List<Future<void>> _pendingExports = [];
  bool _initialized = false;

  /// Creates a new OtlpGrpcLogRecordExporter with the specified configuration.
  ///
  /// If no configuration is provided, default values will be used.
  ///
  /// @param config Optional configuration for the exporter
  OtlpGrpcLogRecordExporter([OtlpGrpcLogRecordExporterConfig? config])
      : _config = config ?? OtlpGrpcLogRecordExporterConfig();

  /// Creates channel credentials based on configuration.
  ChannelCredentials _createChannelCredentials() {
    if (_config.insecure) {
      return const ChannelCredentials.insecure();
    }

    if (_config.certificate == null &&
        _config.clientKey == null &&
        _config.clientCertificate == null) {
      return const ChannelCredentials.secure();
    }

    try {
      final context = CertificateUtils.createSecurityContext(
        certificate: _config.certificate,
        clientKey: _config.clientKey,
        clientCertificate: _config.clientCertificate,
      );

      if (context == null) {
        return const ChannelCredentials.secure();
      }

      return const ChannelCredentials.secure(
        certificates: null,
        authority: null,
        onBadCertificate: null,
      );
    } catch (e) {
      if (OTelLog.isError()) {
        OTelLog.error(
            'OtlpGrpcLogRecordExporter: Failed to load certificates: $e');
      }
      return const ChannelCredentials.secure();
    }
  }

  /// Cleanup the gRPC channel and release resources.
  Future<void> _cleanupChannel() async {
    if (_channel != null) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcLogRecordExporter: Shutting down existing channel');
      }

      try {
        try {
          await _channel!.shutdown();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'OtlpGrpcLogRecordExporter: Error during graceful shutdown: $e');
          }
        }

        try {
          _channel!.terminate();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'OtlpGrpcLogRecordExporter: Error terminating channel: $e');
          }
        }
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpGrpcLogRecordExporter: Error shutting down channel: $e');
        }
      }

      _channel = null;
      _logsService = null;
    }
  }

  Future<void> _setupChannel() async {
    if (_isShutdown) {
      return;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpGrpcLogRecordExporter: Setting up gRPC channel with endpoint ${_config.endpoint}');
    }

    await _cleanupChannel();

    String host;
    int port;

    try {
      final endpoint = _config.endpoint
          .trim()
          .replaceAll(RegExp(r'^(http://|https://)'), '');
      final parts = endpoint.split(':');
      host = parts[0].isEmpty ? '127.0.0.1' : parts[0];
      port = parts.length > 1 ? int.parse(parts[1]) : 4317;

      if (host == 'localhost') {
        host = '127.0.0.1';
      }

      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcLogRecordExporter: Setting up gRPC channel to $host:$port');
      }

      _channel ??= ClientChannel(
        host,
        port: port,
        options: ChannelOptions(
          credentials: _createChannelCredentials(),
          connectTimeout: const Duration(seconds: 5),
          idleTimeout: const Duration(seconds: 30),
          codecRegistry: CodecRegistry(codecs: const [
            GzipCodec(),
            IdentityCodec(),
          ]),
        ),
      );

      try {
        _logsService = proto.LogsServiceClient(_channel!);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpGrpcLogRecordExporter: Successfully created LogsServiceClient');
        }
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpGrpcLogRecordExporter: Failed to create LogsServiceClient: $e');
        }
        rethrow;
      }
    } catch (e, stackTrace) {
      if (OTelLog.isError()) {
        OTelLog.error(
            'OtlpGrpcLogRecordExporter: Failed to setup gRPC channel: $e');
        OTelLog.error('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  Future<void> _ensureChannel() async {
    if (_isShutdown) {
      throw StateError('Exporter is shutdown');
    }

    if (_initialized && _channel != null && _logsService != null) {
      return;
    }

    _initialized = true;
    if (_channel == null || _logsService == null) {
      await _setupChannel();
    }
  }

  Duration _calculateJitteredDelay(int retries) {
    final baseMs = _config.baseDelay.inMilliseconds;
    final delay = baseMs * pow(2, retries);
    final jitter = _random.nextDouble() * delay;
    return Duration(milliseconds: (delay + jitter).toInt());
  }

  Future<ExportResult> _tryExport(List<ReadableLogRecord> logRecords) async {
    await _ensureChannel();
    if (_isShutdown) {
      return ExportResult.failure;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpGrpcLogRecordExporter: Preparing to export ${logRecords.length} log records');
    }

    final request = OtlpLogRecordTransformer.transformLogRecords(logRecords);
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpGrpcLogRecordExporter: Successfully transformed log records');
    }

    // Add compression header if configured
    final headers = Map<String, String>.from(_config.headers);
    if (_config.compression) {
      headers['grpc-encoding'] = 'gzip';
    }

    final CallOptions options = CallOptions(
      timeout: _config.timeout,
      metadata: headers,
    );

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpGrpcLogRecordExporter: Sending export request to ${_config.endpoint}');
    }

    try {
      if (_logsService == null) {
        throw StateError('Logs service is null');
      }

      final response = await _logsService!.export(request, options: options);
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcLogRecordExporter: Export request completed successfully');
        OTelLog.debug('OtlpGrpcLogRecordExporter: Response: $response');
      }
      return ExportResult.success;
    } catch (e, stackTrace) {
      if (OTelLog.isError()) {
        OTelLog.error('OtlpGrpcLogRecordExporter: Export request failed: $e');
        OTelLog.error('Stack trace: $stackTrace');
      }

      if (e is GrpcError &&
          (e.code == StatusCode.unavailable ||
              e.code == StatusCode.unknown ||
              e.code == StatusCode.internal)) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpGrpcLogRecordExporter: Channel error, recreating channel');
        }
        await _cleanupChannel();
        _initialized = false;
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
        OTelLog.debug('OtlpGrpcLogRecordExporter: No log records to export');
      }
      return ExportResult.success;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpGrpcLogRecordExporter: Beginning export of ${logRecords.length} log records');
    }

    final exportFuture = _export(logRecords);
    _pendingExports.add(exportFuture);

    try {
      final result = await exportFuture;
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcLogRecordExporter: Export completed with result: $result');
      }
      return result;
    } catch (e) {
      if (_isShutdown &&
          e is StateError &&
          e.message.contains('shut down during')) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpGrpcLogRecordExporter: Export was interrupted by shutdown');
        }
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
          'OtlpGrpcLogRecordExporter: Attempting to export ${logRecords.length} log records');
    }

    var attempts = 0;
    final maxAttempts = _config.maxRetries + 1;

    while (attempts < maxAttempts) {
      final wasShutdownDuringRetry = _isShutdown;

      try {
        if (wasShutdownDuringRetry && attempts > 0) {
          return ExportResult.failure;
        }

        return await _tryExport(logRecords);
      } on GrpcError catch (e, stackTrace) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpGrpcLogRecordExporter: gRPC error: ${e.code} - ${e.message}');
          OTelLog.error('Stack trace: $stackTrace');
        }

        if (wasShutdownDuringRetry) {
          return ExportResult.failure;
        }

        if (!_retryableStatusCodes.contains(e.code)) {
          if (OTelLog.isError()) {
            OTelLog.error(
                'OtlpGrpcLogRecordExporter: Non-retryable gRPC error (${e.code})');
          }
          return ExportResult.failure;
        }

        if (attempts >= maxAttempts - 1) {
          if (OTelLog.isError()) {
            OTelLog.error(
                'OtlpGrpcLogRecordExporter: Max attempts reached, giving up');
          }
          return ExportResult.failure;
        }

        final delay = _calculateJitteredDelay(attempts);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpGrpcLogRecordExporter: Retrying after ${delay.inMilliseconds}ms');
        }
        await Future<void>.delayed(delay);
        if (!_isShutdown) {
          await _setupChannel();
        }
        attempts++;
      } catch (e, stackTrace) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpGrpcLogRecordExporter: Unexpected error during export: $e');
          OTelLog.error('Stack trace: $stackTrace');
        }

        if (wasShutdownDuringRetry) {
          return ExportResult.failure;
        }

        if (attempts >= maxAttempts - 1) {
          return ExportResult.failure;
        }

        final delay = _calculateJitteredDelay(attempts);
        await Future<void>.delayed(delay);
        if (!_isShutdown) {
          await _setupChannel();
        }
        attempts++;
      }
    }

    return ExportResult.failure;
  }

  @override
  Future<void> forceFlush() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpGrpcLogRecordExporter: Force flush requested');
    }
    if (_isShutdown) {
      return;
    }

    if (_pendingExports.isNotEmpty) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcLogRecordExporter: Waiting for ${_pendingExports.length} pending exports');
      }
      try {
        await Future.wait(_pendingExports);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpGrpcLogRecordExporter: All pending exports completed');
        }
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpGrpcLogRecordExporter: Error during force flush: $e');
        }
      }
    }
  }

  @override
  Future<void> shutdown() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpGrpcLogRecordExporter: Shutdown requested');
    }
    if (_isShutdown) {
      return;
    }

    _isShutdown = true;

    final pendingExportsCopy = List<Future<void>>.of(_pendingExports);

    if (pendingExportsCopy.isNotEmpty) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcLogRecordExporter: Waiting for ${pendingExportsCopy.length} pending exports');
      }
      try {
        await Future.wait(pendingExportsCopy)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'OtlpGrpcLogRecordExporter: Timeout waiting for exports');
          }
          return Future.value([]);
        });
      } catch (e) {
        if (OTelLog.isDebug()) {
          OTelLog.debug('OtlpGrpcLogRecordExporter: Error during shutdown: $e');
        }
      }
    }

    await _cleanupChannel();

    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpGrpcLogRecordExporter: Shutdown complete');
    }
  }
}
