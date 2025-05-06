// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Sampling Debugging', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('explicit span ID generation in tracer', () {
      // Create a specific span context to use in testing
      final originalSpanId = OTel.spanId();
      final explicitContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: originalSpanId,
      );

      // Create a span using this explicit context
      final tracer = OTel.tracerProvider().getTracer('test');
      final span = tracer.startSpan(
        'test-span',
        spanContext: explicitContext,
      );

      // Verify the span has a new ID, not the one we provided
      expect(span.spanContext.spanId, isNot(equals(originalSpanId)));

      // But the trace ID should match
      expect(span.spanContext.traceId, equals(explicitContext.traceId));

      span.end();
    });

    test('sampling flags are correctly set', () {
      // Test with AlwaysOnSampler
      final provider1 = OTel.addTracerProvider(
        'always-on',
        sampler: const AlwaysOnSampler(),
      );
      final tracer1 = provider1.getTracer('test');
      final span1 = tracer1.startSpan('test');

      expect(span1.spanContext.traceFlags.isSampled, isTrue, reason: 'AlwaysOnSampler should set sampled flag to true');

      // Test with AlwaysOffSampler
      final provider2 = OTel.addTracerProvider(
        'always-off',
        sampler: const AlwaysOffSampler(),
      );
      final tracer2 = provider2.getTracer('test');
      final span2 = tracer2.startSpan('test');

      expect(span2.spanContext.traceFlags.isSampled, isFalse, reason: 'AlwaysOffSampler should set sampled flag to false');

      span1.end();
      span2.end();
    });

    test('parent sampling decisions are correctly inherited', () {
      // Setup with ParentBasedSampler
      final tracerProvider = OTel.addTracerProvider(
        'parent-based',
        sampler: ParentBasedSampler(const AlwaysOnSampler()),
      );
      final tracer = tracerProvider.getTracer('test');

      // Create a parent span that is sampled
      OTel.traceFlags(TraceFlags.SAMPLED_FLAG);
      final parent = tracer.startSpan('parent');
      expect(parent.spanContext.traceFlags.isSampled, isTrue);

      // Create a context with this span
      final parentContext = OTel.context().withSpan(parent);

      // Create a child span with this context
      final child = tracer.startSpan(
        'child',
        context: parentContext,
      );

      // Child should inherit parent's sampling decision
      expect(child.spanContext.traceFlags.isSampled, isTrue);
      expect(child.spanContext.traceId, equals(parent.spanContext.traceId));
      expect(child.spanContext.parentSpanId, equals(parent.spanContext.spanId));
      expect(child.spanContext.spanId.toString(), isNot(equals(parent.spanContext.spanId.toString())));

      parent.end();
      child.end();
    });
  });
}
