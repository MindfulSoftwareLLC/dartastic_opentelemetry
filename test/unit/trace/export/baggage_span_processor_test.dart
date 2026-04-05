// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../../testing_utils/in_memory_span_exporter.dart';

void main() {
  group('BaggageSpanProcessor', () {
    late InMemorySpanExporter exporter;
    late SimpleSpanProcessor exportProcessor;
    late BaggageSpanProcessor baggageProcessor;
    late TracerProvider tracerProvider;

    setUp(() async {
      // Clean state for each test
      await OTel.reset();

      // Create processors
      exporter = InMemorySpanExporter();
      exportProcessor = SimpleSpanProcessor(exporter);
      baggageProcessor = const BaggageSpanProcessor();

      // Initialize OTel with minimal configuration
      await OTel.initialize(
        serviceName: 'test-baggage-service',
        serviceVersion: '1.0.0',
        enableMetrics: false,
      );

      tracerProvider = OTel.tracerProvider();
      // Add baggage processor first so it runs before export
      tracerProvider.addSpanProcessor(baggageProcessor);
      tracerProvider.addSpanProcessor(exportProcessor);
    });

    tearDown(() async {
      await exportProcessor.shutdown();
      await exporter.shutdown();
      await tracerProvider.shutdown();
      await OTel.reset();
    });

    test('Copies baggage entries to span attributes on start', () async {
      exporter.clear();

      // Create baggage with multiple entries
      final baggage = OTel.baggage()
          .copyWith('client.session.id', 'session-123')
          .copyWith('user.id', 'user-456')
          .copyWith('deployment.environment', 'staging');

      // Run with baggage context
      final context = OTel.context().withBaggage(baggage);
      await context.run(() async {
        final tracer = tracerProvider.getTracer('test-tracer');
        final span = tracer.startSpan('test-span-with-baggage');
        span.end();
      });

      // Force flush to ensure export
      await exportProcessor.forceFlush();

      // Verify span was exported with baggage attributes
      expect(exporter.spans, hasLength(1));
      final exportedSpan = exporter.spans.first;

      expect(exportedSpan.attributes.getString('client.session.id'),
          equals('session-123'));
      expect(exportedSpan.attributes.getString('user.id'), equals('user-456'));
      expect(exportedSpan.attributes.getString('deployment.environment'),
          equals('staging'));
    });

    test('Handles empty baggage gracefully', () async {
      exporter.clear();

      // Create empty baggage
      final baggage = OTel.baggage();

      // Run with empty baggage context
      final context = OTel.context().withBaggage(baggage);
      await context.run(() async {
        final tracer = tracerProvider.getTracer('test-tracer');
        final span = tracer.startSpan('test-span-empty-baggage');
        span.end();
      });

      // Force flush to ensure export
      await exportProcessor.forceFlush();

      // Verify span was exported without baggage attributes
      expect(exporter.spans, hasLength(1));
      final exportedSpan = exporter.spans.first;
      expect(exportedSpan.name, equals('test-span-empty-baggage'));
      // Span should have been created successfully without any baggage attributes
    });

    test('Handles no baggage context gracefully', () async {
      exporter.clear();

      // Run without any baggage context
      final tracer = tracerProvider.getTracer('test-tracer');
      final span = tracer.startSpan('test-span-no-baggage');
      span.end();

      // Force flush to ensure export
      await exportProcessor.forceFlush();

      // Verify span was exported successfully
      expect(exporter.spans, hasLength(1));
      final exportedSpan = exporter.spans.first;
      expect(exportedSpan.name, equals('test-span-no-baggage'));
    });

    test('Ignores baggage metadata', () async {
      exporter.clear();

      // Create baggage with metadata
      final baggage = OTel.baggage().copyWith('transaction.id', 'tx-789',
          'metadata=source:mobile-app;priority=high');

      // Run with baggage context
      final context = OTel.context().withBaggage(baggage);
      await context.run(() async {
        final tracer = tracerProvider.getTracer('test-tracer');
        final span = tracer.startSpan('test-span-with-metadata');
        span.end();
      });

      // Force flush to ensure export
      await exportProcessor.forceFlush();

      // Verify span has baggage value but not metadata
      expect(exporter.spans, hasLength(1));
      final exportedSpan = exporter.spans.first;

      // The attribute should contain only the value, not the metadata
      expect(exportedSpan.attributes.getString('transaction.id'),
          equals('tx-789'));
    });

    test('Works with nested spans in baggage context', () async {
      exporter.clear();

      // Create baggage
      final baggage = OTel.baggage().copyWith('request.id', 'req-999');

      // Run with baggage context and create nested spans
      final context = OTel.context().withBaggage(baggage);
      await context.run(() async {
        final tracer = tracerProvider.getTracer('test-tracer');

        final parentSpan = tracer.startSpan('parent-span');
        final childSpan = tracer.startSpan('child-span');

        childSpan.end();
        parentSpan.end();
      });

      // Force flush to ensure export
      await exportProcessor.forceFlush();

      // Both spans should have the baggage attribute
      expect(exporter.spans, hasLength(2));

      for (final span in exporter.spans) {
        expect(span.attributes.getString('request.id'), equals('req-999'));
      }
    });

    test('Baggage changes are reflected in new spans', () async {
      exporter.clear();

      final tracer = tracerProvider.getTracer('test-tracer');

      // First context with initial baggage
      final baggage1 = OTel.baggage().copyWith('stage', 'initial');
      await OTel.context().withBaggage(baggage1).run(() async {
        final span1 = tracer.startSpan('span-1');
        span1.end();
      });

      // Second context with updated baggage
      final baggage2 = OTel.baggage().copyWith('stage', 'updated');
      await OTel.context().withBaggage(baggage2).run(() async {
        final span2 = tracer.startSpan('span-2');
        span2.end();
      });

      // Force flush to ensure export
      await exportProcessor.forceFlush();

      // Verify both spans have different baggage values
      expect(exporter.spans, hasLength(2));

      final span1 = exporter.findSpanByName('span-1')!;
      expect(span1.attributes.getString('stage'), equals('initial'));

      final span2 = exporter.findSpanByName('span-2')!;
      expect(span2.attributes.getString('stage'), equals('updated'));
    });

    test('onEnd is a no-op', () async {
      // This test verifies that onEnd doesn't throw or cause issues
      final span = OTel.tracer().startSpan('test-span');
      await baggageProcessor.onEnd(span);
      // If we get here without errors, the test passes
      span.end();
    });

    test('onNameUpdate is a no-op', () async {
      // This test verifies that onNameUpdate doesn't throw or cause issues
      final span = OTel.tracer().startSpan('test-span');
      await baggageProcessor.onNameUpdate(span, 'new-name');
      // If we get here without errors, the test passes
      span.end();
    });

    test('shutdown is a no-op', () async {
      // This test verifies that shutdown doesn't throw or cause issues
      await baggageProcessor.shutdown();
      // If we get here without errors, the test passes
    });

    test('forceFlush is a no-op', () async {
      // This test verifies that forceFlush doesn't throw or cause issues
      await baggageProcessor.forceFlush();
      // If we get here without errors, the test passes
    });

    test('Processor can be used with multiple tracers', () async {
      exporter.clear();

      final baggage = OTel.baggage().copyWith('common.attribute', 'shared');

      final context = OTel.context().withBaggage(baggage);
      await context.run(() async {
        final tracer1 = tracerProvider.getTracer('tracer-1');
        final tracer2 = tracerProvider.getTracer('tracer-2');

        final span1 = tracer1.startSpan('span-from-tracer-1');
        final span2 = tracer2.startSpan('span-from-tracer-2');

        span1.end();
        span2.end();
      });

      // Force flush to ensure export
      await exportProcessor.forceFlush();

      // Both spans from different tracers should have baggage attributes
      expect(exporter.spans, hasLength(2));

      for (final span in exporter.spans) {
        expect(span.attributes.getString('common.attribute'), equals('shared'));
      }
    });

    test('Processor works with high cardinality baggage', () async {
      exporter.clear();

      // Create baggage with many entries
      var baggage = OTel.baggage();
      for (int i = 0; i < 20; i++) {
        baggage = baggage.copyWith('key$i', 'value$i');
      }

      final context = OTel.context().withBaggage(baggage);
      await context.run(() async {
        final tracer = tracerProvider.getTracer('test-tracer');
        final span = tracer.startSpan('span-with-many-attributes');
        span.end();
      });

      // Force flush to ensure export
      await exportProcessor.forceFlush();

      // Verify all baggage entries were added as attributes
      expect(exporter.spans, hasLength(1));
      final exportedSpan = exporter.spans.first;

      for (int i = 0; i < 20; i++) {
        expect(exportedSpan.attributes.getString('key$i'), equals('value$i'));
      }
    });
  });
}
