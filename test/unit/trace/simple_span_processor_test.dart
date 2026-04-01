// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

/// A span exporter that always throws on export, used to test error handling.
class _FailingSpanExporter implements SpanExporter {
  @override
  Future<void> export(List<Span> spans) async {
    throw Exception('Export failed');
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

/// A span exporter that tracks whether forceFlush was called.
class _TrackingSpanExporter implements SpanExporter {
  final List<Span> exportedSpans = [];
  bool forceFlushCalled = false;
  bool shutdownCalled = false;

  @override
  Future<void> export(List<Span> spans) async {
    exportedSpans.addAll(spans);
  }

  @override
  Future<void> forceFlush() async {
    forceFlushCalled = true;
  }

  @override
  Future<void> shutdown() async {
    shutdownCalled = true;
  }
}

void main() {
  group('SimpleSpanProcessor', () {
    late InMemorySpanExporter exporter;
    late SimpleSpanProcessor processor;

    setUp(() async {
      await OTel.reset();
      exporter = InMemorySpanExporter();
      processor = SimpleSpanProcessor(exporter);
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

    test('onEnd exports span to exporter', () async {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('test-span');
      span.end();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exporter.spans, hasLength(1));
    });

    test('onEnd exports span with correct name', () async {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('my-named-span');
      span.end();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exporter.spans, hasLength(1));
      expect(exporter.spans.first.name, equals('my-named-span'));
    });

    test('multiple spans are all exported', () async {
      final tracer = OTel.tracer();

      final span1 = tracer.startSpan('span-one');
      span1.end();

      final span2 = tracer.startSpan('span-two');
      span2.end();

      final span3 = tracer.startSpan('span-three');
      span3.end();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exporter.spans, hasLength(3));
      expect(exporter.hasSpanWithName('span-one'), isTrue);
      expect(exporter.hasSpanWithName('span-two'), isTrue);
      expect(exporter.hasSpanWithName('span-three'), isTrue);
    });

    test('onEnd after shutdown does not export', () async {
      final tracer = OTel.tracer();

      // Create and end a span before shutdown
      final span1 = tracer.startSpan('before-shutdown');
      span1.end();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify first span was exported
      expect(exporter.hasSpanWithName('before-shutdown'), isTrue);
      final countBeforeShutdown = exporter.spans.length;

      // Shutdown the processor
      await processor.shutdown();

      // Create and end a span after shutdown
      final span2 = tracer.startSpan('after-shutdown');
      span2.end();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Only the first span should be exported
      expect(exporter.spans.length, equals(countBeforeShutdown));
      expect(exporter.hasSpanWithName('after-shutdown'), isFalse);
    });

    test('shutdown can be called multiple times without error', () async {
      await processor.shutdown();
      await processor.shutdown();
      await processor.shutdown();
      // No exception means pass
    });

    test('forceFlush after shutdown returns without error', () async {
      await processor.shutdown();
      await processor.forceFlush();
      // No exception means pass
    });

    test('forceFlush delegates to exporter', () async {
      // Use the tracking exporter to verify forceFlush delegation
      await OTel.reset();
      final trackingExporter = _TrackingSpanExporter();
      final trackingProcessor = SimpleSpanProcessor(trackingExporter);
      await OTel.initialize(
        serviceName: 'test',
        spanProcessor: trackingProcessor,
        detectPlatformResources: false,
      );

      expect(trackingExporter.forceFlushCalled, isFalse);
      await trackingProcessor.forceFlush();
      expect(trackingExporter.forceFlushCalled, isTrue);
    });

    test('onStart is called via span creation', () async {
      // onStart is called internally when a span is created via the tracer.
      // Verifying that span creation completes without error confirms onStart ran.
      final tracer = OTel.tracer();
      final span = tracer.startSpan('start-test-span');

      // The span should exist and be recording
      expect(span.isRecording, isTrue);
      expect(span.name, equals('start-test-span'));

      span.end();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Confirm the span was fully processed through the pipeline
      expect(exporter.hasSpanWithName('start-test-span'), isTrue);
    });

    test('onNameUpdate does not throw', () async {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('original-name');

      // Directly call onNameUpdate on the processor -- should not throw
      await processor.onNameUpdate(span, 'updated-name');

      span.end();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('error in exporter is handled gracefully', () async {
      // Set up a processor with a failing exporter
      await OTel.reset();
      final failingExporter = _FailingSpanExporter();
      final failingProcessor = SimpleSpanProcessor(failingExporter);
      await OTel.initialize(
        serviceName: 'test',
        spanProcessor: failingProcessor,
        detectPlatformResources: false,
      );

      final tracer = OTel.tracer();
      final span = tracer.startSpan('failing-span');

      // This should not throw even though the exporter throws
      span.end();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // If we reach here without an unhandled exception, the test passes.
      // Shutdown should also not throw.
      await failingProcessor.shutdown();
    });

    test('shutdown waits for pending exports and shuts down exporter',
        () async {
      await OTel.reset();
      final trackingExporter = _TrackingSpanExporter();
      final trackingProcessor = SimpleSpanProcessor(trackingExporter);
      await OTel.initialize(
        serviceName: 'test',
        spanProcessor: trackingProcessor,
        detectPlatformResources: false,
      );

      final tracer = OTel.tracer();
      final span = tracer.startSpan('shutdown-test-span');
      span.end();

      // Shutdown should wait for the pending export and then shut down the exporter
      await trackingProcessor.shutdown();

      expect(trackingExporter.shutdownCalled, isTrue);
      expect(trackingExporter.exportedSpans, hasLength(1));
      expect(
        trackingExporter.exportedSpans.first.name,
        equals('shutdown-test-span'),
      );
    });
  });
}
