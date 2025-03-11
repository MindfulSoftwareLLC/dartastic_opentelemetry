// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:test/test.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'mock_collector.dart';

void main() {
  late MockCollector collector;
  late TracerProvider tracerProvider;
  late Tracer tracer;
  final testPort = 4318; // Use different port than default

  setUp(() async {
    collector = MockCollector(port: testPort);
    await collector.start();

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
    // Ensure proper cleanup order
    await tracerProvider.shutdown();
    await collector.stop();
    collector.clear(); // Explicitly clear spans

    // Add delay to ensure port is freed
    await Future.delayed(Duration(milliseconds: 100));
    await OTel.reset();
  });

  test('MockCollector receives spans within timeout period', () async {
    // Create and end first span
    final span1 = tracer.startSpan('test-span-1');
    span1.end();

    // Create and end second span
    final span2 = tracer.startSpan('test-span-2');
    span2.end();

    // Wait for spans and verify
    print('Waiting for spans...');
    try {
      await collector.waitForSpans(2, timeout: Duration(seconds: 5));
      print('Successfully received both spans');
    } catch (e) {
      print('Failed to receive spans: $e');
      print('Current span count: ${collector.spanCount}');
      rethrow;
    }

    // Verify both spans were received
    expect(collector.spanCount, equals(2));
    collector.assertSpanExists(name: 'test-span-1');
    collector.assertSpanExists(name: 'test-span-2');
  });

  test('MockCollector clears spans between tests', () async {
    expect(collector.spanCount, equals(0));

    // Create and end a span
    final span = tracer.startSpan('test-cleanup');
    span.end();

    // Wait briefly
    await Future.delayed(Duration(milliseconds: 100));

    // Clear and verify
    collector.clear();
    expect(collector.spanCount, equals(0));
  });

  test('MockCollector properly handles concurrent span exports', () async {
    // Create multiple spans concurrently
    final futures = List.generate(5, (index) async {
      final span = tracer.startSpan('concurrent-span-$index');
      await Future.delayed(Duration(milliseconds: 10 * index)); // Stagger slightly
      span.end();
    });

    // Wait for all spans to be created and ended
    await Future.wait(futures);

    // Wait for spans to be exported
    try {
      await collector.waitForSpans(5, timeout: Duration(seconds: 5));
      print('Successfully received all concurrent spans');

      // Print debug info
      print('Concurrent spans received:');
      for (var i = 0; i < 5; i++) {
        collector.assertSpanExists(name: 'concurrent-span-$i');
        print('  Found span: concurrent-span-$i');
      }
    } catch (e) {
      print('Failed to receive concurrent spans: $e');
      print('Current span count: ${collector.spanCount}');
      rethrow;
    }

    expect(collector.spanCount, equals(5));
  });
}
