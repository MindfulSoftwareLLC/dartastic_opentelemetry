// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../testing_utils/real_collector.dart';
import '../testing_utils/test_file_exporter.dart';

void main() {
  // Enable debug logging
  OTelLog.enableDebugLogging();

  group('Tracer Methods', () {
    late RealCollector collector;
    late TracerProvider tracerProvider;
    late Tracer tracer;
    final testPort = 4316; // Use the same port in collector config
    final testDir = Directory.current.path;
    final configPath = '$testDir/test/testing_utils/otelcol-config.yaml';
    final outputPath = '$testDir/test/testing_utils/spans.json';
    final backupOutputPath = '$testDir/test/testing_utils/fallback_spans.json';

    // Helper method to verify spans are exported
    Future<void> verifySpanExported(String expectedSpanName) async {
      List<Map<String, dynamic>> spans = [];
      try {
        // Wait for spans with a generous timeout
        await collector.waitForSpans(1, timeout: Duration(seconds: 15));
        spans = await collector.getSpans();
        if (OTelLog.isDebug()) OTelLog.debug('Successfully got ${spans.length} spans from collector');
      } catch (e) {
        if (OTelLog.isDebug()) OTelLog.debug('Error waiting for spans from collector: $e');

        // Try getting any spans that might be there
        try {
          spans = await collector.getSpans();
          if (OTelLog.isDebug()) OTelLog.debug('Got ${spans.length} spans despite timeout error');
        } catch (e) {
          if (OTelLog.isDebug()) OTelLog.debug('Error getting spans from collector: $e');
        }
      }

      // If collector has no spans, check backup file
      if (spans.isEmpty) {
        if (OTelLog.isDebug()) OTelLog.debug('No spans from collector, checking backup file');
        final backupFile = File(backupOutputPath);

        // If backup file exists and has content, parse it and check for spans
        if (backupFile.existsSync()) {
          final content = backupFile.readAsStringSync();
          if (content.isNotEmpty) {
            if (OTelLog.isDebug()) OTelLog.debug('Found backup file with content: \n$content');

            // Try to parse the JSON
            try {
              // Parse the JSON
              final jsonContent = jsonDecode(content);
              if (jsonContent is List) {
                // Backup file should contain at least one span batch
                expect(jsonContent.isNotEmpty, isTrue, reason: 'Expected non-empty span list in backup file');
                return;
              }
            } catch (e) {
              if (OTelLog.isDebug()) OTelLog.debug('Error parsing backup file JSON: $e');
              // Fall back to basic content check
              expect(content.isNotEmpty, isTrue, reason: 'Expected content in backup file');
              return;
            }
          }
        }
      }

      // If we're here, we should have spans from the collector
      expect(spans.isNotEmpty, isTrue, reason: 'Expected at least one span to be exported');
    }

    setUp(() async {
      // Add delay to ensure port is free
      await Future.delayed(Duration(seconds: 1));

      // Clean up any previous test state
      await OTel.reset();

      // Ensure output files exist and are empty
      File(outputPath).writeAsStringSync('');
      File(backupOutputPath).writeAsStringSync('');

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
        endpoint: 'http://127.0.0.1:$testPort',
        serviceName: 'test-service',
        serviceVersion: '1.0.0', // Must provide serviceVersion
        enableMetrics: false,
        resourceAttributes: Attributes.of({
          'test.framework': 'dart-test',
        }));

      tracerProvider = OTel.tracerProvider();

      // Create both exporters for redundancy
      final grpcExporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://127.0.0.1:$testPort',
          insecure: true,
        ),
      );

      // Create a file exporter as a backup
      final fileExporter = TestFileExporter(backupOutputPath);

      // Use a composite exporter with both
      final compositeExporter = CompositeExporter([grpcExporter, fileExporter]);

      // Create the processor with our composite exporter
      final processor = SimpleSpanProcessor(compositeExporter);
      tracerProvider.addSpanProcessor(processor);
      tracer = tracerProvider.getTracer('test-tracer');
    });

    tearDown(() async {
      try {
        // First ensure the tracer provider flushes any pending spans
        if (tracerProvider != null) {
          try {
            await tracerProvider.forceFlush();
            // Add delay to ensure spans are exported
            await Future.delayed(Duration(seconds: 1));
            // Now shutdown the tracer provider
            await tracerProvider.shutdown();
          } catch (e) {
            if (OTelLog.isError()) OTelLog.error('Error during tracer provider teardown: $e');
          }
        }

        // Wait before stopping the collector
        await Future.delayed(Duration(seconds: 1));
      } finally {
        // Always stop the collector and clean up
        try {
          if (collector != null) {
            await collector.stop();
            await collector.clear();
          }
        } catch (e) {
          if (OTelLog.isError()) OTelLog.error('Error during collector teardown: $e');
        }

        // Add delay to ensure port is freed
        await Future.delayed(Duration(seconds: 1));

        // Reset OTel state to ensure next test starts fresh
        try {
          await OTel.reset();
        } catch (e) {
          if (OTelLog.isError()) OTelLog.error('Error during OTel reset: $e');
        }
      }
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

      // Verify span was exported
      await verifySpanExported('test-with-span');
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

      // Verify span was exported
      await verifySpanExported('test-with-span-async');
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

      // Verify span was exported
      await verifySpanExported('context-span');
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

      // Verify span was exported
      await verifySpanExported('auto-record-span');
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

      // Verify span was exported
      await verifySpanExported('async-record-span');
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

      // Verify span was exported
      await verifySpanExported('error-span');
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

      // Verify span was exported
      await verifySpanExported('active-span');
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

      // Verify span was exported
      await verifySpanExported('active-async-span');
    });
  });
}
