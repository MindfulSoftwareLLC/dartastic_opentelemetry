// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Parent Context Handling', () {
    late TracerProvider tracerProvider;
    late Tracer tracer;

    setUp(() async {
      await OTel.initialize(
        endpoint: 'http://localhost:4317',
        serviceName: 'test-service',
      );
      tracerProvider = OTel.tracerProvider();
      tracer = tracerProvider.getTracer('test-tracer');
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('uses current context when no context provided', () {
      // Set current context with a span
      final parentSpan = tracer.startSpan('parent');
      final parentContext = Context.current.withSpan(parentSpan);
      Context.current = parentContext;

      // Create span without explicit context
      final span = tracer.startSpan('child');

      // Verify parent relationship
      expect(span.spanContext.traceId, equals(parentSpan.spanContext.traceId));
      expect(
          span.spanContext.parentSpanId, equals(parentSpan.spanContext.spanId));

      // Reset current context
      Context.current = Context.root;
    });

    test('uses provided context over current context', () {
      // Create parent span and context
      final parentSpan1 = tracer.startSpan('parent1');
      final parentContext1 = Context.current.withSpan(parentSpan1);

      final parentSpan2 = tracer.startSpan('parent2');
      final parentContext2 = Context.current.withSpan(parentSpan2);

      // Set current context to parent1
      Context.current = parentContext1;

      // Create span with explicit parent2 context
      final span = tracer.startSpan('child', context: parentContext2);

      // Verify parent relationship is with parent2
      expect(span.spanContext.traceId, equals(parentSpan2.spanContext.traceId));
      expect(span.spanContext.parentSpanId,
          equals(parentSpan2.spanContext.spanId));

      // Reset current context
      Context.current = Context.root;
    });

    test('validates trace ID when using explicit span context', () {
      // Create parent span
      final parentSpan = tracer.startSpan('parent');
      final parentContext = Context.current.withSpan(parentSpan);

      // Create span context with different trace ID
      final differentTraceId =
          OTel.traceId(); // This will be different from parent's
      final spanContext = OTel.spanContext(
        traceId: differentTraceId,
        spanId: OTel.spanId(),
      );

      // Attempt to create child span with different trace ID
      expect(
          () => tracer.startSpan(
                'child',
                context: parentContext,
                spanContext: spanContext,
              ),
          throwsArgumentError,
          reason:
              'Should not allow creating span with different trace ID than parent');
    });

    test('uses explicit spanContext trace ID while generating new span ID', () {
      // Create parent span and context
      final parentSpan = tracer.startSpan('parent');
      final parentContext = Context.current.withSpan(parentSpan);

      expect(parentContext.spanContext, isNotNull);

      // Create explicit span context with same trace ID but different span ID
      final explicitSpanContext = OTel.spanContext(
        traceId: parentContext.spanContext!.traceId, // Same trace ID
        spanId: OTel.spanId(), // Different span ID
      );

      // Create span with both context and spanContext
      final span = tracer.startSpan(
        'child',
        context: parentContext,
        spanContext: explicitSpanContext,
      );

      // Verify:
      // 1. Trace ID matches parent (required by spec)
      expect(
          span.spanContext.traceId, equals(parentContext.spanContext!.traceId),
          reason: 'Child should use parent trace ID');

      // 2. Span ID is new (not the same as explicitSpanContext)
      expect(span.spanContext.spanId, isNot(equals(explicitSpanContext.spanId)),
          reason: 'Child should get new span ID');

      // 3. Parent span ID properly set
      expect(
          span.spanContext.parentSpanId, equals(parentSpan.spanContext.spanId),
          reason: 'Child should reference parent span ID');

      // 4. All IDs are valid
      expect(span.spanContext.isValid, isTrue,
          reason: 'Child context should be valid');
    });

    test('uses bad explicit spanContext over context parent', () {
      // Create parent span and context
      final parentSpan = tracer.startSpan('parent');
      final parentContext = Context.current.withSpan(parentSpan);

      // Create explicit span context
      final explicitSpanContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
      );

      expect(() => parentContext.withSpanContext(explicitSpanContext),
          throwsArgumentError,
          reason: 'Should not allow changing trace ID via withSpanContext');
    });

    test('properly inherits parent trace ID in various scenarios', () {
      // Create root span
      final rootSpan = tracer.startSpan('root');
      final rootContext = Context.current.withSpan(rootSpan);

      // 1. Create child with parent context
      final childViaContext = tracer.startSpan(
        'child1',
        context: rootContext,
      );
      expect(childViaContext.spanContext.traceId,
          equals(rootSpan.spanContext.traceId),
          reason: 'Child via context should inherit parent trace ID');

      // 2. Create child with explicit parent span
      final childViaParentSpan = tracer.startSpan(
        'child2',
        parentSpan: rootSpan,
      );
      expect(childViaParentSpan.spanContext.traceId,
          equals(rootSpan.spanContext.traceId),
          reason: 'Child via parent span should inherit parent trace ID');

      // 3. Create child with matching spanContext
      final matchingSpanContext = OTel.spanContext(
        traceId: rootSpan.spanContext.traceId, // Same trace ID
        spanId: OTel.spanId(),
      );
      final childViaSpanContext = tracer.startSpan(
        'child3',
        context: rootContext,
        spanContext: matchingSpanContext,
      );
      expect(childViaSpanContext.spanContext.traceId,
          equals(rootSpan.spanContext.traceId),
          reason: 'Child via matching span context should maintain trace ID');
    });

    test('throws when parentSpan and spanContext have different spanIds', () {
      final parentSpan = tracer.startSpan('parent');
      final explicitSpanContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
        parentSpanId: OTel.spanId(), // Different from parentSpan's spanId
      );

      expect(
        () => tracer.startSpan(
          'child',
          parentSpan: parentSpan,
          spanContext: explicitSpanContext,
        ),
        throwsArgumentError,
      );
    });

    test('uses parentSpan over context parent', () {
      // Create two potential parent spans
      final contextParentSpan = tracer.startSpan('context-parent');
      final explicitParentSpan = tracer.startSpan('explicit-parent');
      final parentContext = Context.current.withSpan(contextParentSpan);

      // Create span with both context parent and explicit parent
      final span = tracer.startSpan(
        'child',
        context: parentContext,
        parentSpan: explicitParentSpan,
      );

      // Verify explicit parent was used
      expect(span.spanContext.traceId,
          equals(explicitParentSpan.spanContext.traceId));
      expect(span.spanContext.parentSpanId,
          equals(explicitParentSpan.spanContext.spanId));
    });

    test('creates root span when no parent context available', () {
      final span = tracer.startSpan('root');

      // Verify the parent span ID is zero-filled (invalid)
      expect(span.spanContext.parentSpanId, isNotNull);
      expect(
          span.spanContext.parentSpanId.toString(), equals('0000000000000000'));
      expect(span.spanContext.traceId.isValid, isTrue);
      expect(span.spanContext.spanId.isValid, isTrue);
    });
  });
}
