// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:test/test.dart';

void main() {
  group('Debug Invalid Parent ID Tests', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('spanIdInvalid returns a proper zero-filled ID', () {
      final invalidId = OTel.spanIdInvalid();
      expect(invalidId.toString(), equals('0000000000000000'));
      expect(invalidId.isValid, isFalse, reason: 'Invalid span ID should not be valid');
    });

    test('root span creation sets proper parent span ID directly', () {
      // Directly test the span context creation
      final traceId = OTel.traceId();
      final spanId = OTel.spanId();
      final parentSpanId = OTel.spanIdInvalid();

      // Create a span context with explicit invalid parent
      final spanContext = OTel.spanContext(
        traceId: traceId,
        spanId: spanId,
        parentSpanId: parentSpanId,
      );

      // Verify the parent span ID is zeros, not null
      expect(spanContext.parentSpanId, isNotNull, reason: 'Parent span ID should not be null');
      expect(spanContext.parentSpanId.toString(), equals('0000000000000000'),
             reason: 'Parent span ID should be all zeros for root spans');
    });

    test('tracer creates root span with zero-filled parent ID', () {
      final tracer = OTel.tracerProvider().getTracer('test');
      final rootSpan = tracer.startSpan('root');

      // Print the span context
      print('Parent span ID: ${rootSpan.spanContext.parentSpanId}');
      print('As string: ${rootSpan.spanContext.parentSpanId}');
      print('Is valid: ${rootSpan.spanContext.parentSpanId!.isValid}');

      // Test that parent span ID is properly zero-filled
      expect(rootSpan.spanContext.parentSpanId, isNotNull, reason: 'Parent span ID should not be null');
      expect(rootSpan.spanContext.parentSpanId.toString(), equals('0000000000000000'),
             reason: 'Parent span ID should be all zeros for root spans');
      expect(rootSpan.spanContext.parentSpanId!.isValid, isFalse,
             reason: 'Root span parent ID should be invalid');

      rootSpan.end();
    });
  });
}
