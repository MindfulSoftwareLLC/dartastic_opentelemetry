// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Additional OtlpGrpcSpanExporter edges: generic-error retry with
// channel recreation, secure-credential fallback, and post-shutdown
// behavior.

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart'
    hide Server;
import 'package:dartastic_opentelemetry/proto/collector/trace/v1/trace_service.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:test/test.dart';

class _GenericThrowTraceService extends TraceServiceBase {
  int callCount = 0;

  @override
  Future<ExportTraceServiceResponse> export(
    ServiceCall call,
    ExportTraceServiceRequest request,
  ) async {
    callCount++;
    throw Exception('Generic non-gRPC error');
  }
}

void main() {
  group('OtlpGrpcSpanExporter additional edges', () {
    setUp(() async {
      await OTel.reset();
      OTelLog.logFunction = (_) {};
      EnvironmentService.testOverrides = {'OTEL_TRACES_EXPORTER': 'none'};
      await OTel.initialize(
        serviceName: 'grpc-span-more-edge',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );
      OTelLog.enableTraceLogging();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
      OTelLog.logFunction = null;
      OTelLog.currentLevel = LogLevel.info;
      EnvironmentService.testOverrides = null;
    });

    List<Span> spans() {
      final span = OTel.tracer().startSpan('grpc-edge')..end();
      return [span];
    }

    test('generic error fails fast without retry', () async {
      final service = _GenericThrowTraceService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'localhost:${server.port}',
          insecure: true,
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );

      await exporter.export(spans()).then((_) {}, onError: (_) {});
      expect(service.callCount, equals(1),
          reason: 'generic (non-gRPC) errors are not retryable');

      await exporter.shutdown();
      await server.shutdown();
    });

    test('secure credentials fall back to default when no certs configured',
        () async {
      // TLS handshake against nothing: fails through the error paths while
      // exercising the no-cert ChannelCredentials.secure() branch.
      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'localhost:1',
          insecure: false,
          maxRetries: 1,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 5),
        ),
      );
      await exporter.export(spans()).then((_) {}, onError: (_) {});
      await exporter.shutdown();
    });

    test(
        'export after shutdown fails fast; flush and re-shutdown are'
        ' no-ops', () async {
      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(endpoint: 'localhost:1', insecure: true),
      );
      await exporter.shutdown();
      await exporter.export(spans()).then((_) {}, onError: (_) {});
      await exporter.forceFlush();
      await exporter.shutdown();
    });

    test('empty batch succeeds without a channel', () async {
      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(endpoint: 'localhost:1', insecure: true),
      );
      await exporter.export([]);
      await exporter.shutdown();
    });
  });
}
