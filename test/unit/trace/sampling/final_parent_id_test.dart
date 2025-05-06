// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Final Parent ID Tests', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('root span parent ID is zero-filled', () {
      // Create a root span
      final tracer = OTel.tracerProvider().getTracer('test-tracer');
      final rootSpan = tracer.startSpan('root-span');

      // Print debug info
      print('Root span parent ID: ${rootSpan.spanContext.parentSpanId}');
      print('Root span parent ID toString: ${rootSpan.spanContext.parentSpanId}');
      print('Root span parent ID isValid: ${rootSpan.spanContext.parentSpanId!.isValid}');

      // Test that the parent ID is zero-filled
      expect(rootSpan.spanContext.parentSpanId, isNotNull);
      expect(rootSpan.spanContext.parentSpanId.toString(), equals('0000000000000000'));
      expect(rootSpan.spanContext.parentSpanId!.isValid, isFalse);

      rootSpan.end();
    });

    test('child span parent ID matches parent span ID', () {
      // Create a parent and child span
      final tracer = OTel.tracerProvider().getTracer('test-tracer');
      final parentSpan = tracer.startSpan('parent-span');
      final parentContext = Context.current.withSpan(parentSpan);
      final childSpan = tracer.startSpan('child-span', context: parentContext);

      // Print debug info
      print('Parent span ID: ${parentSpan.spanId}');
      print('Child span parent ID: ${childSpan.spanContext.parentSpanId}');

      // Test that the child's parent ID matches the parent's span ID
      expect(childSpan.spanContext.parentSpanId, equals(parentSpan.spanId));

      childSpan.end();
      parentSpan.end();
    });
  });
}
