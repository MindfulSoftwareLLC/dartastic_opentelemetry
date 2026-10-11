// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Parent Context Handling', () {
    late TracerProvider tracerProvider;
    late Tracer tracer;

    setUp(() async {
      await OTel.initialize(
        endpoint: 'http://localhost:4317',
        serviceName: 'test-service',
      );
      tracerProvider = OTel.tracerProvider();
      tracer = tracerProvider.getTracer('test-tracer');
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('uses current context when no context provided', () {
      final parentSpan = tracer.startSpan('parent');
      final parentContext = Context.current.withSpan(parentSpan);

      // Activate the parent context for a synchronous scope. runSync attaches
      // it via Zone, so any tracer.startSpan inside picks it up via
      // Context.current without mutating the static field.
      parentContext.runSync(() {
        final span = tracer.startSpan('child');

        expect(
            span.spanContext.traceId, equals(parentSpan.spanContext.traceId));
        expect(
          span.spanContext.parentSpanId,
          equals(parentSpan.spanContext.spanId),
        );
      });
    });

    test('uses provided context over current context', () {
      final parentSpan1 = tracer.startSpan('parent1');
      final parentContext1 = Context.current.withSpan(parentSpan1);

      final parentSpan2 = tracer.startSpan('parent2');
      final parentContext2 = Context.current.withSpan(parentSpan2);

      // Activate parentContext1 for the scope; pass parentContext2 explicitly.
      parentContext1.runSync(() {
        final span = tracer.startSpan('child', context: parentContext2);

        expect(
            span.spanContext.traceId, equals(parentSpan2.spanContext.traceId));
        expect(
          span.spanContext.parentSpanId,
          equals(parentSpan2.spanContext.spanId),
        );
      });
    });

    test('a bare SpanContext on the context parents the span', () {
      // A valid non-remote SpanContext with no span object behind it (set
      // via Context.withSpanContext) still identifies a parent: the child
      // joins its trace with a new span ID and parentSpanId pointing at it.
      final explicitSpanContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
      );
      final parentContext = Context.root.withSpanContext(explicitSpanContext);

      final span = tracer.startSpan('child', context: parentContext);

      // Verify:
      // 1. Trace ID matches the span context's
      expect(
        span.spanContext.traceId,
        equals(explicitSpanContext.traceId),
        reason: 'Child should use the span context\'s trace ID',
      );

      // 2. Span ID is new (not the same as explicitSpanContext)
      expect(
        span.spanContext.spanId,
        isNot(equals(explicitSpanContext.spanId)),
        reason: 'Child should get new span ID',
      );

      // 3. Parent span ID properly set; there is no parent span object
      expect(
        span.spanContext.parentSpanId,
        equals(explicitSpanContext.spanId),
        reason: 'Child should reference the span context\'s span ID',
      );
      expect(span.parentSpan, isNull);

      // 4. All IDs are valid
      expect(
        span.spanContext.isValid,
        isTrue,
        reason: 'Child context should be valid',
      );
    });

    test('explicit spanContext from another trace replaces the parent\'s', () {
      // Create parent span and context
      final parentSpan = tracer.startSpan('parent');
      final parentContext = Context.current.withSpan(parentSpan);

      // Create explicit span context
      final explicitSpanContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
      );

      // Per the Context specification a set-value operation always returns a
      // derived Context, and per the Propagators API `extract` must never
      // throw: receiving a valid span context for another trace while a local
      // span is active is an ordinary situation during extraction, not an
      // error. This asserted throwsArgumentError until the API stopped
      // rejecting it.
      final derived = parentContext.withSpanContext(explicitSpanContext);

      expect(derived.spanContext, same(explicitSpanContext));
      expect(
        derived.span,
        same(parentSpan),
        reason: 'withSpanContext replaces the span context, not the span',
      );
    });

    test('properly inherits parent trace ID in various scenarios', () {
      // Create root span
      final rootSpan = tracer.startSpan('root');
      final rootContext = Context.current.withSpan(rootSpan);

      // 1. Create child with parent context
      final childViaContext = tracer.startSpan('child1', context: rootContext);
      expect(
        childViaContext.spanContext.traceId,
        equals(rootSpan.spanContext.traceId),
        reason: 'Child via context should inherit parent trace ID',
      );

      // 2. Create child with explicit parent span
      final childViaParentSpan = tracer.startSpan(
        'child2',
        context: Context.current.withSpan(rootSpan),
      );
      expect(
        childViaParentSpan.spanContext.traceId,
        equals(rootSpan.spanContext.traceId),
        reason: 'Child via parent span should inherit parent trace ID',
      );

      // 3. Create child with a bare span context of the root's span
      final childViaSpanContext = tracer.startSpan(
        'child3',
        context: Context.root.withSpanContext(rootSpan.spanContext),
      );
      expect(
        childViaSpanContext.spanContext.traceId,
        equals(rootSpan.spanContext.traceId),
        reason: 'Child via span context should maintain trace ID',
      );
    });

    test('a remote SpanContext on the context wins over a local span', () {
      // The propagator extract path: a Context already carrying a local
      // span receives a remote SpanContext from an incoming header. The
      // remote context takes precedence (APITracer.startSpan precedence).
      final localParent = tracer.startSpan('local-parent');
      final remoteSpanContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
        isRemote: true,
      );
      final parentContext = Context.current
          .withSpan(localParent)
          .withSpanContext(remoteSpanContext);

      final span = tracer.startSpan('child', context: parentContext);

      expect(span.spanContext.traceId, equals(remoteSpanContext.traceId));
      expect(span.spanContext.parentSpanId, equals(remoteSpanContext.spanId));
      expect(
        span.parentSpan,
        isNull,
        reason: 'the local span is not the span the remote context identifies',
      );
    });

    test('root: true creates a new trace even with a parent in context', () {
      final contextParentSpan = tracer.startSpan('context-parent');
      final parentContext = Context.current.withSpan(contextParentSpan);

      final span = tracer.startSpan(
        'child',
        context: parentContext,
        root: true,
      );

      expect(
        span.spanContext.traceId,
        isNot(equals(contextParentSpan.spanContext.traceId)),
      );
      expect(span.spanContext.parentSpanId?.isValid ?? false, isFalse);
      expect(span.parentSpan, isNull);
    });

    test('creates root span when no parent context available', () {
      final span = tracer.startSpan('root');

      // Verify the parent span ID is zero-filled (invalid)
      expect(span.spanContext.parentSpanId, isNotNull);
      expect(
        span.spanContext.parentSpanId.toString(),
        equals('0000000000000000'),
      );
      expect(span.spanContext.traceId.isValid, isTrue);
      expect(span.spanContext.spanId.isValid, isTrue);
    });
  });
}
