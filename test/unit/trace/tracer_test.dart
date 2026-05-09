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
      await OTel.shutdown();
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

    test(
      'startActiveSpanAsync executes with active span for async code',
      () async {
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
      },
    );

    test('OTel.withSpan activates the span for fn', () {
      final span = tracer.startSpan('with-span-active');
      try {
        OTel.withSpan(span, () {
          final currentSpan = tracer.currentSpan;
          expect(currentSpan, isNotNull);
          expect(currentSpan!.name, equals('with-span-active'));
        });
      } finally {
        span.end();
      }
    });

    test(
      'OTel.withSpanAsync activates the span across awaits',
      () async {
        final span = tracer.startSpan('with-span-async-active');
        try {
          final result = await OTel.withSpanAsync(span, () async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            final currentSpan = tracer.currentSpan;
            expect(currentSpan, isNotNull);
            expect(currentSpan!.name, equals('with-span-async-active'));
            return 'async-success';
          });
          expect(result, equals('async-success'));
        } finally {
          span.end();
        }
      },
    );

    test('OTel.withSpan propagates exceptions out of fn', () {
      final span = tracer.startSpan('error-span');
      try {
        try {
          OTel.withSpan(span, () {
            throw Exception('Test error');
          });
          // ignore: dead_code
          fail('Expected exception to be propagated');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), contains('Test error'));
        }
      } finally {
        span.end();
      }
    });
  });
}
