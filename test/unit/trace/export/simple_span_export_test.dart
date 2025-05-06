// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../../testing_utils/real_collector.dart';
import '../../../testing_utils/test_file_exporter.dart';

void main() {
  group('Simple Span Export', () {
    late RealCollector collector;
    late OtlpGrpcSpanExporter exporter;
    late SimpleSpanProcessor processor;
    final testPort = 4316; // Use the port from the config
    final testDir = Directory.current.path;
    final configPath = '$testDir/test/testing_utils/otelcol-config.yaml';
    final outputPath = '$testDir/test/testing_utils/spans.json';

    setUp(() async {
      print('=== Starting Simple Span Export Test ===');
      // Enable verbose logging
      OTelLog.enableDebugLogging();

      // Clean state for each test
      await OTel.reset();

      // Ensure output file exists and is empty
      File(outputPath).writeAsStringSync('');

      // Start collector with configuration that exports to file
      collector = RealCollector(
        port: testPort,
        configPath: configPath,
        outputPath: outputPath,
      );
      await collector.start();

      // Extra wait to ensure collector is ready
      await Future<void>.delayed(const Duration(seconds: 2));

      print('Collector started, initializing exporter');

      // Create dual exporters - one direct to file for debugging
      final testFileExporter = TestFileExporter('$testDir/test/testing_utils/direct_spans.json');

      // Create OTLP gRPC exporter
      exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://127.0.0.1:$testPort',
          insecure: true,
          timeout: const Duration(seconds: 10), // Long timeout for debugging
        ),
      );

      // Create a composite exporter
      final compositeExporter = CompositeExporter([exporter, testFileExporter]);

      // Create a simple processor with the composite exporter
      processor = SimpleSpanProcessor(compositeExporter);
    });

    tearDown(() async {
      try {
        // Shutdown in reverse order
        await processor.shutdown();
        await exporter.shutdown();

        // Allow time for cleanup
        await Future<void>.delayed(const Duration(seconds: 1));
      } catch (e) {
        print('Error during test cleanup: $e');
      } finally {
        // Always stop collector
        try {
          await collector.stop();
          await collector.clear();
        } catch (e) {
          print('Error stopping collector: $e');
        }
        await Future<void>.delayed(const Duration(seconds: 1));

        // Reset OTel for good measure
        await OTel.reset();
      }
      print('=== Test Teardown Complete ===');
    });

    test('Exports a span directly using processor', () async {
      // Initialize OTel with minimal configuration
      await OTel.initialize(
        endpoint: 'http://127.0.0.1:$testPort',
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
        enableMetrics: false,
      );

      // Create a span directly
      print('Creating test span');
      final tracer = OTel.tracerProvider().getTracer('test-tracer');
      final span = tracer.startSpan('direct-test-span');

      // Add some attributes for good measure
      span.setStringAttribute<String>('test.key', 'test.value');

      // Process the span with our processor
      print('Processing span with span processor');
      await processor.onStart(span, null);

      // End the span
      span.end();

      // Process end event
      print('Processing span end event');
      await processor.onEnd(span);

      // Force flush to be sure
      print('Forcing processor flush');
      await processor.forceFlush();

      // Wait for exporter to send data
      print('Waiting for span export');
      await Future<void>.delayed(const Duration(seconds: 2));

      // Check file content directly
      final fileContent = File(outputPath).readAsStringSync();
      print('File content size: ${fileContent.length} bytes');
      print('File content: $fileContent');

      // Wait for collector to process
      print('Waiting for collector to process');
      try {
        await collector.waitForSpans(1, timeout: const Duration(seconds: 10));
        print('Successfully waited for spans');
      } catch (e) {
        print('Error waiting for spans: $e');
        // Continue with test - we'll check manually
      }

      // Get spans directly
      final spans = await collector.getSpans();
      print('Found ${spans.length} spans');

      for (var span in spans) {
        print('Span: ${span['name']}, traceId: ${span['traceId']}');
      }

      // Even if waitForSpans failed, we directly check file content
      expect(fileContent.isNotEmpty, isTrue, reason: 'Span file should not be empty');
    });
  });
}
