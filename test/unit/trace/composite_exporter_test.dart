// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Tests for CompositeExporter to verify it correctly delegates
// export, forceFlush, and shutdown to all contained exporters.
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

void main() {
  group('CompositeExporter', () {
    late InMemorySpanExporter exporter1;
    late InMemorySpanExporter exporter2;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'composite-exporter-test',
        detectPlatformResources: false,
      );
      exporter1 = InMemorySpanExporter();
      exporter2 = InMemorySpanExporter();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('export delegates to all exporters', () async {
      final composite = CompositeExporter([exporter1, exporter2]);
      final tracer = OTel.tracer();
      final span = tracer.startSpan('delegate-test');
      span.end();

      await composite.export([span]);

      expect(exporter1.spans, hasLength(1));
      expect(exporter1.spans.first.name, equals('delegate-test'));
      expect(exporter2.spans, hasLength(1));
      expect(exporter2.spans.first.name, equals('delegate-test'));
    });

    test('export with empty exporters list completes without error', () async {
      final composite = CompositeExporter([]);
      final tracer = OTel.tracer();
      final span = tracer.startSpan('empty-list-test');
      span.end();

      await expectLater(
        composite.export([span]),
        completes,
      );
    });

    test('forceFlush delegates to all exporters', () async {
      final composite = CompositeExporter([exporter1, exporter2]);

      // forceFlush should complete without error on both exporters
      await expectLater(
        composite.forceFlush(),
        completes,
      );
    });

    test('shutdown delegates to all exporters', () async {
      final composite = CompositeExporter([exporter1, exporter2]);

      await composite.shutdown();

      // After shutdown, exporters should reject new exports
      await expectLater(
        () => exporter1.export([]),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        () => exporter2.export([]),
        throwsA(isA<StateError>()),
      );
    });

    test('export sends the same spans to each exporter', () async {
      final composite = CompositeExporter([exporter1, exporter2]);
      final tracer = OTel.tracer();

      final span1 = tracer.startSpan('span-a');
      span1.end();
      final span2 = tracer.startSpan('span-b');
      span2.end();

      final spans = [span1, span2];
      await composite.export(spans);

      // Both exporters should have the exact same spans
      expect(exporter1.spans, hasLength(2));
      expect(exporter2.spans, hasLength(2));
      expect(exporter1.spanNames, equals(['span-a', 'span-b']));
      expect(exporter2.spanNames, equals(['span-a', 'span-b']));
    });

    test('three exporters all receive spans', () async {
      final exporter3 = InMemorySpanExporter();
      final composite = CompositeExporter([exporter1, exporter2, exporter3]);
      final tracer = OTel.tracer();

      final span = tracer.startSpan('three-exporter-test');
      span.end();

      await composite.export([span]);

      expect(exporter1.spans, hasLength(1));
      expect(exporter1.spans.first.name, equals('three-exporter-test'));
      expect(exporter2.spans, hasLength(1));
      expect(exporter2.spans.first.name, equals('three-exporter-test'));
      expect(exporter3.spans, hasLength(1));
      expect(exporter3.spans.first.name, equals('three-exporter-test'));
    });

    test('export with empty span list delegates to all exporters', () async {
      final composite = CompositeExporter([exporter1, exporter2]);

      await composite.export([]);

      expect(exporter1.spans, isEmpty);
      expect(exporter2.spans, isEmpty);
    });
  });
}
