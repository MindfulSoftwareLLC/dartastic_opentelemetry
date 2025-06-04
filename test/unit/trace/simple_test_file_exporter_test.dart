// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// ignore_for_file: strict_raw_type

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/test_file_exporter.dart';

void main() {
  group('Simple TestFileExporter Test', () {
    late TestFileExporter exporter;
    final testDir = Directory.current.path;
    final outputPath = '$testDir/test/testing_utils/test_file_exporter_test.json';

    setUp(() async {
      // Enable debug logging
      OTelLog.enableDebugLogging();

      // Make sure output directory exists
      final dir = Directory('$testDir/test/testing_utils');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Make sure output file exists and is completely empty
      final file = File(outputPath);
      file.writeAsStringSync(''); // Always empty the file

      // Create the exporter
      exporter = TestFileExporter(outputPath);

      // Initialize OTel
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );
    });

    tearDown(() async {
      await OTel.shutdown();

      // Shutdown the exporter
      await exporter.shutdown();

      // Clean up the file
      final file = File(outputPath);
      if (file.existsSync()) {
        // Don't delete, just empty for inspection
        file.writeAsStringSync('');
      }
    });

    test('TestFileExporter can export spans', () async {
      // Get a tracer from OTel
      final tracer = OTel.tracerProvider().getTracer('test-exporter');

      // Create a list to capture the spans for later export
      final spans = <Span>[];

      // Create a span through the normal API
      final span = tracer.startSpan('test-span');
      span.setStringAttribute<String>('test.key', 'test.value');

      // End the span
      span.end();

      // Add to our list
      spans.add(span);

      // Export the span directly using our exporter
      await exporter.export(spans);

      // Verify the file exists and has content
      final file = File(outputPath);
      expect(file.existsSync(), isTrue, reason: 'Expected file to exist');

      // Verify the file has content
      final content = file.readAsStringSync();
      print('File content after export: $content');
      expect(content.isNotEmpty, isTrue, reason: 'Expected file to have content');

      // Verify the content can be parsed as JSON
      try {
        final dynamic jsonData = jsonDecode(content);
        
        // Verify it's a list (of batches)
        expect(jsonData, isA<List>(), reason: 'Expected JSON to be a list');
        
        // Cast to List for type safety
        final batches = jsonData as List;
        expect(batches, isNotEmpty, reason: 'Expected non-empty list of batches');

        // Get the first batch
        final firstBatch = batches[0];
        expect(firstBatch, isA<List>(), reason: 'Expected batch to be a list');
        
        // Cast batch to List for type safety
        final batchList = firstBatch as List;
        expect(batchList, isNotEmpty, reason: 'Expected non-empty batch');

        // Get the first span
        final spanData = batchList[0];
        expect(spanData, isA<Map>(), reason: 'Expected span to be a map');
        
        // Cast span to Map for type safety
        final spanMap = spanData as Map<String, dynamic>;
        
        // Verify span properties
        expect(spanMap['name'], equals('test-span'), reason: 'Expected span name to match');
        expect(spanMap['attributes'], isA<Map>(), reason: 'Expected span to have attributes');
        
        final attributes = spanMap['attributes'] as Map<String, dynamic>;
        expect(attributes['test.key'], equals('test.value'), reason: 'Expected attribute to be set');
        
      } catch (e) {
        fail('Error parsing JSON: $e\nContent: $content');
      }
    });

    test('TestFileExporter exports multiple spans correctly', () async {
      // Clear the file first
      File(outputPath).writeAsStringSync('');

      // Get a tracer from OTel
      final tracer = OTel.tracerProvider().getTracer('test-exporter');

      // Create multiple spans
      final spans = <Span>[];
      for (int i = 0; i < 3; i++) {
        final span = tracer.startSpan('test-span-$i');
        span.setIntAttribute('span.index', i);
        span.end();
        spans.add(span);
      }

      // Export all spans at once
      await exporter.export(spans);

      // Verify the file has content
      final content = File(outputPath).readAsStringSync();
      expect(content, isNotEmpty);

      // Parse and verify
      final dynamic jsonData = jsonDecode(content);
      final batches = jsonData as List;
      expect(batches, isNotEmpty);

      // Get first batch and verify it contains all 3 spans
      final firstBatch = batches[0] as List;
      expect(firstBatch, hasLength(3));

      // Verify each span
      for (int i = 0; i < 3; i++) {
        final spanMap = firstBatch[i] as Map<String, dynamic>;
        expect(spanMap['name'], equals('test-span-$i'));
        final attributes = spanMap['attributes'] as Map<String, dynamic>;
        expect(attributes['span.index'], equals(i));
      }
    });

    test('TestFileExporter handles empty span list', () async {
      // Clear the file first
      File(outputPath).writeAsStringSync('');

      // Export empty list
      await exporter.export([]);

      // File should still be empty since no spans were exported
      final content = File(outputPath).readAsStringSync();
      expect(content, isEmpty);
    });
  });
}
