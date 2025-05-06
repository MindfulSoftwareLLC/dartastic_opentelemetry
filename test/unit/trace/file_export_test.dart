// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/test_file_exporter.dart';

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

      // Ensure output file exists and is completely empty
      File(outputPath).writeAsStringSync('');

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

        await Future<void>.delayed(const Duration(seconds: 1));
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
      final span = tracer.startSpan('test-with-span');

      // Act
      tracer.withSpan(
        span,
        () {
          final currentSpan = tracer.currentSpan;
          print('Current span in withSpan: ${currentSpan?.name}');
          result = currentSpan?.name ?? 'No active span';
          return result;
        },
      );

      // Must manually end the span - this is key for it to be exported
      span.end();

      // Assert
      expect(result, equals('test-with-span'));

      // Force flush to ensure span is exported
      print('Force flushing to ensure export');
      await processor.forceFlush();
      await Future<void>.delayed(const Duration(seconds: 1));

      // Verify the span was written to file
      final File file = File(outputPath);
      if (!file.existsSync()) {
        fail('Expected output file does not exist');
      }

      final fileContent = file.readAsStringSync();
      print('File content: $fileContent');

      if (fileContent.isEmpty) {
        fail('File content is empty - no spans were exported');
      }

      try {
        // Parse JSON and check for span - handling the new batched format
        final dynamic parsedContent = jsonDecode(fileContent);
        if (parsedContent is! List) {
          fail('Expected JSON content to be a List but got ${parsedContent.runtimeType}');
        }
        final List<List<Map<String, dynamic>>> batches = parsedContent as List<List<Map<String, dynamic>>>;
        print('Found ${batches.length} batches in file');

        expect(batches, isNotEmpty, reason: 'Expected at least one batch of spans');

        bool found = false;
        // Iterate through batches
        for (final batch in batches) {
          expect(batch, isA<List<Map<String, dynamic>>>(), reason: 'Expected batch to be a list of spans');

          // Iterate through spans in the batch
          for (final span in batch) {
            if (span.containsKey('name')) {
              print('Found span: ${span["name"]}');
              if (span['name'] == 'test-with-span') {
                found = true;
                break;
              }
            }
          }
          
          if (found) break;
        }

        expect(found, isTrue, reason: 'Expected to find span with name "test-with-span"');
      } catch (e) {
        fail('Error parsing file content: $e');
      }
    });

    test('withSpanAsync executes async code with an active span', () async {
      print('Starting test: withSpanAsync executes async code with an active span');

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
          print('Current span in withSpanAsync: ${currentSpan?.name}');
          result = currentSpan?.name ?? 'No active span';
          return result;
        },
      );

      // Must manually end the span - this is key for it to be exported
      span.end();

      // Assert
      expect(result, equals('test-with-span-async'));

      // Force flush to ensure span is exported
      print('Force flushing to ensure export');
      await processor.forceFlush();
      await Future<void>.delayed(const Duration(seconds: 1));

      // Verify the span was written to file
      final fileContent = await File(outputPath).readAsString();
      print('File content: $fileContent');

      try {
        // Parse JSON and check for span - handling the new batched format
        final dynamic parsedContent = jsonDecode(fileContent);
        if (parsedContent is! List) {
          fail('Expected JSON content to be a List but got ${parsedContent.runtimeType}');
        }
        final List<List<Map<String, dynamic>>> batches = parsedContent as List<List<Map<String, dynamic>>>;
        print('Found ${batches.length} batches in file');

        expect(batches, isNotEmpty, reason: 'Expected at least one batch of spans');

        bool found = false;
        // Iterate through batches
        for (final batch in batches) {
          expect(batch, isA<List<Map<String, dynamic>>>(), reason: 'Expected batch to be a list of spans');

          // Iterate through spans in the batch
          for (final spanData in batch) {
            if (spanData.containsKey('name')) {
              print('Found span: ${spanData["name"]}');
              if (spanData['name'] == 'test-with-span-async') {
                found = true;
                break;
              }
            }
          }
          
          if (found) break;
        }

        expect(found, isTrue, reason: 'Expected to find span with name "test-with-span-async"');
      } catch (e) {
        fail('Error parsing file content: $e');
      }
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
      await Future<void>.delayed(const Duration(seconds: 1));

      // Verify the span was written to file
      final fileContent = await File(outputPath).readAsString();
      print('File content: $fileContent');

      try {
        // Parse JSON and check for span - handling the new batched format
        final dynamic parsedContent = jsonDecode(fileContent);
        if (parsedContent is! List) {
          fail('Expected JSON content to be a List but got ${parsedContent.runtimeType}');
        }
        final List<List<Map<String, dynamic>>> batches = parsedContent as List<List<Map<String, dynamic>>>;
        print('Found ${batches.length} batches in file');

        expect(batches, isNotEmpty, reason: 'Expected at least one batch of spans');

        bool found = false;
        // Iterate through batches
        for (final batch in batches) {
          expect(batch, isA<List<Map<String, dynamic>>>(), reason: 'Expected batch to be a list of spans');

          // Iterate through spans in the batch
          for (final spanData in batch) {
            if (spanData.containsKey('name')) {
              print('Found span: ${spanData["name"]}');
              if (spanData['name'] == 'auto-record-span') {
                found = true;
                break;
              }
            }
          }
          
          if (found) break;
        }

        expect(found, isTrue, reason: 'Expected to find span with name "auto-record-span"');
      } catch (e) {
        fail('Error parsing file content: $e');
      }
    });
  });
}
