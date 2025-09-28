// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// ignore_for_file: strict_raw_type

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/test_file_exporter.dart';

void main() {
  group('Direct File Export Test', () {
    late TestFileExporter fileExporter;
    late SimpleSpanProcessor processor;
    late TracerProvider tracerProvider;
    final testDir = Directory.current.path;
    final outputPath = '$testDir/test/testing_utils/direct_spans.json';

    setUp(() async {
      // Enable debug logging for better troubleshooting
      OTelLog.enableDebugLogging();

      // Clean state - reset before initializing
      await OTel.reset();

      // Ensure output file exists and is empty
      final outputFile = File(outputPath);
      if (!outputFile.parent.existsSync()) {
        outputFile.parent.createSync(recursive: true);
      }
      outputFile.writeAsStringSync('');

      // Initialize OTel with minimal but valid config first
      await OTel.initialize(
        serviceName: 'direct-test-service',
        serviceVersion: '1.0.0',
        enableMetrics: false,
      );

      // Get the tracer provider
      tracerProvider = OTel.tracerProvider();

      // Create our direct file exporter after OTel is initialized
      fileExporter = TestFileExporter(outputPath);

      // Create a processor using our exporter
      processor = SimpleSpanProcessor(fileExporter);

      // Add our processor to the tracer provider AFTER initialization
      tracerProvider.addSpanProcessor(processor);
    });

    tearDown(() async {
      try {
        // First shutdown our custom processor
        await processor.shutdown();
        await fileExporter.shutdown();

        // Then shutdown OTel
        await OTel.shutdown();
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error('Error during test cleanup: $e');
        }
      }

      // Reset for next test
      await OTel.reset();
    });

    test('direct file export spans correctly', () async {
      print('=== Starting direct file export test ===');

      // Create and end a span
      final tracer = tracerProvider.getTracer('direct-file-test');
      print('Got tracer from provider');

      final span = tracer.startSpan('direct-test-span',
          attributes:
              Attributes.of({'test.key': 'test.value', 'test.number': 123}));
      print('Created span: ${span.name}');

      // Small delay to simulate work
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // End the span which should trigger exporting
      print('Ending span...');
      span.end();
      print('Span ended, isEnded: ${span.isEnded}');

      // Force flush to ensure it's exported - wait for completion
      print('Force flushing tracer provider...');
      await tracerProvider.forceFlush();
      print('Force flushing processor...');
      await processor.forceFlush();
      print('Flush operations completed');

      // Give extra time for file operations
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Verify the file has content
      final fileContent = await File(outputPath).readAsString();
      print(
          'File content after export (length=${fileContent.length}): $fileContent');

      // Basic sanity check - the file should contain our span name
      expect(fileContent.contains('direct-test-span'), isTrue);

      // Parse the JSON to verify structure if content exists
      if (fileContent.isNotEmpty) {
        final jsonData = jsonDecode(fileContent);

        // The JSON should be a list of batches (List<List<Map<String, dynamic>>>)
        expect(jsonData, isA<List>());

        // Should have at least one batch
        expect(jsonData, isNotEmpty);

        // First element should be a batch (list of spans)
        final firstBatch = jsonData[0];
        expect(firstBatch, isA<List>());
        expect(firstBatch, isNotEmpty);

        // First span in the batch should be our span
        final spanData = firstBatch[0];
        expect(spanData, isA<Map<String, dynamic>>());
        expect(spanData['name'], equals('direct-test-span'));

        // Verify attributes are present
        expect(spanData['attributes'], isA<Map<String, dynamic>>());
        expect(spanData['attributes']['test.key'], equals('test.value'));
        expect(spanData['attributes']['test.number'], equals(123));
      }
    });

    test('recordSpan creates a span that gets exported', () async {
      print('=== Starting recordSpan test ===');

      // Clear the file first for this test
      File(outputPath).writeAsStringSync('');

      // Create a span using recordSpan
      final tracer = tracerProvider.getTracer('direct-file-test');

      print('Calling recordSpan...');
      final result = tracer.recordSpan(
        name: 'record-span-test',
        fn: () {
          print('Inside recordSpan function...');
          // Do some work
          var sum = 0;
          for (var i = 0; i < 1000; i++) {
            sum += i;
          }
          return sum;
        },
      );
      print('recordSpan completed with result: $result');

      // Verify function executed correctly
      expect(result, 499500);

      // Force flush to ensure it's exported
      print('Flushing after recordSpan...');
      await tracerProvider.forceFlush();
      await processor.forceFlush();

      // Give extra time for file operations
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Verify span was exported
      final fileContent = await File(outputPath).readAsString();
      print(
          'recordSpan file content (length=${fileContent.length}): $fileContent');

      expect(fileContent.contains('record-span-test'), isTrue);

      // Parse and verify structure if content exists
      if (fileContent.isNotEmpty) {
        final jsonData = jsonDecode(fileContent);
        expect(jsonData, isA<List>());
        expect(jsonData, isNotEmpty);

        final firstBatch = jsonData[0];
        expect(firstBatch, isA<List>());
        expect(firstBatch, isNotEmpty);

        final spanData = firstBatch[0];
        expect(spanData, isA<Map<String, dynamic>>());
        expect(spanData['name'], equals('record-span-test'));
      }
    });

    test('multiple spans are exported correctly', () async {
      print('=== Starting multiple spans test ===');

      // Clear the file first for this test
      File(outputPath).writeAsStringSync('');

      final tracer = tracerProvider.getTracer('direct-file-test');

      // Create multiple spans
      print('Creating 3 spans...');
      for (int i = 0; i < 3; i++) {
        final span = tracer.startSpan('multi-span-$i',
            attributes: Attributes.of({'span.index': i}));
        span.end();
        print('Created and ended span $i');
      }

      // Force flush to ensure all spans are exported
      print('Flushing after multiple spans...');
      await tracerProvider.forceFlush();
      await processor.forceFlush();

      // Give extra time for file operations
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Verify spans were exported
      final fileContent = await File(outputPath).readAsString();
      print(
          'Multiple spans file content (length=${fileContent.length}): $fileContent');

      expect(fileContent, isNotEmpty);

      if (fileContent.isNotEmpty) {
        // Parse and verify structure
        final dynamic jsonData = jsonDecode(fileContent);
        expect(jsonData, isA<List>());

        // Collect all spans from all batches with proper type casting
        final allSpans = <Map<String, dynamic>>[];

        // Cast to List first, then iterate
        final batches = jsonData as List;
        for (final batchData in batches) {
          expect(batchData, isA<List>());

          // Cast batch to List and iterate through spans
          final batch = batchData as List;
          for (final spanData in batch) {
            expect(spanData, isA<Map<String, dynamic>>());
            allSpans.add(spanData as Map<String, dynamic>);
          }
        }

        print('Found ${allSpans.length} spans in file');

        // Should have 3 spans total
        expect(allSpans, hasLength(3));

        // Verify each span exists (order might vary)
        for (int i = 0; i < 3; i++) {
          final expectedSpanName = 'multi-span-$i';
          final matchingSpan = allSpans.firstWhere(
            (span) => span['name'] == expectedSpanName,
            orElse: () => throw StateError(
                'Span $expectedSpanName not found in: ${allSpans.map((s) => s['name']).toList()}'),
          );

          expect(matchingSpan['attributes']['span.index'], equals(i));
        }
      }
    });
  });
}
