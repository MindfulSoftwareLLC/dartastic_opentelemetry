// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/trace/tracer.dart';
import 'package:dartastic_opentelemetry/src/trace/tracer_provider.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  late Tracer tracer;
  late TracerProvider tracerProvider;
  late Context rootContext;

  setUp(() {
    // Initialize a fresh tracer provider and tracer for each test
    tracerProvider = OTel.tracerProvider();

    tracer = tracerProvider.getTracer(
      'test-tracer',
      version: '1.0.0',
    );

    rootContext = OTel.context();
  });

  group('Context Propagation', () {
    test('should maintain same trace ID between parent and child spans', () {
      final parentSpan = tracer.startSpan('parent', context: rootContext);
      final parentContext =
          Context.current.copyWithSpanContext(parentSpan.spanContext);

      final childSpan = tracer.startSpan('child', context: parentContext);
      (parentContext).copyWithSpanContext(childSpan.spanContext);

      expect(
          childSpan.spanContext.traceId, equals(parentSpan.spanContext.traceId),
          reason: 'Child span should inherit trace ID from parent');

      // Get the parent span ID from the  implementation
      expect((childSpan.spanContext).parentSpanId,
          equals(parentSpan.spanContext.spanId),
          reason: 'Child span should reference parent span ID');
    });

    test('should properly propagate span context through multiple levels', () {
      final span1 = tracer.startSpan('span1', context: rootContext);
      final context1 = (rootContext).copyWithSpanContext(span1.spanContext);

      final span2 = tracer.startSpan('span2', context: context1);
      final context2 = (context1).copyWithSpanContext(span2.spanContext);

      final span3 = tracer.startSpan('span3', context: context2);

      expect(span2.spanContext.traceId, equals(span1.spanContext.traceId));
      expect(span3.spanContext.traceId, equals(span1.spanContext.traceId));
      expect(
          (span2.spanContext).parentSpanId, equals(span1.spanContext.spanId));
      expect(
          (span3.spanContext).parentSpanId, equals(span2.spanContext.spanId));
    });

    test('should maintain context when using current context', () {
      final parentSpan = tracer.startSpan('parent', context: rootContext);
      final parentContext =
          (rootContext).copyWithSpanContext(parentSpan.spanContext);

      parentContext.run<void>(() async {
        final currentContext = Context.current;
        final currentSpanContext = currentContext.spanContext;

        expect(
            currentSpanContext?.spanId, equals(parentSpan.spanContext.spanId),
            reason: 'Current span should match parent span');

        final childSpan = tracer.startSpan('child', context: currentContext);

        expect(childSpan.spanContext.traceId,
            equals(parentSpan.spanContext.traceId),
            reason: 'Child span should inherit trace ID from current context');
        expect((childSpan.spanContext).parentSpanId,
            equals(parentSpan.spanContext.spanId),
            reason: 'Child span should reference current span as parent');
      });
    });
  });
}
