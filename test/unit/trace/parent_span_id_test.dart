// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Parent Span ID Tests', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('root span should have invalid parent span ID as zeros', () {
      final tracer = OTel.tracerProvider().getTracer('test');
      final rootSpan = tracer.startSpan('root');

      // Test that parent span ID is properly zero-filled
      expect(rootSpan.spanContext.parentSpanId.toString(), equals('0' * 16));
      expect(rootSpan.spanContext.parentSpanId!.isValid, isFalse);

      rootSpan.end();
    });

    test('child span should have parent span ID set', () {
      final tracer = OTel.tracerProvider().getTracer('test');
      final parentSpan = tracer.startSpan('parent');
      final parentContext = Context.current.withSpan(parentSpan);

      final childSpan = tracer.startSpan('child', context: parentContext);

      // Parent span ID should be set to the parent's span ID
      expect(childSpan.spanContext.parentSpanId, equals(parentSpan.spanContext.spanId));
      expect(childSpan.spanContext.parentSpanId!.isValid, isTrue);

      childSpan.end();
      parentSpan.end();
    });

    test('parent span IDs are correctly handled in deep hierarchies', () {
      final tracer = OTel.tracerProvider().getTracer('test');

      // Create a chain of spans: root -> child1 -> child2 -> child3
      final rootSpan = tracer.startSpan('root');
      final rootContext = Context.current.withSpan(rootSpan);

      final child1 = tracer.startSpan('child1', context: rootContext);
      final child1Context = Context.current.withSpan(child1);

      final child2 = tracer.startSpan('child2', context: child1Context);
      final child2Context = Context.current.withSpan(child2);

      final child3 = tracer.startSpan('child3', context: child2Context);

      // Verify parent relationships
      expect(rootSpan.spanContext.parentSpanId.toString(), equals('0' * 16));
      expect(child1.spanContext.parentSpanId, equals(rootSpan.spanContext.spanId));
      expect(child2.spanContext.parentSpanId, equals(child1.spanContext.spanId));
      expect(child3.spanContext.parentSpanId, equals(child2.spanContext.spanId));

      // End all spans
      child3.end();
      child2.end();
      child1.end();
      rootSpan.end();
    });
  });
}
