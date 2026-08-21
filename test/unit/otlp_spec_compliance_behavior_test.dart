// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Behavioral end-to-end regression tests for issues #213, #220, and #228,
// asserting the user-observable contract rather than internal wiring:
// OTel.initialize() completing where it used to throw (#213), export bytes
// actually arriving at the spec-default gRPC port 4317 (#220), and the
// User-Agent actually sent on the wire (#228). Written independently of the
// implementation, from the issues and OTel spec v1.60.0, during review of
// PR #238; each test was verified red on the pre-fix SDK.

@Timeout(Duration(seconds: 60))
library;

import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/collector/trace/v1/trace_service.pbgrpc.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:test/test.dart';

/// gRPC TraceService that records export calls and their client metadata.
class _CapturingTraceService extends TraceServiceBase {
  final userAgents = <String?>[];
  final firstCall = Completer<void>();

  @override
  Future<ExportTraceServiceResponse> export(
    grpc.ServiceCall call,
    ExportTraceServiceRequest request,
  ) async {
    userAgents.add(call.clientMetadata?['user-agent']);
    if (!firstCall.isCompleted) firstCall.complete();
    return ExportTraceServiceResponse();
  }
}

Future<grpc.Server> _serveCapture(_CapturingTraceService svc, int port) async {
  final server = grpc.Server.create(services: [svc]);
  await server.serve(address: InternetAddress.loopbackIPv4, port: port);
  return server;
}

void _endSpanAndFlush() {
  OTel.tracerProvider().getTracer('red').startSpan('red-span').end();
  // On the unfixed SDK the exporter may dial a port nobody listens on;
  // don't let that flush failure become an unhandled async error.
  unawaited(OTel.tracerProvider().forceFlush().catchError((_) {}));
}

void main() {
  setUp(() async {
    await OTel.reset();
  });

  tearDown(() async {
    EnvironmentService.testOverrides = null;
    await OTel.reset();
  });

  group('#213 empty env var value is treated as unset', () {
    test('EnvironmentService.getValue returns null for an empty value', () {
      EnvironmentService.testOverrides = {'OTEL_SERVICE_NAME': ''};
      expect(
        EnvironmentService.instance.getValue('OTEL_SERVICE_NAME'),
        isNull,
      );
    });

    test('initialize: empty OTEL_EXPORTER_OTLP_ENDPOINT means default',
        () async {
      EnvironmentService.testOverrides = {'OTEL_EXPORTER_OTLP_ENDPOINT': ''};
      await OTel.initialize(
        serviceName: 'red-213',
        enableMetrics: false,
        enableLogs: false,
      );
      // Completing without an ArgumentError is the spec behavior.
    });

    test('initialize: empty OTEL_SERVICE_NAME means default', () async {
      EnvironmentService.testOverrides = {'OTEL_SERVICE_NAME': ''};
      await OTel.initialize(enableMetrics: false, enableLogs: false);
    });
  });

  group('#220 OTLP/gRPC endpoint default', () {
    test('protocol grpc with no endpoint exports to localhost:4317', () async {
      final svc = _CapturingTraceService();
      final grpc.Server server;
      try {
        server = await _serveCapture(svc, 4317);
      } on SocketException {
        fail('port 4317 is already in use — stop the local collector and '
            'rerun this test');
      }
      addTearDown(server.shutdown);

      EnvironmentService.testOverrides = {
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
      };
      await OTel.initialize(
        serviceName: 'red-220',
        enableMetrics: false,
        enableLogs: false,
      );
      _endSpanAndFlush();

      await svc.firstCall.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail(
          'no export arrived on the spec-default gRPC port 4317 within 5s — '
          'the exporter presumably targeted the OTLP/HTTP port 4318',
        ),
      );
    });
  });

  group('#228 OTLP exporter User-Agent', () {
    test('gRPC export identifies the exporter per spec', () async {
      final svc = _CapturingTraceService();
      final server = await _serveCapture(svc, 0);
      addTearDown(server.shutdown);

      EnvironmentService.testOverrides = {
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:${server.port}',
      };
      await OTel.initialize(
        serviceName: 'red-228-grpc',
        enableMetrics: false,
        enableLogs: false,
      );
      _endSpanAndFlush();

      await svc.firstCall.future.timeout(const Duration(seconds: 5));
      expect(svc.userAgents.first, startsWith('OTel-OTLP-Exporter-Dart/'));
    });

    test('HTTP export identifies the exporter per spec', () async {
      final captured = Completer<String?>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        final ua = req.headers.value(HttpHeaders.userAgentHeader);
        req.response.statusCode = 200;
        req.response.add(ExportTraceServiceResponse().writeToBuffer());
        await req.response.close();
        if (!captured.isCompleted) captured.complete(ua);
      });

      EnvironmentService.testOverrides = {
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:${server.port}',
      };
      await OTel.initialize(
        serviceName: 'red-228-http',
        enableMetrics: false,
        enableLogs: false,
      );
      _endSpanAndFlush();

      final ua = await captured.future.timeout(const Duration(seconds: 5));
      expect(ua, startsWith('OTel-OTLP-Exporter-Dart/'));
    });
  });
}
