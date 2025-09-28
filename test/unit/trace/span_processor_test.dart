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

  void clear() {
    exportedSpans.clear();
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
      await OTel.shutdown();
    });

    test('exports span on end even when isRecording is false', () async {
      // Clear any existing spans
      exporter.clear();

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
      expect(span.isRecording, isTrue,
          reason: 'Span should be recording before end()');

      // End the span
      span.end();

      // Verify that isRecording is false after ending
      expect(span.isRecording, isFalse,
          reason: 'Span should NOT be recording after end()');

      // Wait a bit for async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Check that the span was exported despite isRecording being false
      expect(exporter.exportedSpans, hasLength(1));
      expect(exporter.exportedSpans.first.name, equals('test-span-recording'));

      await processor.shutdown();
    });

    test('handles exporter errors gracefully', () async {
      // Clear any existing spans
      exporter.clear();

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

      await processor.shutdown();
    });

    test('stops exporting after shutdown', () async {
      // Clear any existing spans
      exporter.clear();

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
      await OTel.reset();
      await OTel.initialize();
      exporter = MockSpanExporter();
      tracerProvider = OTel.tracerProvider();
      tracer = tracerProvider.getTracer('test-tracer');
    });

    tearDown(() async {
      await OTel.shutdown();
      await tracerProvider.shutdown();
      await OTel.reset();
    });

    test('batches spans for export', () async {
      // Clear any existing spans
      exporter.clear();

      // Create the batch processor
      final processor = BatchSpanProcessor(exporter);

      // Register the processor with the tracer provider
      tracerProvider.addSpanProcessor(processor);

      // Create multiple spans that should be batched
      for (var i = 0; i < 3; i++) {
        final span = tracer.startSpan('test-span-$i');
        span.end();
      }

      // Force flush to ensure spans are exported
      await processor.forceFlush();

      // Verify spans were exported
      expect(exporter.exportedSpans, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(
          exporter.exportedSpans[i].name,
          equals('test-span-$i'),
        );
      }

      await processor.shutdown();
    });

    test('handles export timeout', () async {
      // Clear any existing spans
      exporter.clear();

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

      await processor.shutdown();
    });

    test('handles shutdown correctly', () async {
      // Clear any existing spans
      exporter.clear();

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

    test('batch processor respects batch size limits', () async {
      // Clear any existing spans
      exporter.clear();

      // Create batch processor with small batch size for testing
      final processor = BatchSpanProcessor(
          exporter,
          const BatchSpanProcessorConfig(
              maxExportBatchSize: 2,
              exportTimeout: Duration(milliseconds: 1000),
              scheduleDelay: Duration(
                milliseconds: 100,
              )));

      // Register the processor with the tracer provider
      tracerProvider.addSpanProcessor(processor);

      // Create 5 spans - should trigger multiple batches
      for (var i = 0; i < 5; i++) {
        final span = tracer.startSpan('batch-test-span-$i');
        span.end();
      }

      // Wait for batching to occur
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Force flush to ensure any remaining spans are exported
      await processor.forceFlush();

      // Verify all spans were exported
      expect(exporter.exportedSpans, hasLength(5));

      // Verify span names
      for (var i = 0; i < 5; i++) {
        expect(
          exporter.exportedSpans
              .any((span) => span.name == 'batch-test-span-$i'),
          isTrue,
          reason: 'Should find span with name batch-test-span-$i',
        );
      }

      await processor.shutdown();
    });

    test('batch processor handles single span export', () async {
      // Clear any existing spans
      exporter.clear();

      // Create the batch processor
      final processor = BatchSpanProcessor(exporter);

      // Register the processor with the tracer provider
      tracerProvider.addSpanProcessor(processor);

      // Create and end a single span
      final span = tracer.startSpan('single-span-test');
      span.end();

      // Force flush to ensure span is exported
      await processor.forceFlush();

      // Verify span was exported
      expect(exporter.exportedSpans, hasLength(1));
      expect(exporter.exportedSpans.first.name, equals('single-span-test'));

      await processor.shutdown();
    });
  });
}
