// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/test_file_exporter.dart';

void main() {
  group('Direct File Export Test', () {
    late TestFileExporter fileExporter;
    late SimpleSpanProcessor processor;
    final testDir = Directory.current.path;
    final outputPath = '$testDir/test/testing_utils/direct_spans.json';

    setUp(() async {
      // Enable debug logging
      OTelLog.enableDebugLogging();

      // Clean state
      await OTel.reset();

      // Ensure output file exists and is empty
      File(outputPath).writeAsStringSync('');

      // Create our direct file exporter
      fileExporter = TestFileExporter(outputPath);

      // Create a processor using our exporter
      processor = SimpleSpanProcessor(fileExporter);

      // Initialize OTel with minimal but valid config
      await OTel.initialize(
        serviceName: 'direct-test-service',
        serviceVersion: '1.0.0',
        enableMetrics: false,
      );

      // Add our processor to the tracer provider
      OTel.tracerProvider().addSpanProcessor(processor);
    });

    tearDown(() async {
      try {
        // First clean up in order
        await OTel.tracerProvider().forceFlush();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await OTel.tracerProvider().shutdown();

        // Additional cleanup to be sure
        await processor.shutdown();
        await fileExporter.shutdown();
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error('Error during test cleanup: $e');
        }
      }

      // Reset for next test
      await OTel.reset();
    });

    test('direct file export spans correctly', () async {
      // Create and end a span
      final tracer = OTel.tracerProvider().getTracer('direct-file-test');

      final span = tracer.startSpan('direct-test-span');
      span.setStringAttribute<String>('test.key', 'test.value');
      span.setIntAttribute('test.number', 123);

      // Small delay to simulate work
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // End the span which should trigger exporting
      span.end();

      // Force flush to ensure it's exported
      await OTel.tracerProvider().forceFlush();

      // Wait a bit to ensure file writing completes
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify the file has content
      final fileContent = await File(outputPath).readAsString();
      if (OTelLog.isDebug()) OTelLog.debug('File content: $fileContent');

      // Basic sanity check
      expect(fileContent.contains('direct-test-span'), isTrue);

      // Parse the JSON to verify structure
      if (fileContent.isNotEmpty) {
      final jsonData = jsonDecode(fileContent);
      if (OTelLog.isDebug()) OTelLog.debug('JSON Data: $jsonData');

      // Expect to be an array
      expect(jsonData, isA<List<Map<String, dynamic>>>());

      // First element should contain our span
      if (jsonData is List && jsonData.isNotEmpty) {
        final firstBatch = jsonData[0];
        expect(firstBatch, isA<List<Map<String, dynamic>>>());

        if (firstBatch is List && firstBatch.isNotEmpty) {
          final spanData = firstBatch[0];
          expect(spanData is Map, isTrue);
          if (spanData is Map) {
            expect(spanData['name'], 'direct-test-span');
          }
        }
      }
      }
    });

    test('recordSpan creates a span that gets exported', () async {
      // Create a span using recordSpan
      final tracer = OTel.tracerProvider().getTracer('direct-file-test');

      final result = tracer.recordSpan(
        name: 'record-span-test',
        fn: () {
          // Do some work
          var sum = 0;
          for (var i = 0; i < 1000; i++) {
            sum += i;
          }
          return sum;
        },
      );

      // Verify function executed
      expect(result, 499500);

      // Force flush
      await OTel.tracerProvider().forceFlush();

      // Wait a bit
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify span was exported
      final fileContent = await File(outputPath).readAsString();
      expect(fileContent.contains('record-span-test'), isTrue);
    });
  });
}
