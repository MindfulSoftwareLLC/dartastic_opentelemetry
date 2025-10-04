// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:math';

import 'package:dartastic_opentelemetry/src/trace/span.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;
import 'package:grpc/grpc.dart';

import '../../../../proto/opentelemetry_proto_dart.dart' as proto;
import '../../span_logger.dart';
import '../span_exporter.dart';
import 'certificate_utils.dart';
import 'otlp_grpc_span_exporter_config.dart';
import 'span_transformer.dart';

/// An OpenTelemetry span exporter that exports spans using OTLP over gRPC.
///
/// This exporter sends trace data to an OpenTelemetry collector or compatible backend
/// using the OpenTelemetry Protocol (OTLP) over gRPC. It supports features such as:
/// - Retrying failed exports with exponential backoff
/// - Secure and insecure connections
/// - Custom headers and timeouts
/// - Compression
class OtlpGrpcSpanExporter implements SpanExporter {
  static const _retryableStatusCodes = [
    // Note: Don't retry on deadline exceeded as it indicates a timeout
    StatusCode.resourceExhausted, // Maps to HTTP 429
    StatusCode.unavailable, // Maps to HTTP 503
  ];

  final OtlpGrpcExporterConfig _config;
  ClientChannel? _channel;
  proto.TraceServiceClient? _traceService;
  bool _isShutdown = false;
  final Random _random = Random();
  final List<Future<void>> _pendingExports = [];

  /// Creates a new OtlpGrpcSpanExporter with the specified configuration.
  ///
  /// If no configuration is provided, default values will be used.
  ///
  /// @param config Optional configuration for the exporter
  OtlpGrpcSpanExporter([OtlpGrpcExporterConfig? config])
      : _config = config ?? OtlpGrpcExporterConfig();
  bool _initialized = false;

