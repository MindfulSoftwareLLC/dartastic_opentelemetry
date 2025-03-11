// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:test/test.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

class MockSpanExporter extends SpanExporter {
  final List<Span> exportedSpans = [];
  bool forceError = false;
  bool _isShutdown = false;

  @override
  Future<void> export(List<Span> spans) async {
    if (forceError) {
      throw Exception('Mock export error');
    }
    if (!_isShutdown) {
      exportedSpans.addAll(spans);
    }
  }

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }

  @override
  Future<void> forceFlush() async {
    if (forceError) {
      throw Exception('Mock flush error');
    }
  }
}

void main() {
  group('SimpleSpanProcessor', () {
    late MockSpanExporter exporter;
    late TracerProvider tracerProvider;
    late Tracer tracer;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize();
      exporter = MockSpanExporter();
      tracerProvider = OTel.tracerProvider();
      tracer = tracerProvider.getTracer('test-tracer');
    });

    tearDown(() async {
      await tracerProvider.shutdown();
      await OTel.reset();
    });

    test('exports span on end', () async {
      final processor = SimpleSpanProcessor(exporter);
      final span = tracer.startSpan(
        'test-span',
        kind:SpanKind.internal,
      );

      await processor.onStart(span, null);
      expect(exporter.exportedSpans, isEmpty);

      span.end();
      await processor.onEnd(span);

      expect(exporter.exportedSpans, hasLength(1));
      expect(exporter.exportedSpans.first, equals(span));
    });

    test('handles exporter errors gracefully', () async {
      final processor = SimpleSpanProcessor(exporter);
      exporter.forceError = true;

      final span = tracer.startSpan(
        'test-span',
        kind:SpanKind.internal,
        parentSpan: null,
      );

      // Should not throw
      span.end();
      await processor.onEnd(span);
    });

    test('stops exporting after shutdown', () async {
      final processor = SimpleSpanProcessor(exporter);
      final span = tracer.startSpan(
        'test-span',
        kind:SpanKind.internal,
        parentSpan: null,
      );

      await processor.shutdown();

      span.end();
      await processor.onEnd(span);

      expect(exporter.exportedSpans, isEmpty);
      expect(exporter._isShutdown, isTrue);
    });
  });

  group('BatchSpanProcessor', () {
    late MockSpanExporter exporter;
    late TracerProvider tracerProvider;
    late Tracer tracer;

    setUp(() async {
      await OTel.initialize();
      exporter = MockSpanExporter();
      tracerProvider = OTel.tracerProvider();
      tracer = tracerProvider.getTracer('test-tracer');
    });

    tearDown(() async {
      await tracerProvider.shutdown();
      await OTel.reset();
    });

    test('batches spans for export', () async {
      final processor = BatchSpanProcessor(exporter);

      final spans = List.generate(3, (index) {
        final span = tracer.startSpan(
          'test-span-$index',
          kind:SpanKind.internal,
          parentSpan: null,
        );
        span.end();
        return span;
      });

      // Add spans to processor
      for (final span in spans) {
        await processor.onEnd(span);
      }

      // Force flush to ensure spans are exported
      await processor.forceFlush();

      expect(exporter.exportedSpans, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(
          (exporter.exportedSpans[i]).name,
          equals('test-span-$i'),
        );
      }
    });

    test('handles export timeout', () async {
      final processor = BatchSpanProcessor(exporter);

      exporter.forceError = true;

      final span = tracer.startSpan(
        'test-span',
        kind:SpanKind.internal,
        parentSpan: null,
      );
      span.end();

      // Should not throw
      await processor.onEnd(span);
      await processor.forceFlush();
    });

    test('handles shutdown correctly', () async {
      final processor = BatchSpanProcessor(exporter);

      final span = tracer.startSpan(
        'test-span',
        kind:SpanKind.internal,
      );
      span.end();

      await processor.onEnd(span);
      await processor.shutdown();

      expect(exporter._isShutdown, isTrue);
    });
  });
}
