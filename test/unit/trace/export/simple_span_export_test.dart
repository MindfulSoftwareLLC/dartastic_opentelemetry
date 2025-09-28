// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../../testing_utils/in_memory_span_exporter.dart';

void main() {
  group('Simple Span Export', () {
    late InMemorySpanExporter exporter;
    late SimpleSpanProcessor processor;
    late TracerProvider tracerProvider;

    setUp(() async {
      // Clean state for each test
      await OTel.reset();

      // Create in-memory exporter and processor
      exporter = InMemorySpanExporter();
      processor = SimpleSpanProcessor(exporter);

      // Initialize OTel with minimal configuration
      await OTel.initialize(
        serviceName: 'test-export-service',
        serviceVersion: '1.0.0',
        enableMetrics: false,
      );

      tracerProvider = OTel.tracerProvider();
      tracerProvider.addSpanProcessor(processor);
    });

    tearDown(() async {
      await processor.shutdown();
      await exporter.shutdown();
      await tracerProvider.shutdown();
      await OTel.reset();
    });

    test('Exports a span directly using processor', () async {
      exporter.clear();

      // Create a span directly
      final tracer = tracerProvider.getTracer('test-tracer');
      final span = tracer.startSpan('direct-test-span');

      // Add some attributes
      span.setStringAttribute<String>('test.key', 'test.value');
      span.setIntAttribute('test.number', 42);

      // End the span (this triggers export)
      span.end();

      // Force flush to ensure export
      await processor.forceFlush();

      // Verify span was exported
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('direct-test-span'), isTrue);

      final exportedSpan = exporter.findSpanByName('direct-test-span')!;
      expect(
          exportedSpan.attributes.getString('test.key'), equals('test.value'));
      expect(exportedSpan.attributes.getInt('test.number'), equals(42));
      expect(exportedSpan.isEnded, isTrue);
    });

    test('Exports multiple spans in order', () async {
      exporter.clear();

      final tracer = tracerProvider.getTracer('test-tracer');

      // Create multiple spans
      for (int i = 0; i < 5; i++) {
        final span = tracer.startSpan('span-$i');
        span.setIntAttribute('index', i);
        span.end();
      }

      // Force flush
      await processor.forceFlush();

      // Verify all spans were exported
      expect(exporter.spans, hasLength(5));

      // Verify each span
      for (int i = 0; i < 5; i++) {
        expect(exporter.hasSpanWithName('span-$i'), isTrue);
        final span = exporter.findSpanByName('span-$i')!;
        expect(span.attributes.getInt('index'), equals(i));
      }
    });

    test('Handles span processor lifecycle correctly', () async {
      exporter.clear();

      final tracer = tracerProvider.getTracer('test-tracer');
      final span = tracer.startSpan('lifecycle-test-span');

      // Verify span is not yet exported (only happens on end)
      expect(exporter.spans, isEmpty);

      // End the span (this automatically triggers processor.onEnd)
      span.end();

      // Force flush to ensure export
      await processor.forceFlush();

      // Now span should be exported
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('lifecycle-test-span'), isTrue);
    });

    test('Force flush exports pending spans', () async {
      exporter.clear();

      final tracer = tracerProvider.getTracer('test-tracer');
      final span = tracer.startSpan('flush-test-span');
      span.end();

      // Small delay to simulate processing time
      // ignore: inference_failure_on_instance_creation
      await Future.delayed(const Duration(milliseconds: 10));

      // Force flush should ensure export
      await processor.forceFlush();

      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('flush-test-span'), isTrue);
    });

    test('Shutdown prevents further exports', () async {
      exporter.clear();

      final tracer = tracerProvider.getTracer('test-tracer');

      // Create and export a span before shutdown
      final span1 = tracer.startSpan('before-shutdown');
      span1.end();
      await processor.forceFlush();

      expect(exporter.spans, hasLength(1));

      // Shutdown the processor
      await processor.shutdown();

      // Try to export another span after shutdown
      final span2 = tracer.startSpan('after-shutdown');
      span2.end();

      // The processor should not export spans after shutdown
      expect(exporter.spans, hasLength(1)); // Should still be 1, not 2
      expect(exporter.hasSpanWithName('before-shutdown'), isTrue);
      expect(exporter.hasSpanWithName('after-shutdown'), isFalse);
    });
  });
}