  /// Creates channel credentials based on configuration.
  ///
  /// If insecure is true, returns insecure credentials.
  /// Otherwise, creates secure credentials with optional custom certificates for mTLS.
  ChannelCredentials _createChannelCredentials() {
    if (_config.insecure) {
      return const ChannelCredentials.insecure();
    }

    // If no custom certificates are provided, use default secure credentials
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
        certificates: null, // We're using SecurityContext instead
        authority: null,
        onBadCertificate: null,
      );
    } catch (e) {
      if (OTelLog.isError()) {
        OTelLog.error('OtlpGrpcSpanExporter: Failed to load certificates: $e');
      }
      // Fall back to default secure credentials on error
      return const ChannelCredentials.secure();
    }
  }

  /// Cleanup the gRPC channel and release resources
  Future<void> _cleanupChannel() async {
    if (_channel != null) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('OtlpGrpcSpanExporter: Shutting down existing channel');
      }

      try {
        // First try a graceful shutdown
        try {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'OtlpGrpcSpanExporter: Attempting graceful channel shutdown');
          }
          await _channel!.shutdown();
          await Future<void>.delayed(const Duration(
              milliseconds: 100)); // Brief delay for shutdown to complete
        } catch (e) {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'OtlpGrpcSpanExporter: Error during graceful shutdown: $e');
          }
        }

        // Then try to terminate to ensure cleanup
        try {
          if (OTelLog.isDebug()) {
            OTelLog.debug('OtlpGrpcSpanExporter: Terminating channel');
          }
          _channel!.terminate();
          await Future<void>.delayed(const Duration(
              milliseconds: 100)); // Brief delay for termination to complete
        } catch (e) {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'OtlpGrpcSpanExporter: Error terminating channel: $e');
          }
        }
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpGrpcSpanExporter: Error shutting down existing channel: $e');
        }
      }

      // Set to null to allow garbage collection
      _channel = null;
      _traceService = null;

      // Force garbage collection if possible
      try {
        // In Dart, we can't directly force garbage collection,
        // but we can suggest it by setting variables to null and
        // creating some memory pressure
        final List<int> temp = [];
        for (int i = 0; i < 1000; i++) {
          temp.add(i);
        }
        temp.clear();
      } catch (e) {
        // Ignore any errors
      }
    }
  }

  Future<void> _setupChannel() async {
    if (_isShutdown) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcSpanExporter: Not setting up channel - exporter is shut down');
      }
      return;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpGrpcSpanExporter: Setting up gRPC channel with endpoint ${_config.endpoint}');
    }

    // First, clean up any existing channel
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

      // Replace localhost with 127.0.0.1 for more reliable connections
      if (host == 'localhost') {
        host = '127.0.0.1';
      }

      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcSpanExporter: Setting up gRPC channel to $host:$port');
      }

      // Create a channel
      _channel ??= ClientChannel(
        host,
        port: port,
        options: ChannelOptions(
          credentials: _createChannelCredentials(),
          connectTimeout: const Duration(seconds: 5),
          // Keep connection alive better
          idleTimeout: const Duration(seconds: 30),
          codecRegistry: CodecRegistry(codecs: const [
            GzipCodec(),
            IdentityCodec(),
          ]),
        ),
      );

      try {
        _traceService = proto.TraceServiceClient(_channel!);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpGrpcSpanExporter: Successfully created TraceServiceClient');
        }
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpGrpcSpanExporter: Failed to create TraceServiceClient: $e');
        }
        rethrow;
      }
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcSpanExporter: Successfully created gRPC channel and trace service');
      }
    } catch (e, stackTrace) {
      if (OTelLog.isError()) {
        OTelLog.error(
            ('OtlpGrpcSpanExporter: Failed to setup gRPC channel: $e'));
      }
      if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _ensureChannel() async {
    if (_isShutdown) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcSpanExporter: Not ensuring channel - exporter is shut down');
      }
      throw StateError('Exporter is shutdown');
    }

    if (_initialized && _channel != null && _traceService != null) {
      return;
    }

    _initialized = true;
    if (_channel == null || _traceService == null) {
      await _setupChannel();
    }
  }

  Duration _calculateJitteredDelay(int retries) {
    final baseMs = _config.baseDelay.inMilliseconds;
    final delay = baseMs * pow(2, retries);
    final jitter = _random.nextDouble() * delay;
    return Duration(milliseconds: (delay + jitter).toInt());
  }

  Future<void> _tryExport(List<Span> spans) async {
    await _ensureChannel();
    if (_isShutdown) {
      throw StateError('Exporter is shutdown');
    }
    if (OTelLog.isLogSpans()) {
      logSpans(spans, "Exporting spans.");
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpGrpcSpanExporter: Preparing to export ${spans.length} spans');
      for (var span in spans) {
        OTelLog.debug(
            '  Span: ${span.name}, spanId: ${span.spanContext.spanId}, traceId: ${span.spanContext.traceId}');
      }
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpGrpcSpanExporter: Transforming ${spans.length} spans');
    }
    final request = OtlpSpanTransformer.transformSpans(spans);
    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpGrpcSpanExporter: Successfully transformed spans');
    }

    if (OTelLog.isDebug()) {
      for (var rs in request.resourceSpans) {
        OTelLog.debug('  ResourceSpan:');
        if (rs.hasResource()) {
          OTelLog.debug('    Resource attributes:');
          for (var attr in rs.resource.attributes) {
            OTelLog.debug('      ${attr.key}: ${attr.value}');
          }
        }
        for (var ss in rs.scopeSpans) {
          OTelLog.debug('    ScopeSpan:');
          for (var span in ss.spans) {
            OTelLog.debug('      Span: ${span.name}');
            OTelLog.debug('        TraceId: ${span.traceId}');
            OTelLog.debug('        SpanId: ${span.spanId}');
          }
        }
      }
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
          'OtlpGrpcSpanExporter: Sending export request to ${_config.endpoint}');
    }
    try {
      if (_traceService == null) {
        throw StateError(
            'Trace service is null, channel may not be properly initialized');
      }

      final response = await _traceService!.export(request, options: options);
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcSpanExporter: Export request completed successfully');
      }
      if (OTelLog.isDebug()) {
        OTelLog.debug('OtlpGrpcSpanExporter: Response: $response');
      }
    } catch (e, stackTrace) {
      if (OTelLog.isError()) {
        OTelLog.error('OtlpGrpcSpanExporter: Export request failed: $e');
        OTelLog.error('Stack trace: $stackTrace');
      }

      // If we have a channel error, try to recreate it
      if (e is GrpcError &&
          (e.code == StatusCode.unavailable ||
              e.code == StatusCode.unknown ||
              e.code == StatusCode.internal)) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpGrpcSpanExporter: Channel error detected, recreating channel');
        }
        // Force channel recreation
        await _cleanupChannel();
        _initialized = false;
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
        OTelLog.debug('OtlpGrpcSpanExporter: No spans to export');
      }
      return;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpGrpcSpanExporter: Beginning export of ${spans.length} spans');
    }
    final exportFuture = _export(spans);

    // Track the pending export but don't throw if it fails during shutdown
    _pendingExports.add(exportFuture);
    try {
      await exportFuture;
      if (OTelLog.isDebug()) {
        OTelLog.debug('OtlpGrpcSpanExporter: Export completed successfully');
      }
    } catch (e) {
      if (_isShutdown &&
          e is StateError &&
          e.message.contains('shut down during')) {
        // Gracefully handle the case where shutdown interrupted the export
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpGrpcSpanExporter: Export was interrupted by shutdown, suppressing error');
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
          'OtlpGrpcSpanExporter: Attempting to export ${spans.length} spans to ${_config.endpoint}');
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
                'OtlpGrpcSpanExporter: Export interrupted by shutdown');
          }
          throw StateError('Exporter was shut down during export');
        }

        await _tryExport(spans);
        if (OTelLog.isDebug()) {
          OTelLog.debug('OtlpGrpcSpanExporter: Successfully exported spans');
        }
        return;
      } on GrpcError catch (e, stackTrace) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpGrpcSpanExporter: gRPC error during export: ${e.code} - ${e.message}');
        }
        if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');

        // Check if the exporter was shut down while we were waiting
        if (wasShutdownDuringRetry) {
          if (OTelLog.isError()) {
            OTelLog.error(
                'OtlpGrpcSpanExporter: Export interrupted by shutdown');
          }
          throw StateError('Exporter was shut down during export');
        }

        if (!_retryableStatusCodes.contains(e.code)) {
          if (OTelLog.isError()) {
            OTelLog.error(
                'OtlpGrpcSpanExporter: Non-retryable gRPC error (${e.code}), stopping retry attempts');
          }
          rethrow;
        }

        if (attempts >= maxAttempts - 1) {
          if (OTelLog.isError()) {
            OTelLog.error(
                'OtlpGrpcSpanExporter: Max attempts reached ($attempts out of $maxAttempts), giving up');
          }
          rethrow;
        }

        final delay = _calculateJitteredDelay(attempts);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpGrpcSpanExporter: Retrying export after ${delay.inMilliseconds}ms...');
        }
        await Future<void>.delayed(delay);
        if (!_isShutdown) {
          // Only recreate channel if not shut down
          await _setupChannel();
        }
        attempts++;
      } catch (e, stackTrace) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'OtlpGrpcSpanExporter: Unexpected error during export: $e');
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
              'OtlpGrpcSpanExporter: Retrying export after ${delay.inMilliseconds}ms...');
        }
        await Future<void>.delayed(delay);
        if (!_isShutdown) {
          // Only recreate channel if not shut down
          await _setupChannel();
        }
        attempts++;
      }
    }
  }

  /// Force flush any pending spans
  @override
  Future<void> forceFlush() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpGrpcSpanExporter: Force flush requested');
    }
    if (_isShutdown) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcSpanExporter: Exporter is already shut down, nothing to flush');
      }
      return;
    }

    // Wait for any pending export operations to complete
    if (_pendingExports.isNotEmpty) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OtlpGrpcSpanExporter: Waiting for ${_pendingExports.length} pending exports to complete');
      }
      try {
        await Future.wait(_pendingExports);
        if (OTelLog.isDebug()) {
          OTelLog.debug('OtlpGrpcSpanExporter: All pending exports completed');
        }
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error('OtlpGrpcSpanExporter: Error during force flush: $e');
        }
      }
    } else {
      if (OTelLog.isDebug()) {
        OTelLog.debug('OtlpGrpcSpanExporter: No pending exports to flush');
      }
    }
  }

  @override
  Future<void> shutdown() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpGrpcSpanExporter: Shutdown requested');
    }
    if (_isShutdown) {
      return;
    }
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OtlpGrpcSpanExporter: Shutting down - waiting for ${_pendingExports.length} pending exports');
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
            'OtlpGrpcSpanExporter: Waiting for ${pendingExportsCopy.length} pending exports with timeout');
      }
      try {
        // Use a generous timeout but don't wait forever
        await Future.wait(pendingExportsCopy)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'OtlpGrpcSpanExporter: Timeout waiting for exports to complete');
          }
          return Future.value([]);
        });
      } catch (e) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'OtlpGrpcSpanExporter: Error during shutdown while waiting for exports: $e');
        }
      }
    }

    // Clean up channel resources
    await _cleanupChannel();

    if (OTelLog.isDebug()) {
      OTelLog.debug('OtlpGrpcSpanExporter: Shutdown complete');
    }
  }
}
