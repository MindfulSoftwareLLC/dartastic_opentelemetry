// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../testing_utils/real_collector.dart';

void main() {
  group('Tracer Methods', () {
    late RealCollector collector;
    late TracerProvider tracerProvider;
    late Tracer tracer;
    final testPort = 4322; // Use unique port
    final testDir = Directory.current.path;
    final configPath = '$testDir/test/testing_utils/otelcol-config.yaml';
    final outputPath = '$testDir/test/testing_utils/spans.json';

    setUp(() async {
      // Ensure output file exists and is empty
      File(outputPath).writeAsStringSync('');

      // Start collector with configuration that exports to file
      collector = RealCollector(
        port: testPort,
        configPath: configPath,
        outputPath: outputPath,
      );
      await collector.start();

      // Reset and initialize OTel
      await OTel.reset();
      await OTel.initialize(
        endpoint: 'http://localhost:$testPort',
        serviceName: 'test-service',
        enableMetrics: false); // Disable metrics to avoid port conflicts

      tracerProvider = OTel.tracerProvider();

      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://localhost:$testPort',
          insecure: true,
        ),
      );

      final processor = SimpleSpanProcessor(exporter);
      tracerProvider.addSpanProcessor(processor);
      tracer = tracerProvider.getTracer('test-tracer');
    });

    tearDown(() async {
      // Ensure proper cleanup order
      await tracerProvider.shutdown();
      await collector.stop();
      await collector.clear();

      // Add delay to ensure port is freed
      await Future.delayed(Duration(milliseconds: 100));
    });

    test('withSpan executes code with an active span', () async {
      // Arrange
      String result = '';

      // Act
      tracer.withSpan(
        tracer.startSpan('test-with-span'),
        () {
          final currentSpan = tracer.currentSpan;
          result = currentSpan?.name ?? 'No active span';
          return result;
        },
      );

      // Assert
      expect(result, equals('test-with-span'));

      // Wait for span to be exported
      await collector.waitForSpans(1);
      await collector.assertSpanExists(name: 'test-with-span');
    });

    test('withSpanAsync executes async code with an active span', () async {
      // Arrange
      String result = '';

      // Act
      await tracer.withSpanAsync(
        tracer.startSpan('test-with-span-async'),
        () async {
          // Simulate async work
          await Future.delayed(Duration(milliseconds: 10));
          final currentSpan = tracer.currentSpan;
          result = currentSpan?.name ?? 'No active span';
          return result;
        },
      );

      // Assert
      expect(result, equals('test-with-span-async'));

      // Wait for span to be exported
      await collector.waitForSpans(1);
      await collector.assertSpanExists(name: 'test-with-span-async');
    });

    test('startSpanWithContext creates a span in the provided context', () async {
      // Arrange
      final customContext = OTel.context();

      // Act
      final span = tracer.startSpanWithContext(
        name: 'context-span',
        context: customContext,
      );
      span.end();

      // Assert
      expect(span.name, equals('context-span'));

      // Wait for span to be exported
      await collector.waitForSpans(1);
      await collector.assertSpanExists(name: 'context-span');
    });

    test('recordSpan creates and automatically ends a span', () async {
      // Act
      final result = tracer.recordSpan(
        name: 'auto-record-span',
        fn: () {
          return 'success';
        },
      );

      // Assert
      expect(result, equals('success'));

      // Wait for span to be exported
      await collector.waitForSpans(1);
      await collector.assertSpanExists(name: 'auto-record-span');
    });

    test('recordSpanAsync creates and automatically ends an async span', () async {
      // Act
      final result = await tracer.recordSpanAsync(
        name: 'async-record-span',
        fn: () async {
          await Future.delayed(Duration(milliseconds: 10));
          return 'async success';
        },
      );

      // Assert
      expect(result, equals('async success'));

      // Wait for span to be exported
      await collector.waitForSpans(1);
      await collector.assertSpanExists(name: 'async-record-span');
    });

    test('recordSpan captures exceptions and sets error status', () async {
      // Act & Assert
      expect(
        () => tracer.recordSpan(
          name: 'error-span',
          fn: () {
            throw Exception('Test error');
          },
        ),
        throwsException,
      );

      // Wait for span to be exported
      await collector.waitForSpans(1);

      // Get spans and verify the status
      final spans = await collector.getSpans();
      expect(spans, isNotEmpty);
      expect(spans.first['status'], isNotNull);
      expect(spans.first['status']['code'], equals(2)); // 2 corresponds to ERROR
      expect(spans.first['status']['message'], contains('Test error'));
    });

    test('startActiveSpan activates span during execution', () async {
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

      // Assert
      expect(result, equals('active span success'));

      // Wait for span to be exported
      await collector.waitForSpans(1);
      await collector.assertSpanExists(name: 'active-span');
    });

    test('startActiveSpanAsync activates span during async execution', () async {
      // Act
      final result = await tracer.startActiveSpanAsync(
        name: 'active-async-span',
        fn: (span) async {
          // Simulate async work
          await Future.delayed(Duration(milliseconds: 10));

          // Get current span to verify it's the same
          final currentSpan = tracer.currentSpan;
          expect(currentSpan, equals(span));
          return 'active async span success';
        },
      );

      // Assert
      expect(result, equals('active async span success'));

      // Wait for span to be exported
      await collector.waitForSpans(1);
      await collector.assertSpanExists(name: 'active-async-span');
    });
  });
}
