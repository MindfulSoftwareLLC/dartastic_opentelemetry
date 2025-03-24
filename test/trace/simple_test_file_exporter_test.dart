import 'dart:typed_data';// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Simple TestFileExporter Test', () {
    late TestFileExporter exporter;
    final testDir = Directory.current.path;
    final outputPath = '$testDir/test/testing_utils/test_file_exporter_test.json';
    
    setUp(() {
      // Enable debug logging
      OTelLog.enableDebugLogging();
      
      // Make sure output directory exists
      final dir = Directory('$testDir/test/testing_utils');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      
      // Make sure output file exists and is empty
      final file = File(outputPath);
      if (file.existsSync()) {
        file.writeAsStringSync('');
      }
      
      // Create the exporter
      exporter = TestFileExporter(outputPath);
    });
    
    tearDown(() async {
      // Shutdown the exporter
      await exporter.shutdown();
      
      // Clean up the file
      final file = File(outputPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });
    
    test('TestFileExporter can export spans', () async {
      // Create a test span
      final span = SDKSpanCreate.create(
        delegateSpan: APISpanCreate.create(
          name: 'test-span',
          instrumentationScope: InstrumentationScope(
            name: 'test',
            version: '1.0.0',
          ),
          spanContext: SpanContext.fromTraceIdAndSpanId(
            TraceId(Uint8List(16)), // Random ID
            SpanId(Uint8List(8)),   // Random ID
            isRemote: false,
          ),
          spanKind: SpanKind.internal,
          startTime: DateTime.now(),
          isRecording: true,
        ),
        sdkTracer: null,
      );
      
      // Export the span
      await exporter.export([span]);
      
      // Verify the file exists and has content
      final file = File(outputPath);
      expect(file.existsSync(), isTrue, reason: 'Expected file to exist');
      
      // Verify the file has content
      final content = file.readAsStringSync();
      expect(content.isNotEmpty, isTrue, reason: 'Expected file to have content');
      
      // Verify the content can be parsed as JSON
      try {
        final json = jsonDecode(content);
        expect(json, isA<List>(), reason: 'Expected JSON to be a list');
        
        // Verify the span data
        expect(json.length, 1, reason: 'Expected 1 list of spans');
        expect(json[0], isA<List>(), reason: 'Expected inner JSON to be a list');
        expect(json[0].length, 1, reason: 'Expected 1 span');
        
        // Check the span properties
        final spanJson = json[0][0];
        expect(spanJson['name'], 'test-span', reason: 'Expected span name to be test-span');
      } catch (e) {
        fail('Error parsing JSON: $e\nContent: $content');
      }
    });
  });
}
