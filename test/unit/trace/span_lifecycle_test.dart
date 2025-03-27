// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';

import 'package:test/test.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import '../../testing_utils/real_collector.dart';

void main() {
  late RealCollector collector;
  late TracerProvider tracerProvider;
  late Tracer tracer;
  final testPort = 4320; // Use unique port
  final testDir = Directory.current.path;
  final configPath = '$testDir/test/testing_utils/otelcol-config.yaml';
  final outputPath = '$testDir/test/testing_utils/spans.json';

  setUp(() async {
    // Ensure output file exists and is empty
    File(outputPath).writeAsStringSync('');

    // Start collector with configuration that exports to file
    collector = RealCollector(
      port: testPort,
      configPath: configPath,
      outputPath: outputPath,
    );
    await collector.start();

    // Reset and initialize OTel
    await OTel.reset();
    await OTel.initialize(
      endpoint: 'http://localhost:$testPort',
      serviceName: 'test-service');

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
    await collector.clear();

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

    // Get the exported span to inspect the raw format
    final spans = await collector.getSpans();
    expect(spans, isNotEmpty, reason: 'Expected at least one span to be exported');
    final exportedSpan = spans.first;
    print('Exported span data: $exportedSpan');

    print('Verifying span attributes...');
    await collector.assertSpanExists(
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

    // Get spans and verify the status
    final spans = await collector.getSpans();
    expect(spans, isNotEmpty);
    expect(spans.first['status'], isNotNull);
    expect(spans.first['status']['code'], equals(2)); // 2 corresponds to ERROR
    expect(spans.first['status']['message'], equals(statusDescription));

    print('Status test completed');
  });
}
