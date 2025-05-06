// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

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
      // Shutdown the exporter
      await exporter.shutdown();

      // Reset OTel
      await OTel.reset();

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
        final json = jsonDecode(content);
        expect(json, isA<List<List<Map<String, dynamic>>>>(), reason: 'Expected JSON to be a list of batches');

        // Verify span data exists
        expect(json.isNotEmpty == true, isTrue, reason: 'Expected non-empty JSON array');

        // If we have a batch, check the first span properties
        if (json.isNotEmpty == true) {
          final firstBatch = json[0];
          expect(firstBatch, isA<List<Map<String, dynamic>>>(), reason: 'Expected batch to be a list of spans');

          if (firstBatch.isNotEmpty == true) {
            final span = firstBatch[0];
            expect(span, isA<Map<String, dynamic>>(), reason: 'Expected span to be a map');
            expect(span['name'], equals('test-span'), reason: 'Expected span name to match');
            expect(span['attributes'], isA<Map<String, dynamic>>(), reason: 'Expected span to have attributes');
            expect(span['attributes']['test.key'], equals('test.value'), reason: 'Expected attribute to be set');
          }
        }
      } catch (e) {
        fail('Error parsing JSON: $e\nContent: $content');
      }
    });
  });
}
