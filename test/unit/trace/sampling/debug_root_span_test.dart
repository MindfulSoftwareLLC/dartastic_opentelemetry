// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Root Span Debug Tests', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('root span has proper zero parent ID', () {
      final tracer = OTel.tracerProvider().getTracer('test');
      final span = tracer.startSpan('root-span');

      // Print detailed debug info
      print('Span context: ${span.spanContext}');
      print('Span ID: ${span.spanId}');
      print('Trace ID: ${span.spanContext.traceId}');
      print('Parent Span ID: ${span.spanContext.parentSpanId}');
      print('Parent Span ID to string: ${span.spanContext.parentSpanId}');
      print(
          'Parent Span ID isValid: ${span.spanContext.parentSpanId?.isValid}');

      // Check that the parent span ID is all zeros for a root span
      expect(span.spanContext.parentSpanId, isNotNull);
      expect(
          span.spanContext.parentSpanId.toString(), equals('0000000000000000'));

      span.end();
    });

    test('child span has parent ID set to parent span ID', () {
      final tracer = OTel.tracerProvider().getTracer('test');
      final parentSpan = tracer.startSpan('parent-span');
      final parentContext = Context.current.withSpan(parentSpan);

      final childSpan = tracer.startSpan('child-span', context: parentContext);

      // Print detailed debug info
      print('Parent span ID: ${parentSpan.spanId}');
      print('Child parent span ID: ${childSpan.spanContext.parentSpanId}');

      // Check that the child's parent span ID matches the parent's span ID
      expect(childSpan.spanContext.parentSpanId, equals(parentSpan.spanId));

      childSpan.end();
      parentSpan.end();
    });

    test('manual creation of span context with invalid parent', () {
      // Create an invalid parent span ID
      final invalidParentId = OTel.spanIdInvalid();
      print('Invalid parent ID: $invalidParentId');
      print('Invalid parent ID isValid: ${invalidParentId.isValid}');

      // Create a span context with this invalid parent ID
      final context = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
        parentSpanId: invalidParentId,
      );

      // Check that the parent span ID is set correctly
      expect(context.parentSpanId, isNotNull);
      expect(context.parentSpanId.toString(), equals('0000000000000000'));
      expect(context.parentSpanId!.isValid, isFalse);
    });
  });
}
