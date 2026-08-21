// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Regression tests for https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/220
//
// The OTLP spec (specification/protocol/exporter.md#configuration-options)
// defaults the endpoint to `http://localhost:4317` for OTLP/gRPC and
// `http://localhost:4318` for the two HTTP protocols. The default must be
// picked per signal AFTER the protocol is resolved; a single 4318 default
// applied before the protocol is known silently mis-routes gRPC-only
// deployments to the wrong port.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  final logs = <String>[];

  setUp(() {
    logs.clear();
    OTelLog.logFunction = logs.add;
    OTelLog.currentLevel = LogLevel.debug;
  });

  tearDown(() async {
    await OTel.reset();
    EnvironmentService.testOverrides = null;
    OTelLog.currentLevel = LogLevel.error;
  });

  test('default (http/protobuf) endpoint is port 4318 for every signal',
      () async {
    await OTel.initialize(serviceName: 'http-default-test');

    final spanProcessor =
        OTel.tracerProvider().spanProcessors.first as BatchSpanProcessor;
    expect(spanProcessor.exporter, isA<OtlpHttpSpanExporter>());

    final metricReader = OTel.meterProvider().metricReaders.first
        as PeriodicExportingMetricReader;
    expect(metricReader.exporter, isA<OtlpHttpMetricExporter>());

    final logProcessor = OTel.loggerProvider().logRecordProcessors.first
        as BatchLogRecordProcessor;
    expect(logProcessor.exporter, isA<OtlpHttpLogRecordExporter>());

    expect(logs.join('\n'), contains('endpoint: http://localhost:4318'));
  });

  test('grpc protocol defaults to port 4317 for traces', () async {
    EnvironmentService.testOverrides = {'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc'};
    await OTel.initialize(serviceName: 'grpc-traces-test');

    final spanProcessor =
        OTel.tracerProvider().spanProcessors.first as BatchSpanProcessor;
    expect(spanProcessor.exporter, isA<OtlpGrpcSpanExporter>());

    expect(logs.join('\n'), contains('endpoint: http://localhost:4317'));
  });

  test('grpc protocol defaults to port 4317 for metrics', () async {
    EnvironmentService.testOverrides = {'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc'};
    await OTel.initialize(serviceName: 'grpc-metrics-test');

    final metricReader = OTel.meterProvider().metricReaders.first
        as PeriodicExportingMetricReader;
    expect(metricReader.exporter, isA<OtlpGrpcMetricExporter>());

    expect(
      logs.join('\n'),
      contains('OtlpGrpcMetricExporter for http://localhost:4317'),
    );
  });

  test('grpc protocol defaults to port 4317 for logs', () async {
    EnvironmentService.testOverrides = {'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc'};
    await OTel.initialize(serviceName: 'grpc-logs-test');

    final logProcessor = OTel.loggerProvider().logRecordProcessors.first
        as BatchLogRecordProcessor;
    expect(logProcessor.exporter, isA<OtlpGrpcLogRecordExporter>());

    expect(logs.join('\n'), contains('endpoint: http://localhost:4317'));
  });

  test('explicit endpoint is passed through instead of a default', () async {
    await OTel.initialize(
      serviceName: 'explicit-endpoint-test',
      endpoint: 'http://collector:9999',
    );

    final spanProcessor =
        OTel.tracerProvider().spanProcessors.first as BatchSpanProcessor;
    expect(spanProcessor.exporter, isA<OtlpHttpSpanExporter>());

    expect(logs.join('\n'), contains('endpoint: http://collector:9999'));
  });

  test('http/json protocol uses port 4318', () async {
    EnvironmentService.testOverrides = {
      'OTEL_EXPORTER_OTLP_PROTOCOL': 'http/json',
    };
    await OTel.initialize(serviceName: 'http-json-test');

    final spanProcessor =
        OTel.tracerProvider().spanProcessors.first as BatchSpanProcessor;
    expect(spanProcessor.exporter, isA<OtlpHttpSpanExporter>());

    expect(logs.join('\n'), contains('endpoint: http://localhost:4318'));
  });
}
