// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

void main() {
  group('Tracer Methods', () {
    late TracerProvider tracerProvider;
    late Tracer tracer;
    late InMemorySpanExporter exporter;
    late SimpleSpanProcessor processor;

    setUp(() async {
      // Reset OTel completely
      await OTel.reset();

      // Initialize with a clean setup
      await OTel.initialize(
        serviceName: 'test-tracer-methods-service',
        serviceVersion: '1.0.0',
        enableMetrics: false,
      );

      tracerProvider = OTel.tracerProvider();

      // Create in-memory exporter and processor
      exporter = InMemorySpanExporter();
      processor = SimpleSpanProcessor(exporter);

      // Add the processor to capture spans
      tracerProvider.addSpanProcessor(processor);

      tracer = tracerProvider.getTracer('test-tracer-methods');
    });

    tearDown(() async {
      await processor.shutdown();
      await exporter.shutdown();
      await tracerProvider.shutdown();
      await OTel.reset();
    });

    test('withSpan executes code with an active span', () async {
      exporter.clear();

      // Arrange
      String result = '';
      final span = tracer.startSpan('test-with-span');

      // Act
      tracer.withSpan(
        span,
        () {
          final currentSpan = tracer.currentSpan;
          result = currentSpan?.name ?? 'No active span';
          return result;
        },
      );

      // End the span explicitly since withSpan doesn't end it
      span.end();

      // Force export
      await processor.forceFlush();

      // Assert
      expect(result, equals('test-with-span'));
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('test-with-span'), isTrue);
    });

    test('withSpanAsync executes async code with an active span', () async {
      exporter.clear();

      // Arrange
      String result = '';
      final span = tracer.startSpan('test-with-span-async');

      // Act
      await tracer.withSpanAsync(
        span,
        () async {
          // Simulate async work
          await Future<void>.delayed(const Duration(milliseconds: 10));
          final currentSpan = tracer.currentSpan;
          result = currentSpan?.name ?? 'No active span';
          return result;
        },
      );

      // End the span explicitly since withSpanAsync doesn't end it
      span.end();

      // Force export
      await processor.forceFlush();

      // Assert
      expect(result, equals('test-with-span-async'));
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('test-with-span-async'), isTrue);
    });

    test('recordSpan creates and automatically ends a span', () async {
      exporter.clear();

      // Act
      final result = tracer.recordSpan(
        name: 'auto-record-span',
        fn: () {
          return 'success';
        },
      );

      // Force export
      await processor.forceFlush();

      // Assert
      expect(result, equals('success'));
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('auto-record-span'), isTrue);

      final exportedSpan = exporter.findSpanByName('auto-record-span')!;
      expect(exportedSpan.isEnded, isTrue);
    });

    test('recordSpanAsync creates and automatically ends an async span',
        () async {
      exporter.clear();

      // Act
      final result = await tracer.recordSpanAsync(
        name: 'async-record-span',
        fn: () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 'async success';
        },
      );

      // Force export
      await processor.forceFlush();

      // Assert
      expect(result, equals('async success'));
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('async-record-span'), isTrue);

      final exportedSpan = exporter.findSpanByName('async-record-span')!;
      expect(exportedSpan.isEnded, isTrue);
    });

    test('recordSpan captures exceptions and sets error status', () async {
      exporter.clear();

      // Act & Assert
      expect(
        () => tracer.recordSpan(
          name: 'error-span',
          fn: () {
            throw Exception('Test error in recordSpan');
          },
        ),
        throwsException,
      );

      // Force export
      await processor.forceFlush();

      // Verify span was created and exported even though exception was thrown
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('error-span'), isTrue);

      final exportedSpan = exporter.findSpanByName('error-span')!;
      expect(exportedSpan.isEnded, isTrue);
      expect(exportedSpan.status, equals(SpanStatusCode.Error));
    });

    test('startActiveSpan activates span during execution', () async {
      exporter.clear();

      // Act
      final result = tracer.startActiveSpan(
        name: 'active-span',
        fn: (span) {
          // Get current span to verify it's the same
          final currentSpan = tracer.currentSpan;
          expect(currentSpan, equals(span));
          return 'active span success';
        },
      );

      // Force export
      await processor.forceFlush();

      // Assert
      expect(result, equals('active span success'));
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('active-span'), isTrue);

      final exportedSpan = exporter.findSpanByName('active-span')!;
      expect(exportedSpan.isEnded, isTrue);
    });

    test('startActiveSpanAsync activates span during async execution',
        () async {
      exporter.clear();

      // Act
      final result = await tracer.startActiveSpanAsync(
        name: 'active-async-span',
        fn: (span) async {
          // Simulate async work
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Get current span to verify it's the same
          final currentSpan = tracer.currentSpan;
          expect(currentSpan, equals(span));
          return 'active async span success';
        },
      );

      // Force export
      await processor.forceFlush();

      // Assert
      expect(result, equals('active async span success'));
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('active-async-span'), isTrue);

      final exportedSpan = exporter.findSpanByName('active-async-span')!;
      expect(exportedSpan.isEnded, isTrue);
    });

    test('withSpan maintains span context during execution', () async {
      exporter.clear();

      final parentSpan = tracer.startSpan('parent-span');
      final parentContext = OTel.context().withSpan(parentSpan);

      tracer.withSpan(
        parentSpan,
        () {
          // Start a child span within the parent context
          final childSpan =
              tracer.startSpan('child-span', context: parentContext);
          childSpan.end();
        },
      );

      parentSpan.end();

      await processor.forceFlush();

      // Verify both spans were exported
      expect(exporter.spans, hasLength(2));
      expect(exporter.hasSpanWithName('parent-span'), isTrue);
      expect(exporter.hasSpanWithName('child-span'), isTrue);

      // Verify parent-child relationship
      final parentExported = exporter.findSpanByName('parent-span')!;
      final childExported = exporter.findSpanByName('child-span')!;

      expect(childExported.parentSpanContext!.spanId,
          equals(parentExported.spanContext.spanId));
      expect(childExported.spanContext.traceId,
          equals(parentExported.spanContext.traceId));
    });
  });
}
