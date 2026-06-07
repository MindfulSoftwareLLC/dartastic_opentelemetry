// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

// Top-level sanitizers so their tear-offs are compile-time constants and can
// be used in `const SpanExceptionOptions(...)`.
SanitizedSpanException _sanitizerT(Object e, StackTrace s) =>
    const SanitizedSpanException(type: 'T', message: 'm');
SanitizedSpanException _sanitizerA(Object e, StackTrace s) =>
    const SanitizedSpanException(type: 'A', message: 'a');
SanitizedSpanException _sanitizerB(Object e, StackTrace s) =>
    const SanitizedSpanException(type: 'B', message: 'b');

/// Returns the single recorded `exception` event on [span], or null.
SpanEvent? _exceptionEvent(Span span) {
  final events = span.spanEvents;
  if (events == null) return null;
  for (final e in events) {
    if (e.name == 'exception') return e;
  }
  return null;
}

void main() {
  group('SpanExceptionOptions (unit)', () {
    test('defaults record exception and set status', () {
      const options = SpanExceptionOptions();
      expect(options.recordException, isTrue);
      expect(options.setStatusOnException, isTrue);
      expect(options.exceptionSanitizer, isNull);
      expect(SpanExceptionOptions.defaults.recordException, isTrue);
      expect(SpanExceptionOptions.defaults.setStatusOnException, isTrue);
    });

    test('mergeWith(null) returns the same configuration', () {
      const base = SpanExceptionOptions(recordException: false);
      final merged = base.mergeWith(null);
      expect(merged.recordException, isFalse);
      expect(merged.setStatusOnException, isTrue);
    });

    test(
        'per-call override merges field-by-field, preserving the global '
        'sanitizer', () {
      const global = SpanExceptionOptions(exceptionSanitizer: _sanitizerT);

      // Only flip recordException for this call.
      final merged =
          global.mergeWith(const SpanExceptionOptions(recordException: false));

      expect(merged.recordException, isFalse);
      // Inherited from global.
      expect(merged.setStatusOnException, isTrue);
      expect(merged.exceptionSanitizer, same(_sanitizerT));
    });

    test('override can replace the sanitizer', () {
      const global = SpanExceptionOptions(exceptionSanitizer: _sanitizerA);
      final merged = global.mergeWith(
          const SpanExceptionOptions(exceptionSanitizer: _sanitizerB));
      expect(merged.exceptionSanitizer, same(_sanitizerB));
    });
  });

  group('withSpan exception options (behavioral)', () {
    late InMemorySpanExporter exporter;

    Future<void> init({SpanExceptionOptions? spanExceptionOptions}) async {
      exporter = InMemorySpanExporter();
      await OTel.initialize(
        serviceName: 'test',
        spanProcessor: SimpleSpanProcessor(exporter),
        detectPlatformResources: false,
        spanExceptionOptions:
            spanExceptionOptions ?? const SpanExceptionOptions(),
      );
    }

    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('default: records exception and sets error status, rethrows',
        () async {
      await init();
      final tracer = OTel.tracer();
      final span = tracer.startSpan('default-span');

      expect(
        () => tracer.withSpan(span, () => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );

      expect(span.status, equals(SpanStatusCode.Error));
      expect(span.statusDescription, contains('boom'));
      expect(_exceptionEvent(span), isNotNull);
      span.end();
    });

    test('recordException=false: status set but no exception event', () async {
      await init();
      final tracer = OTel.tracer();
      final span = tracer.startSpan('no-record-span');

      expect(
        () => tracer.withSpan(
          span,
          () => throw StateError('boom'),
          exceptionOptions: const SpanExceptionOptions(recordException: false),
        ),
        throwsA(isA<StateError>()),
      );

      expect(span.status, equals(SpanStatusCode.Error));
      expect(_exceptionEvent(span), isNull);
      span.end();
    });

    test('setStatusOnException=false: event recorded but status left unset',
        () async {
      await init();
      final tracer = OTel.tracer();
      final span = tracer.startSpan('no-status-span');

      expect(
        () => tracer.withSpan(
          span,
          () => throw StateError('boom'),
          exceptionOptions:
              const SpanExceptionOptions(setStatusOnException: false),
        ),
        throwsA(isA<StateError>()),
      );

      expect(span.status, isNot(equals(SpanStatusCode.Error)));
      expect(_exceptionEvent(span), isNotNull);
      span.end();
    });

    test('sanitizer: records only sanitized type/message/stacktrace', () async {
      await init();
      final tracer = OTel.tracer();
      final span = tracer.startSpan('sanitize-span');
      final sanitizedStack = StackTrace.fromString('redacted-stack');

      expect(
        () => tracer.withSpan(
          span,
          () => throw StateError('token=secret123'),
          exceptionOptions: SpanExceptionOptions(
            exceptionSanitizer: (error, stackTrace) => SanitizedSpanException(
              type: 'SanitizedError',
              message: 'token=[REDACTED]',
              stackTrace: sanitizedStack,
              statusDescription: 'sanitized failure',
            ),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final event = _exceptionEvent(span)!;
      expect(event.attributes!.getString('exception.type'),
          equals('SanitizedError'));
      expect(event.attributes!.getString('exception.message'),
          equals('token=[REDACTED]'));
      // The raw secret must never be recorded.
      expect(event.attributes!.getString('exception.message'),
          isNot(contains('secret123')));
      expect(event.attributes!.getString('exception.stacktrace'),
          equals('redacted-stack'));
      expect(span.status, equals(SpanStatusCode.Error));
      expect(span.statusDescription, equals('sanitized failure'));
      span.end();
    });

    test('sanitizer without stackTrace records no stacktrace attribute',
        () async {
      await init();
      final tracer = OTel.tracer();
      final span = tracer.startSpan('sanitize-nostack-span');

      expect(
        () => tracer.withSpan(
          span,
          () => throw StateError('boom'),
          exceptionOptions: SpanExceptionOptions(
            exceptionSanitizer: (error, stackTrace) =>
                const SanitizedSpanException(type: 'E', message: 'm'),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final event = _exceptionEvent(span)!;
      expect(event.attributes!.getString('exception.stacktrace'), isNull);
      span.end();
    });

    test(
        'sanitizer failure: marks span error with generic description, does '
        'not record', () async {
      await init();
      final tracer = OTel.tracer();
      final span = tracer.startSpan('sanitize-fail-span');

      expect(
        () => tracer.withSpan(
          span,
          () => throw StateError('original'),
          exceptionOptions: SpanExceptionOptions(
            exceptionSanitizer: (error, stackTrace) =>
                throw ArgumentError('sanitizer blew up'),
          ),
        ),
        // The ORIGINAL exception is rethrown, not the sanitizer's.
        throwsA(isA<StateError>()),
      );

      expect(span.status, equals(SpanStatusCode.Error));
      expect(span.statusDescription, equals('Exception sanitizer failed'));
      expect(_exceptionEvent(span), isNull);
      span.end();
    });

    test('global config applies without per-call options', () async {
      // Globally disable recording.
      await init(
        spanExceptionOptions:
            const SpanExceptionOptions(recordException: false),
      );
      final tracer = OTel.tracer();
      final span = tracer.startSpan('global-span');

      expect(
        () => tracer.withSpan(span, () => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );

      // Global recordException=false honored.
      expect(_exceptionEvent(span), isNull);
      // setStatusOnException still defaults true.
      expect(span.status, equals(SpanStatusCode.Error));
      span.end();
    });

    test(
        'per-call override merges over global config, keeping the global '
        'sanitizer', () async {
      await init(
        spanExceptionOptions: SpanExceptionOptions(
          exceptionSanitizer: (error, stackTrace) =>
              const SanitizedSpanException(
            type: 'GlobalSanitized',
            message: 'global-redacted',
          ),
        ),
      );
      final tracer = OTel.tracer();
      final span = tracer.startSpan('merge-span');

      // Per-call only flips setStatusOnException; sanitizer inherited.
      expect(
        () => tracer.withSpan(
          span,
          () => throw StateError('boom'),
          exceptionOptions:
              const SpanExceptionOptions(setStatusOnException: false),
        ),
        throwsA(isA<StateError>()),
      );

      final event = _exceptionEvent(span)!;
      expect(event.attributes!.getString('exception.type'),
          equals('GlobalSanitized'));
      // Status left unset because of the per-call override.
      expect(span.status, isNot(equals(SpanStatusCode.Error)));
      span.end();
    });

    test('withSpanAsync honors options', () async {
      await init();
      final tracer = OTel.tracer();
      final span = tracer.startSpan('async-span');

      await expectLater(
        tracer.withSpanAsync(
          span,
          () async => throw StateError('boom'),
          exceptionOptions: const SpanExceptionOptions(recordException: false),
        ),
        throwsA(isA<StateError>()),
      );

      expect(span.status, equals(SpanStatusCode.Error));
      expect(_exceptionEvent(span), isNull);
      span.end();
    });

    test('OTel.withSpan forwards options', () async {
      await init();
      final span = OTel.tracer().startSpan('otel-span');

      expect(
        () => OTel.withSpan(
          span,
          () => throw StateError('boom'),
          exceptionOptions: const SpanExceptionOptions(recordException: false),
        ),
        throwsA(isA<StateError>()),
      );

      expect(_exceptionEvent(span), isNull);
      span.end();
    });

    test('startActiveSpan forwards options and ends the span', () async {
      await init();
      final tracer = OTel.tracer();

      expect(
        () => tracer.startActiveSpan<void>(
          name: 'active-span',
          fn: (span) => throw StateError('boom'),
          exceptionOptions: const SpanExceptionOptions(recordException: false),
        ),
        throwsA(isA<StateError>()),
      );

      await tracer.provider.forceFlush();
      final exported = exporter.findSpanByName('active-span')!;
      expect(exported.status, equals(SpanStatusCode.Error));
      expect(
        exported.spanEvents?.any((e) => e.name == 'exception') ?? false,
        isFalse,
      );
    });
  });
}
