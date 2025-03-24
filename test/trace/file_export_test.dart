// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/trace/export/test_file_exporter.dart';

void main() {
  group('File Export Test', () {
    late TestFileExporter exporter;
    late SimpleSpanProcessor processor;
    late TracerProvider tracerProvider;
    late Tracer tracer;
    final outputPath = '${Directory.current.path}/test/testing_utils/test_spans.json';

    setUp(() async {
      print('=== Starting File Export Test ===');
      OTelLog.enableDebugLogging();

      // Clean state for each test
      await OTel.reset();

      // Ensure output file exists and is empty
      File(outputPath).writeAsStringSync('[]');

      // Initialize OTel with minimal configuration
      await OTel.initialize(
        endpoint: 'http://127.0.0.1:4316', // Not actually used
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
        enableMetrics: false,
      );

      print('Creating test file exporter');
      exporter = TestFileExporter(outputPath);

      // Create a simple processor with our file exporter
      processor = SimpleSpanProcessor(exporter);

      tracerProvider = OTel.tracerProvider();
      tracerProvider.addSpanProcessor(processor);
      tracer = tracerProvider.getTracer('test-tracer');

      print('Setup complete');
    });

    tearDown(() async {
      try {
        print('Test teardown - cleaning up resources');

        // Flush any pending spans
        try {
          print('Flushing tracer provider');
          await tracerProvider.forceFlush();
        } catch (e) {
          print('Error during flush: $e');
        }

        // Shutdown components in reverse order
        try {
          print('Shutting down tracer provider');
          await tracerProvider.shutdown();
        } catch (e) {
          print('Error shutting down tracer provider: $e');
        }

        await Future.delayed(Duration(seconds: 1));
        print('Teardown complete');
      } finally {
        // Reset OTel for good measure
        await OTel.reset();
      }
    });

    test('withSpan executes code with an active span', () async {
      print('Starting test: withSpan executes code with an active span');

      // Arrange
      String result = '';

      // Act
      tracer.withSpan(
        tracer.startSpan('test-with-span'),
        () {
          final currentSpan = tracer.currentSpan;
          print('Current span in withSpan: ${currentSpan?.name}');
          result = currentSpan?.name ?? 'No active span';
          return result;
        },
      );

      // Assert
      expect(result, equals('test-with-span'));

      // Force flush to ensure span is exported
      print('Force flushing to ensure export');
      await processor.forceFlush();
      await Future.delayed(Duration(seconds: 1));

      // Verify the span was written to file
      final fileContent = await File(outputPath).readAsString();
      print('File content: $fileContent');

      // Parse JSON and check for span
      final spans = json.decode(fileContent);
      expect(spans, isNotEmpty);

      bool found = false;
      for (final span in spans) {
        print('Span in file: ${span['name']}');
        if (span['name'] == 'test-with-span') {
          found = true;
          break;
        }
      }

      expect(found, isTrue, reason: 'Expected to find span with name "test-with-span"');
    });

    test('withSpanAsync executes async code with an active span', () async {
      print('Starting test: withSpanAsync executes async code with an active span');

      // Arrange
      String result = '';

      // Act
      await tracer.withSpanAsync(
        tracer.startSpan('test-with-span-async'),
        () async {
          // Simulate async work
          await Future.delayed(Duration(milliseconds: 10));
          final currentSpan = tracer.currentSpan;
          print('Current span in withSpanAsync: ${currentSpan?.name}');
          result = currentSpan?.name ?? 'No active span';
          return result;
        },
      );

      // Assert
      expect(result, equals('test-with-span-async'));

      // Force flush to ensure span is exported
      print('Force flushing to ensure export');
      await processor.forceFlush();
      await Future.delayed(Duration(seconds: 1));

      // Verify the span was written to file
      final fileContent = await File(outputPath).readAsString();
      print('File content: $fileContent');

      // Parse JSON and check for span
      final spans = json.decode(fileContent);
      expect(spans, isNotEmpty);

      bool found = false;
      for (final span in spans) {
        print('Span in file: ${span['name']}');
        if (span['name'] == 'test-with-span-async') {
          found = true;
          break;
        }
      }

      expect(found, isTrue, reason: 'Expected to find span with name "test-with-span-async"');
    });

    test('recordSpan creates and automatically ends a span', () async {
      print('Starting test: recordSpan creates and automatically ends a span');

      // Act
      final result = tracer.recordSpan(
        name: 'auto-record-span',
        fn: () {
          return 'success';
        },
      );

      // Assert
      expect(result, equals('success'));

      // Force flush to ensure span is exported
      print('Force flushing to ensure export');
      await processor.forceFlush();
      await Future.delayed(Duration(seconds: 1));

      // Verify the span was written to file
      final fileContent = await File(outputPath).readAsString();
      print('File content: $fileContent');

      // Parse JSON and check for span
      final spans = json.decode(fileContent);
      expect(spans, isNotEmpty);

      bool found = false;
      for (final span in spans) {
        print('Span in file: ${span['name']}');
        if (span['name'] == 'auto-record-span') {
          found = true;
          break;
        }
      }

      expect(found, isTrue, reason: 'Expected to find span with name "auto-record-span"');
    });
  });
}
