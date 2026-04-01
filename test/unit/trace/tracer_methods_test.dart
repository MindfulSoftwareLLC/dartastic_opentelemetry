// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

void main() {
  late InMemorySpanExporter exporter;

  setUp(() async {
    await OTel.reset();
    exporter = InMemorySpanExporter();
    final processor = SimpleSpanProcessor(exporter);
    await OTel.initialize(
      serviceName: 'test',
      spanProcessor: processor,
      detectPlatformResources: false,
    );
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  group('withSpan', () {
    test('runs function and returns result', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('test-span');

      final result = tracer.withSpan(span, () => 42);

      expect(result, equals(42));
      span.end();
    });

    test('sets context during execution so Context.current.span is the span',
        () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('context-span');

      APISpan? capturedSpan;
      tracer.withSpan(span, () {
        capturedSpan = Context.current.span;
        return null;
      });

      expect(capturedSpan, isNotNull);
      expect(capturedSpan!.spanContext.spanId, equals(span.spanContext.spanId));
      span.end();
    });

    test('restores context after completion', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('restore-span');
      // Capture context after startSpan (which may modify Context.current)
      final contextBeforeWithSpan = Context.current;

      tracer.withSpan(span, () => null);

      expect(Context.current, equals(contextBeforeWithSpan));
      span.end();
    });

    test('on error: records exception and sets error status, rethrows', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('error-span');

      expect(
        () => tracer.withSpan(span, () {
          throw Exception('withSpan test error');
        }),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('withSpan test error'),
        )),
      );

      // The span should have recorded the exception and error status
      expect(span.status, equals(SpanStatusCode.Error));
      expect(span.statusDescription, contains('withSpan test error'));
      expect(span.spanEvents, isNotNull);
      expect(span.spanEvents!.length, greaterThanOrEqualTo(1));
      expect(
        span.spanEvents!.any((e) => e.name == 'exception'),
        isTrue,
      );
      span.end();
    });

    test('restores context even on error', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('error-restore-span');
      // Capture context after startSpan (which may modify Context.current)
      final contextBeforeWithSpan = Context.current;

      try {
        tracer.withSpan(span, () {
          throw Exception('error for context restore test');
        });
      } catch (_) {
        // expected
      }

      expect(Context.current, equals(contextBeforeWithSpan));
      span.end();
    });
  });

  group('withSpanAsync', () {
    test('runs async function and returns result', () async {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('async-span');

      final result = await tracer.withSpanAsync(span, () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 'async-result';
      });

      expect(result, equals('async-result'));
      span.end();
    });

    test('on error: records exception and sets error status, rethrows',
        () async {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('async-error-span');

      await expectLater(
        () => tracer.withSpanAsync(span, () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          throw Exception('withSpanAsync test error');
        }),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('withSpanAsync test error'),
        )),
      );

      expect(span.status, equals(SpanStatusCode.Error));
      expect(span.statusDescription, contains('withSpanAsync test error'));
      expect(span.spanEvents, isNotNull);
      expect(span.spanEvents!.length, greaterThanOrEqualTo(1));
      expect(
        span.spanEvents!.any((e) => e.name == 'exception'),
        isTrue,
      );
      span.end();
    });
  });

  group('recordSpan', () {
    test('creates span, runs function, and ends span', () async {
      final tracer = OTel.tracer();

      tracer.recordSpan(
        name: 'record-span',
        fn: () => 'done',
      );

      await OTel.tracerProvider().forceFlush();

      expect(exporter.hasSpanWithName('record-span'), isTrue);
      final exportedSpan = exporter.findSpanByName('record-span')!;
      expect(exportedSpan.isEnded, isTrue);
    });

    test('returns function result', () {
      final tracer = OTel.tracer();

      final result = tracer.recordSpan(
        name: 'record-span-result',
        fn: () => 99,
      );

      expect(result, equals(99));
    });

    test('on error: records exception, sets error, ends span, rethrows',
        () async {
      final tracer = OTel.tracer();

      expect(
        () => tracer.recordSpan(
          name: 'record-span-error',
          fn: () {
            throw StateError('recordSpan test error');
          },
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          equals('recordSpan test error'),
        )),
      );

      await OTel.tracerProvider().forceFlush();

      expect(exporter.hasSpanWithName('record-span-error'), isTrue);
      final exportedSpan = exporter.findSpanByName('record-span-error')!;
      expect(exportedSpan.isEnded, isTrue);
      expect(exportedSpan.status, equals(SpanStatusCode.Error));
      expect(exportedSpan.spanEvents, isNotNull);
      expect(
        exportedSpan.spanEvents!.any((e) => e.name == 'exception'),
        isTrue,
      );
    });
  });

  group('recordSpanAsync', () {
    test('creates span, runs async fn, and ends span', () async {
      final tracer = OTel.tracer();

      final result = await tracer.recordSpanAsync(
        name: 'record-async-span',
        fn: () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return 'async-done';
        },
      );

      expect(result, equals('async-done'));

      await OTel.tracerProvider().forceFlush();

      expect(exporter.hasSpanWithName('record-async-span'), isTrue);
      final exportedSpan = exporter.findSpanByName('record-async-span')!;
      expect(exportedSpan.isEnded, isTrue);
    });

    test('on error: records exception, sets error, ends span, rethrows',
        () async {
      final tracer = OTel.tracer();

      await expectLater(
        () => tracer.recordSpanAsync(
          name: 'record-async-error',
          fn: () async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            throw ArgumentError('recordSpanAsync test error');
          },
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          equals('recordSpanAsync test error'),
        )),
      );

      await OTel.tracerProvider().forceFlush();

      expect(exporter.hasSpanWithName('record-async-error'), isTrue);
      final exportedSpan = exporter.findSpanByName('record-async-error')!;
      expect(exportedSpan.isEnded, isTrue);
      expect(exportedSpan.status, equals(SpanStatusCode.Error));
      expect(exportedSpan.spanEvents, isNotNull);
      expect(
        exportedSpan.spanEvents!.any((e) => e.name == 'exception'),
        isTrue,
      );
    });
  });

  group('startActiveSpan', () {
    test('creates span, runs function with span argument, and ends span',
        () async {
      final tracer = OTel.tracer();
      APISpan? receivedSpan;

      tracer.startActiveSpan(
        name: 'active-span',
        fn: (span) {
          receivedSpan = span;
          return null;
        },
      );

      expect(receivedSpan, isNotNull);

      await OTel.tracerProvider().forceFlush();

      expect(exporter.hasSpanWithName('active-span'), isTrue);
      final exportedSpan = exporter.findSpanByName('active-span')!;
      expect(exportedSpan.isEnded, isTrue);
    });

    test('returns result', () {
      final tracer = OTel.tracer();

      final result = tracer.startActiveSpan(
        name: 'active-span-result',
        fn: (span) => 'active-result',
      );

      expect(result, equals('active-result'));
    });

    test('on error: records exception via withSpan, ends span, rethrows',
        () async {
      final tracer = OTel.tracer();

      expect(
        () => tracer.startActiveSpan(
          name: 'active-span-error',
          fn: (span) {
            throw Exception('startActiveSpan test error');
          },
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('startActiveSpan test error'),
        )),
      );

      await OTel.tracerProvider().forceFlush();

      expect(exporter.hasSpanWithName('active-span-error'), isTrue);
      final exportedSpan = exporter.findSpanByName('active-span-error')!;
      expect(exportedSpan.isEnded, isTrue);
      expect(exportedSpan.status, equals(SpanStatusCode.Error));
      expect(exportedSpan.spanEvents, isNotNull);
      expect(
        exportedSpan.spanEvents!.any((e) => e.name == 'exception'),
        isTrue,
      );
    });
  });

  group('startActiveSpanAsync', () {
    test('creates span, runs async fn with span, and ends span', () async {
      final tracer = OTel.tracer();
      APISpan? receivedSpan;

      final result = await tracer.startActiveSpanAsync(
        name: 'active-async-span',
        fn: (span) async {
          receivedSpan = span;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return 'active-async-result';
        },
      );

      expect(result, equals('active-async-result'));
      expect(receivedSpan, isNotNull);

      await OTel.tracerProvider().forceFlush();

      expect(exporter.hasSpanWithName('active-async-span'), isTrue);
      final exportedSpan = exporter.findSpanByName('active-async-span')!;
      expect(exportedSpan.isEnded, isTrue);
    });

    test('on error: handles error properly', () async {
      final tracer = OTel.tracer();

      await expectLater(
        () => tracer.startActiveSpanAsync(
          name: 'active-async-error',
          fn: (span) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            throw Exception('startActiveSpanAsync test error');
          },
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('startActiveSpanAsync test error'),
        )),
      );

      await OTel.tracerProvider().forceFlush();

      expect(exporter.hasSpanWithName('active-async-error'), isTrue);
      final exportedSpan = exporter.findSpanByName('active-async-error')!;
      expect(exportedSpan.isEnded, isTrue);
      expect(exportedSpan.status, equals(SpanStatusCode.Error));
      expect(exportedSpan.spanEvents, isNotNull);
      expect(
        exportedSpan.spanEvents!.any((e) => e.name == 'exception'),
        isTrue,
      );
    });
  });

  group('startSpanWithContext', () {
    test('creates span with given context', () async {
      final tracer = OTel.tracer();
      final parentSpan = tracer.startSpan('parent-span');
      final parentContext = Context.current.withSpan(parentSpan);

      final childSpan = tracer.startSpanWithContext(
        name: 'child-with-context',
        context: parentContext,
      );

      expect(childSpan, isNotNull);
      expect(childSpan.spanContext.traceId,
          equals(parentSpan.spanContext.traceId));

      childSpan.end();
      parentSpan.end();

      await OTel.tracerProvider().forceFlush();

      expect(exporter.hasSpanWithName('child-with-context'), isTrue);
      expect(exporter.hasSpanWithName('parent-span'), isTrue);
    });

    test('span has correct parent from provided context', () async {
      final tracer = OTel.tracer();
      final parentSpan = tracer.startSpan('parent-for-context');
      final parentContext = Context.current.withSpan(parentSpan);

      final childSpan = tracer.startSpanWithContext(
        name: 'context-child',
        context: parentContext,
      );

      // The child should have the parent's span ID as its parent span ID
      expect(childSpan.parentSpanContext, isNotNull);
      expect(childSpan.parentSpanContext!.spanId,
          equals(parentSpan.spanContext.spanId));
      // The child should share the same trace ID
      expect(childSpan.spanContext.traceId,
          equals(parentSpan.spanContext.traceId));
      // The child should have its own unique span ID
      expect(childSpan.spanContext.spanId,
          isNot(equals(parentSpan.spanContext.spanId)));

      childSpan.end();
      parentSpan.end();

      await OTel.tracerProvider().forceFlush();

      final exportedChild = exporter.findSpanByName('context-child')!;
      final exportedParent = exporter.findSpanByName('parent-for-context')!;
      expect(exportedChild.parentSpanContext!.spanId,
          equals(exportedParent.spanContext.spanId));
    });
  });
}
