// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.
//
// Self-test for `package:dartastic_opentelemetry/testing.dart`.
//
// The point of this file is to make sure the in-memory exporters and
// `maybeInitializeOtelForTest` stay regression-safe — wrappers across
// the OTel-Dart ecosystem rely on this harness shape, so a change
// here has to be deliberate.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'testing-lib-self-test',
    );
  });

  setUp(() => harness.clear());

  group('InMemorySpanExporter', () {
    test('records exported spans and offers query helpers', () {
      final tracer = OTel.tracer();
      tracer.startSpan('a').end();
      tracer.startSpan('b').end();
      tracer.startSpan('a').end();
      tracer.startSpan('http /users').end();

      expect(harness.spans.spans, hasLength(4));
      expect(harness.spans.spanNames, ['a', 'b', 'a', 'http /users']);

      expect(harness.spans.findSpanByName('a'), isNotNull);
      expect(harness.spans.findSpanByName('zzz'), isNull);

      expect(harness.spans.findSpansByName('a'), hasLength(2));
      expect(
        harness.spans.findSpansStartingWith('http ').single.name,
        'http /users',
      );
    });

    test('clear() empties the buffer between tests', () {
      OTel.tracer().startSpan('only-in-this-test').end();
      expect(harness.spans.spans, hasLength(1));
      harness.clear();
      expect(harness.spans.spans, isEmpty);
    });

    test('most-recent-wins on findSpanByName when names repeat', () {
      // Same name three times; `findSpanByName` should return the
      // last one so a test setUp + arrange/act flow stays stable.
      final tracer = OTel.tracer();
      final first = tracer.startSpan('dup')
        ..addAttributes(
          OTel.attributes([OTel.attributeString('which', 'first')]),
        )
        ..end();
      tracer.startSpan('dup').end();
      final last = tracer.startSpan('dup')
        ..addAttributes(
          OTel.attributes([OTel.attributeString('which', 'last')]),
        )
        ..end();

      final found = harness.spans.findSpanByName('dup');
      expect(found, isNotNull);
      final attrs = {
        for (final a in found!.attributes.toList()) a.key: a.value,
      };
      expect(attrs['which'], 'last');
      // The other expected spans exist as well:
      expect(harness.spans.findSpansByName('dup'), hasLength(3));
      // (silence the unused warning)
      expect(first.name, last.name);
    });
  });

  group('InMemoryLogExporter', () {
    test('captures emitted log records and filters by severity', () async {
      final logger = OTel.loggerProvider().getLogger('self-test');
      logger.emit(
        body: 'hello-info',
        severityNumber: Severity.INFO,
        severityText: 'INFO',
      );
      logger.emit(
        body: 'hello-warn',
        severityNumber: Severity.WARN,
        severityText: 'WARN',
      );
      await harness.flushLogs();

      expect(harness.logs.records, hasLength(2));
      expect(
        harness.logs.findRecordsBySeverity(Severity.WARN).single.body,
        'hello-warn',
      );
    });
  });

  group('InMemoryMetricExporter + OnDemandMetricReader', () {
    test('tests drive collection explicitly', () async {
      final counter = OTel.meterProvider()
          .getMeter(name: 'self-test')
          .createCounter<int>(name: 'pings');
      counter.add(3);
      counter.add(2);

      // Nothing exported yet — no timer has fired.
      expect(harness.metrics.metrics, isEmpty);

      await harness.collectMetrics();
      final metric = harness.metrics.findMetricByName('pings');
      expect(metric, isNotNull);
    });
  });

  group('maybeInitializeOtelForTest', () {
    test('returns the same harness on repeat calls in the same process',
        () async {
      final again = await maybeInitializeOtelForTest();
      expect(identical(again, harness), isTrue);
    });
  });
}
