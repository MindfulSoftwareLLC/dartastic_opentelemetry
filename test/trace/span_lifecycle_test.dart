// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:test/test.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/opentelemetry_proto_dart.dart' as proto;

import '../testing_utils/mock_collector.dart';

void main() {
  late MockCollector collector;
  late TracerProvider tracerProvider;
  late Tracer tracer;
  final testPort = 4320; // Use unique port

  setUp(() async {
    await OTel.reset();
    await OTel.initialize(
      endpoint: 'http://localhost:$testPort',
      serviceName: 'test-service');
    collector = MockCollector(port: testPort);
    await collector.start();

    tracerProvider = OTel.tracerProvider();

    final exporter = OtlpGrpcSpanExporter(
      OtlpGrpcExporterConfig(
        endpoint: 'http://localhost:$testPort',
        insecure: true,
      ),
    );

    final processor = SimpleSpanProcessor(exporter);
    tracerProvider.addSpanProcessor(processor);
    tracer = tracerProvider.getTracer('test-tracer');
  });

  tearDown(() async {
    // Ensure proper cleanup order
    await tracerProvider.shutdown();
    await collector.stop();
    collector.clear(); // Explicitly clear spans

    // Add delay to ensure port is freed
    await Future.delayed(Duration(milliseconds: 100));
  });

  test('span should support setting attributes', () async {
    // Create attributes using the Map extension
    final attributes = <String, Object>{
      'string.key': 'value',
      'int.key': 42,
      'bool.key': true,
      'additional.key': 'added-later',
    }.toAttributes();

    final span = tracer.startSpan(
      'test-span',
      attributes: attributes,
    );

    span.end();

    print('Waiting for span with attributes...');
    await collector.waitForSpans(1);

    print('Verifying span attributes...');
    collector.assertSpanExists(
      name: 'test-span',
      attributes: {
        'string.key': 'value',
        'int.key': 42,
        'bool.key': true,
        'additional.key': 'added-later',
      },
    );
  });

  test('span status should be properly exported', () async {
    print('Starting status test');
    final statusCode = SpanStatusCode.Error;
    final statusDescription = 'Something went wrong';
    final span = tracer.startSpan('status-test-span');
    span.setStatus(statusCode, statusDescription);
    print('Ending span with error status');
    span.end();

    print('Waiting for error status span...');
    await collector.waitForSpans(1);

    print('Verifying error status...');
    collector.assertSpanExists(
      name: 'status-test-span',
      status: proto.Status_StatusCode.STATUS_CODE_ERROR,
      statusMessage: statusDescription,
    );
    print('Status test completed');
  });
}
