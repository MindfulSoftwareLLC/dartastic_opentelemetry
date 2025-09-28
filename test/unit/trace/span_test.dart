// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Span', () {
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
      final span = tracer.startSpan('test-span');

      expect(span.name, equals('test-span'));
      expect(span.kind, equals(SpanKind.internal));
      expect(span.spanContext.isValid, isTrue);
      expect(span.spanContext.spanId, isNotNull);
      expect(span.spanContext.traceId, isNotNull);
      expect(span.isEnded, isFalse);
      expect(span.status, equals(SpanStatusCode.Unset));

      span.end();
    });

    test('parentSpanContext returns null for root spans', () {
      final rootSpan = tracer.startSpan('root-span');

      expect(rootSpan.parentSpanContext, isNull);

      rootSpan.end();
    });

    test('parentSpanContext returns parent span context for child spans', () {
      final parentSpan = tracer.startSpan('parent-span');

      // Create a child span by using the parent span
      final childSpan = tracer.startSpan(
        'child-span',
        parentSpan: parentSpan,
      );

      // Verify the parent span context
      expect(childSpan.parentSpanContext, isNotNull);
      expect(childSpan.parentSpanContext, equals(parentSpan.spanContext));

      // Verify trace ID is inherited from parent
      expect(childSpan.spanContext.traceId,
          equals(parentSpan.spanContext.traceId));

      childSpan.end();
      parentSpan.end();
    });

    test('sets and gets status with description', () {
      final span = tracer.startSpan('status-span');

      // Set a status with description
      span.setStatus(SpanStatusCode.Error, 'Something went wrong');

      // Verify the status was set
      expect(span.status, equals(SpanStatusCode.Error));
      expect(span.statusDescription, equals('Something went wrong'));

      span.end();
    });

    test('adds and retrieves attributes', () {
      final span = tracer.startSpan('attribute-span');

      // Set attributes
      span.setStringAttribute<String>('string-key', 'string-value');
      span.setIntAttribute('int-key', 42);
      span.setBoolAttribute('bool-key', true);
      span.setDoubleAttribute('double-key', 3.14);

      // Verify attributes
      final attrs = span.attributes;
      expect(attrs.getString('string-key'), equals('string-value'));
      expect(attrs.getInt('int-key'), equals(42));
      expect(attrs.getBool('bool-key'), equals(true));
      expect(attrs.getDouble('double-key'), equals(3.14));

      span.end();
    });

    test('adds events', () {
      final span = tracer.startSpan('event-span');

      // Add events
      span.addEventNow('event1');
      span.addEventNow('event2', {'key': 'value'}.toAttributes());

      // Verify events
      final events = span.spanEvents;
      expect(events, isNotNull);
      expect(events!.length, equals(2));
      expect(events[0].name, equals('event1'));
      expect(events[1].name, equals('event2'));
      expect(events[1].attributes!.getString('key'), equals('value'));

      span.end();
    });

    test('adds links', () {
      // Create a span context to link to
      final linkContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
      );

      final span = tracer.startSpan('link-span');

      // Add a link
      span.addLink(linkContext, {'key': 'value'}.toAttributes());

      // Verify links
      final links = span.spanLinks;
      expect(links, isNotNull);
      expect(links!.length, equals(1));
      expect(links[0].spanContext, equals(linkContext));
      expect(links[0].attributes.getString('key'), equals('value'));

      span.end();
    });

    test('records exceptions', () {
      final span = tracer.startSpan('exception-span');

      try {
        throw Exception('Test exception');
      } catch (e, stackTrace) {
        span.recordException(e, stackTrace: stackTrace);
      }

      // Verify exception was recorded as an event
      final events = span.spanEvents;
      expect(events, isNotNull);
      expect(events!.length, equals(1));
      expect(events[0].name, equals('exception'));
      expect(events[0].attributes!.getString('exception.type'),
          contains('Exception'));
      expect(events[0].attributes!.getString('exception.message'),
          contains('Test exception'));

      span.end();
    });

    test('gets instrumentation scope', () {
      final span = tracer.startSpan('scope-span');

      // Verify the instrumentation scope
      final scope = span.instrumentationScope;
      expect(scope, isNotNull);
      expect(scope.name, equals('test-tracer'));

      span.end();
    });
  });
}
