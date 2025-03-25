// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

import '../testing_utils/real_collector.dart';

void main() {
  group('Context Propagation', () {
    late RealCollector collector;
    late TracerProvider tracerProvider;
    late Tracer tracer;
    final testPort = 4321; // Use unique port
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

      // Initialize OTel
      await OTel.reset();
      await OTel.initialize(
        endpoint: 'http://localhost:$testPort',
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );

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
      await tracerProvider.shutdown();
      await collector.stop();
      await collector.clear();

      // Add delay to ensure port is freed
      await Future.delayed(Duration(milliseconds: 100));
      await OTel.reset();
    });

    test('handles attributes across context boundaries', () async {
      print('Starting context attributes test');
      final attributes = <String, Object>{
        'test.key': 'test-value',
      }.toAttributes();

      final span = tracer.startSpan(
        'attributed-span',
        attributes: attributes,
      );
      print('Ending span with attributes...');
      span.end();

      // Wait for export
      print('Waiting for span to be exported...');
      await collector.waitForSpans(1);

      // Verify span
      print('Verifying span attributes...');
      await collector.assertSpanExists(
        name: 'attributed-span',
        attributes: {
          'test.key': 'test-value',
        },
      );
      print('Context attributes test completed');
    });

    test('propagates context between spans correctly using withSpan', () async {
      print('Starting context propagation test with withSpan');

      // Create parent span
      final parentSpan = tracer.startSpan('parent');
      final parentSpanId = parentSpan.spanContext.spanId.toString();

      // Create a context with the parent span
      final parentContext = OTel.context().withSpan(parentSpan);

      // Create child span with parent context
      final childSpan = tracer.startSpan(
        'child',
        context: parentContext,
      );

      // End spans in the correct order
      print('Ending spans...');
      childSpan.end();
      parentSpan.end();

      // Wait for export
      print('Waiting for spans to be exported...');
      await collector.waitForSpans(2);

      // Get all spans
      final spans = await collector.getSpans();
      print('Got ${spans.length} spans: $spans');

      // Find parent and child spans
      final parentExportedSpan = spans.firstWhere((s) => s['name'] == 'parent');
      final childExportedSpan = spans.firstWhere((s) => s['name'] == 'child');

      // Verify parent-child relationship
      expect(childExportedSpan['parentSpanId'], isNotNull);

      // Verify trace IDs match
      expect(
        childExportedSpan['traceId'],
        equals(parentExportedSpan['traceId']),
        reason: 'Child span should inherit trace ID from parent',
      );
    });

    test('withSpanContext prevents trace ID changes', () async {
      // Create first span with its own trace
      final span1 = tracer.startSpan('span1');
      final context1 = OTel.context().withSpan(span1);

      // Create second span with different trace
      // Create completely new context with different span
      final newContext = OTel.context(); // Fresh context
      final span2 = tracer.startSpan('span2', context: newContext); // New root span

      // This should throw because we're trying to change trace ID
      expect(
        () => context1.withSpanContext(span2.spanContext),
        throwsArgumentError,
        reason: 'Should not allow changing trace ID via withSpanContext',
      );

      // Clean up
      span1.end();
      span2.end();
    });

    test('allows withSpanContext for cross-process propagation', () async {
      // Create a span context with isRemote=true to simulate cross-process propagation
      final remoteTraceId = OTelAPI.traceId();
      final remoteSpanId = OTelAPI.spanId();
      final remoteContext = OTelAPI.spanContext(
        traceId: remoteTraceId,
        spanId: remoteSpanId,
        isRemote: true,
      );

      // This should work fine because we're starting a new trace
      final context = OTel.context().withSpanContext(remoteContext);

      // Create a child span
      final childSpan = tracer.startSpan(
        'child',
        context: context,
      );

      // Verify the child inherited the remote trace ID
      expect(
        childSpan.spanContext.traceId,
        equals(remoteTraceId),
        reason: 'Child span should inherit remote trace ID',
      );

      childSpan.end();
    });
  });
}
