// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Edge case tests for ConsoleExporter to improve coverage of
// lib/src/trace/export/console_exporter.dart.
//
// Covers: events with attributes, links with attributes, status description,
// not-ended spans, root spans, child spans, forceFlush, and shutdown.
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleExporter edge cases', () {
    late ConsoleExporter exporter;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'console-exporter-edge-test',
        detectPlatformResources: false,
      );
      exporter = ConsoleExporter();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('exports span with events and event attributes without error',
        () async {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('span-with-events', kind: SpanKind.client);

      // Add event with attributes
      span.addEventNow(
        'my-event',
        OTel.attributes([
          OTel.attributeString('event.key', 'event-value'),
          OTel.attributeInt('event.count', 42),
        ]),
      );

      // Add a second event with different attributes
      span.addEventNow(
        'second-event',
        OTel.attributes([
          OTel.attributeString('phase', 'completed'),
        ]),
      );

      span.end();

      // Export should not throw - this exercises the events + event attributes
      // code path in _printSpan
      await expectLater(
        exporter.export([span]),
        completes,
      );
    });

    test('exports span with links and link attributes without error', () async {
      final tracer = OTel.tracer();

      // Create a linked span context
      final linkedContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
      );
      final link = OTel.spanLink(
        linkedContext,
        attributes: OTel.attributes([
          OTel.attributeString('link.reason', 'related-trace'),
          OTel.attributeInt('link.priority', 1),
        ]),
      );

      final span = tracer.startSpan(
        'span-with-links',
        kind: SpanKind.server,
        links: [link],
      );
      span.end();

      // Export should not throw - this exercises the links + link attributes
      // code path in _printSpan
      await expectLater(
        exporter.export([span]),
        completes,
      );
    });

    test('exports span with status description without error', () async {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('span-with-status-desc');
      span.setStatus(SpanStatusCode.Error, 'Something went wrong');
      span.end();

      // Export should not throw - this exercises the statusDescription
      // code path in _printSpan
      await expectLater(
        exporter.export([span]),
        completes,
      );
    });

    test('exports span with no end time (not ended) without error', () async {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('span-not-ended');

      // Do NOT call span.end() - this exercises the "not ended" code path
      await expectLater(
        exporter.export([span]),
        completes,
      );

      // End it now to clean up
      span.end();
    });

    test('exports root span (no parent) without error', () async {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('root-span', kind: SpanKind.server);
      span.end();

      // Root span has no valid parent span ID - exercises the "(root span)"
      // code path in _printSpan
      await expectLater(
        exporter.export([span]),
        completes,
      );
    });

    test('exports child span (with parent) without error', () async {
      final tracer = OTel.tracer();
      final parentSpan = tracer.startSpan('parent-span');
      final childSpan = tracer.startSpan(
        'child-span',
        parentSpan: parentSpan,
      );
      childSpan.end();
      parentSpan.end();

      // Child span has a valid parent span ID - exercises the parent span ID
      // code path in _printSpan
      await expectLater(
        exporter.export([childSpan]),
        completes,
      );
    });

    test('exports span with attributes without error', () async {
      final tracer = OTel.tracer();
      final span = tracer.startSpan(
        'span-with-attrs',
        attributes: OTel.attributesFromMap({
          'http.method': 'GET',
          'http.status_code': 200,
          'test.flag': true,
        }),
      );
      span.end();

      await expectLater(
        exporter.export([span]),
        completes,
      );
    });

    test('exports multiple spans without error', () async {
      final tracer = OTel.tracer();
      final spans = <Span>[];
      for (var i = 0; i < 3; i++) {
        final span = tracer.startSpan('multi-span-$i');
        span.end();
        spans.add(span);
      }

      await expectLater(
        exporter.export(spans),
        completes,
      );
    });

    test('exports span with events, links, attributes, and status description',
        () async {
      final tracer = OTel.tracer();

      final linkedContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
      );
      final link = OTel.spanLink(
        linkedContext,
        attributes: OTel.attributes([
          OTel.attributeString('link-key', 'link-val'),
        ]),
      );

      final span = tracer.startSpan(
        'fully-loaded-span',
        kind: SpanKind.client,
        attributes: OTel.attributesFromMap({
          'service.name': 'edge-test',
        }),
        links: [link],
      );

      span.addEventNow(
        'processing',
        OTel.attributes([
          OTel.attributeString('step', 'validation'),
        ]),
      );

      span.setStatus(SpanStatusCode.Error, 'Validation failed');
      span.end();

      // This exercises all code paths in _printSpan simultaneously
      await expectLater(
        exporter.export([span]),
        completes,
      );
    });

    test('forceFlush completes without throwing', () async {
      await expectLater(
        exporter.forceFlush(),
        completes,
      );
    });

    test('shutdown completes without throwing', () async {
      await expectLater(
        exporter.shutdown(),
        completes,
      );
    });
  });
}
