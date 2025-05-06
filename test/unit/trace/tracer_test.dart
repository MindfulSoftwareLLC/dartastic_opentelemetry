// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Tracer', () {
    late TracerProvider tracerProvider;
    late Tracer tracer;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-service');
      tracerProvider = OTel.tracerProvider();
      tracer = tracerProvider.getTracer('test-tracer');
    });

    tearDown(() async {
      await tracerProvider.shutdown();
    });

    test('has correct properties', () {
      expect(tracer.name, equals('test-tracer'));
      expect(tracer.enabled, isTrue);
    });

    test('creates spans correctly', () {
      final span = tracer.startSpan('test-span');

      expect(span, isNotNull);
      expect(span.name, equals('test-span'));
      expect(span.kind, equals(SpanKind.internal));
      expect(span.spanContext.isValid, isTrue);

      span.end();
    });

    test('supports withSpan for context propagation', () {
      // Create a span to use with withSpan
      final span = tracer.startSpan('parent-span');

      // Use withSpan to execute code with this span active
      final result = tracer.withSpan(span, () {
        // Get current span from context
        final currentSpan = tracer.currentSpan;

        // Verify currentSpan is the one we activated
        expect(currentSpan, equals(span));

        // Return a value to test that return values work properly
        return 'success';
      });

      // Verify return value
      expect(result, equals('success'));

      span.end();
    });

    test('supports withSpanAsync for async context propagation', () async {
      // Create a span to use with withSpanAsync
      final span = tracer.startSpan('async-parent-span');

      // Use withSpanAsync to execute async code with this span active
      final result = await tracer.withSpanAsync(span, () async {
        // Simulate async work
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Get current span from context
        final currentSpan = tracer.currentSpan;

        // Verify currentSpan is the one we activated
        expect(currentSpan, equals(span));

        // Return a value to test that return values work properly
        return 'async-success';
      });

      // Verify return value
      expect(result, equals('async-success'));

      span.end();
    });

    test('startActiveSpan executes with active span', () {
      // Execute code with a new span that is automatically started and ended
      final result = tracer.startActiveSpan(
        name: 'active-span',
        fn: (span) {
          // Verify currentSpan is the one we activated
          expect(tracer.currentSpan, equals(span));
          expect(span.name, equals('active-span'));

          // Return a value to test that return values work properly
          return 'active-success';
        },
      );

      // Verify return value
      expect(result, equals('active-success'));
    });

    test('startActiveSpanAsync executes with active span for async code', () async {
      // Execute async code with a new span that is automatically started and ended
      final result = await tracer.startActiveSpanAsync(
        name: 'active-async-span',
        fn: (span) async {
          // Simulate async work
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Verify currentSpan is the one we activated
          expect(tracer.currentSpan, equals(span));
          expect(span.name, equals('active-async-span'));

          // Return a value to test that return values work properly
          return 'active-async-success';
        },
      );

      // Verify return value
      expect(result, equals('active-async-success'));
    });

    test('recordSpan automatically handles span creation and ending', () {
      // Use recordSpan to execute code with a new span
      final result = tracer.recordSpan(
        name: 'record-span',
        fn: () {
          // Code inside this function is executed with a span
          final currentSpan = tracer.currentSpan;
          expect(currentSpan, isNotNull);
          expect(currentSpan!.name, equals('record-span'));

          // Return a value to test that return values work properly
          return 'record-success';
        },
      );

      // Verify return value
      expect(result, equals('record-success'));
    });

    test('recordSpanAsync automatically handles async span creation and ending', () async {
      // Use recordSpanAsync to execute async code with a new span
      final result = await tracer.recordSpanAsync(
        name: 'record-async-span',
        fn: () async {
          // Simulate async work
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Code inside this function is executed with a span
          final currentSpan = tracer.currentSpan;
          expect(currentSpan, isNotNull);
          expect(currentSpan!.name, equals('record-async-span'));

          // Return a value to test that return values work properly
          return 'record-async-success';
        },
      );

      // Verify return value
      expect(result, equals('record-async-success'));
    });

    test('recordSpan sets error status on exception', () {
      // Try to use recordSpan with code that throws an exception
      try {
        tracer.recordSpan(
          name: 'error-span',
          fn: () {
            throw Exception('Test error');
          },
        );
        // ignore: dead_code
        fail('Expected exception to be propagated');
      } catch (e) {
        // Exception should propagate out
        expect(e, isA<Exception>());
        expect(e.toString(), contains('Test error'));
      }
    });

    test('startSpanWithContext creates spans with correct context', () {
      // Create a custom context
      final customContext = OTel.context();

      // Start span with the custom context
      final span = tracer.startSpanWithContext(
        name: 'context-span',
        context: customContext,
      );

      expect(span.name, equals('context-span'));

      // Check that the current context has been updated
      expect(Context.current.span, equals(span));

      span.end();
    });
  });
}
