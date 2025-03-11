// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:math';

import 'package:grpc/grpc.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';
import '../../../../proto/opentelemetry_proto_dart.dart' as proto;
import '../../../util/otel_log.dart';
import '../span_exporter.dart';
import 'otlp_grpc_span_exporter_config.dart';
import 'span_transformer.dart';

/// An OpenTelemetry span exporter that exports spans using OTLP over gRPC
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

  OtlpGrpcSpanExporter([OtlpGrpcExporterConfig? config])
      : _config = config ?? OtlpGrpcExporterConfig();
  bool _permanentChannel = false;

  void _setupChannel() {
    if (_channel != null) {
      try {
        _channel?.shutdown();
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error('OtlpGrpcSpanExporter: Error shutting down existing channel: $e');
        }
      }
    }

    String host;
    int port;

    try {
      final endpoint = _config.endpoint.replaceAll(RegExp(r'^(http://|https://)'), '');
      final parts = endpoint.split(':');
      host = parts[0].isEmpty ? 'localhost' : parts[0];
      port = parts.length > 1 ? int.parse(parts[1]) : 4317;

      if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Setting up gRPC channel to $host:$port');

      // Create a permanent channel that won't change ports
      if (!_permanentChannel) {
        _channel = ClientChannel(
          host,
          port: port,
          options: ChannelOptions(
            credentials: _config.insecure ?
            const ChannelCredentials.insecure() :
            const ChannelCredentials.secure(),
            idleTimeout: null, // Disable idle timeout to keep connection alive
            connectTimeout: Duration(seconds: 5),
            codecRegistry: CodecRegistry(codecs: const [
              GzipCodec(),
              IdentityCodec(),
            ]),
          ),
        );
        _permanentChannel = true;
      }

      _traceService = proto.TraceServiceClient(_channel!);
      if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Successfully created gRPC channel and trace service');
    } catch (e, stackTrace) {
      if (OTelLog.isError()) OTelLog.error(('OtlpGrpcSpanExporter: Failed to setup gRPC channel: $e'));
      if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _ensureChannel() async {
    if (_channel == null || _traceService == null) {
      _setupChannel();
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
      OTelLog.logSpans(spans, "Exporting spans.");
    }
    if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Transforming ${spans.length} spans');
    final request = OtlpSpanTransformer.transformSpans(spans);
    if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Successfully transformed spans');

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

    final CallOptions options = CallOptions(
      timeout: _config.timeout,
      metadata: _config.headers,
    );

    if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Sending export request to ${_config.endpoint}');
    try {
      final response = await _traceService!.export(request, options: options);
      if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Export request completed successfully');
      if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Response: $response');
    } catch (e, stackTrace) {
      if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Export request failed: $e');
      if (OTelLog.isDebug()) OTelLog.debug('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> export(List<Span> spans) async {
    if (_isShutdown) {
      throw StateError('Exporter is shutdown');
    }

    if (spans.isEmpty) {
      if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: No spans to export');
      return;
    }

    if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Beginning export of ${spans.length} spans');
    final exportFuture = _export(spans);
    _pendingExports.add(exportFuture);
    try {
      await exportFuture;
      if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Export completed successfully');
    } finally {
      _pendingExports.remove(exportFuture);
    }
  }

  Future<void> _export(List<Span> spans) async {
    if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Attempting to export ${spans.length} spans to ${_config.endpoint}');

    var attempts = 0;
    final maxAttempts = _config.maxRetries + 1; // Initial attempt + retries

    while (attempts < maxAttempts) {
      try {
        await _tryExport(spans);
        if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Successfully exported spans');
        return;
      } on GrpcError catch (e, stackTrace) {
        if (OTelLog.isError()) OTelLog.error('OtlpGrpcSpanExporter: gRPC error during export: ${e.code} - ${e.message}');
        if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');

        if (!_retryableStatusCodes.contains(e.code)) {
          if (OTelLog.isError()) OTelLog.error('OtlpGrpcSpanExporter: Non-retryable gRPC error (${e.code}), stopping retry attempts');
          rethrow;
        }

        if (attempts >= maxAttempts - 1) {
          if (OTelLog.isError()) OTelLog.error('OtlpGrpcSpanExporter: Max attempts reached ($attempts out of $maxAttempts), giving up');
          rethrow;
        }

        final delay = _calculateJitteredDelay(attempts);
        if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Retrying export after ${delay.inMilliseconds}ms...');
        await Future.delayed(delay);
        _setupChannel();
        attempts++;
      } catch (e, stackTrace) {
        if (OTelLog.isError()) OTelLog.error('OtlpGrpcSpanExporter: Unexpected error during export: $e');
        if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');
        if (attempts >= maxAttempts - 1) {
          rethrow;
        }

        final delay = _calculateJitteredDelay(attempts);
        if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Retrying export after ${delay.inMilliseconds}ms...');
        await Future.delayed(delay);
        _setupChannel();
        attempts++;
      }
    }
  }

  @override
  Future<void> forceFlush() async {
    // No buffering in this exporter, so nothing to flush
    if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Force flush requested');
    return;
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Shutting down - waiting for ${_pendingExports.length} pending exports');
    _isShutdown = true;

    // Wait for pending exports but don't start any new ones
    if (_pendingExports.isNotEmpty) {
      try {
        await Future.wait(_pendingExports);
      } catch (e) {
        if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Error during shutdown while waiting for exports: $e');
      }
    }

    try {
      await _channel?.shutdown();
    } catch (e) {
      if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Error during channel shutdown: $e');
    }

    _channel = null;
    _traceService = null;
    if (OTelLog.isDebug()) OTelLog.debug('OtlpGrpcSpanExporter: Shutdown complete');
  }

}
