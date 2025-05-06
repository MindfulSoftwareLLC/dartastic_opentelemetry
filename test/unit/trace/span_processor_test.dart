// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

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



    test('exports span on end even when isRecording is false', () async {
      OTelLog.enableDebugLogging();
      // Create the processor
      final processor = SimpleSpanProcessor(exporter);

      // Register the processor with the tracer provider
      tracerProvider.addSpanProcessor(processor);

      // Create and end a span
      final span = tracer.startSpan(
        'test-span-recording',
        kind: SpanKind.internal,
      );

      // Verify that isRecording is true before ending
      expect(span.isRecording, isTrue, reason: 'Span should be recording before end()');

      // End the span
      span.end();

      // Verify that isRecording is false after ending
      expect(span.isRecording, isFalse, reason: 'Span should NOT be recording after end()');

      // Wait a bit for async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Check that the span was exported despite isRecording being false
      expect(exporter.exportedSpans, hasLength(1));
      expect(exporter.exportedSpans.first.name, equals('test-span-recording'));
    });

    test('handles exporter errors gracefully', () async {
      // Create the processor with error flag set
      final processor = SimpleSpanProcessor(exporter);
      exporter.forceError = true;

      // Register the processor with the tracer provider
      tracerProvider.addSpanProcessor(processor);

      // Create and end a span - this should not throw despite the exporter having an error
      final span = tracer.startSpan(
        'test-span',
        kind: SpanKind.internal,
      );

      // Should not throw
      span.end();

      // Wait a bit for async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    test('stops exporting after shutdown', () async {
      // Create the processor
      final processor = SimpleSpanProcessor(exporter);

      // Register the processor with the tracer provider
      tracerProvider.addSpanProcessor(processor);

      // Shutdown the processor
      await processor.shutdown();

      // Create and end a span after shutdown
      final span = tracer.startSpan(
        'test-span',
        kind: SpanKind.internal,
      );

      span.end();

      // Wait a bit for async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify no spans were exported after shutdown
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
      // Create the batch processor
      final processor = BatchSpanProcessor(exporter);

      // Register the processor with the tracer provider
      tracerProvider.addSpanProcessor(processor);

      // Force flush to ensure spans are exported
      await processor.forceFlush();

      // Verify spans were exported
      expect(exporter.exportedSpans, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(
          (exporter.exportedSpans[i]).name,
          equals('test-span-$i'),
        );
      }
    });

    test('handles export timeout', () async {
      // Create the batch processor with error flag set
      final processor = BatchSpanProcessor(exporter);
      exporter.forceError = true;

      // Register the processor with the tracer provider
      tracerProvider.addSpanProcessor(processor);

      // Create and end a span
      final span = tracer.startSpan(
        'test-span',
        kind: SpanKind.internal,
      );
      span.end();

      // Should not throw
      await processor.forceFlush();
    });

    test('handles shutdown correctly', () async {
      // Create the batch processor
      final processor = BatchSpanProcessor(exporter);

      // Register the processor with the tracer provider
      tracerProvider.addSpanProcessor(processor);

      // Create and end a span
      final span = tracer.startSpan(
        'test-span',
        kind: SpanKind.internal,
      );
      span.end();

      // Wait a bit for async processing
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Shutdown the processor
      await processor.shutdown();

      // Verify exporter was shut down
      expect(exporter._isShutdown, isTrue);
    });
  });
}
