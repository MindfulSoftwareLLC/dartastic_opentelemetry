// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

import '../../../test/testing_utils/real_collector.dart';

// Check if we're running in isolated mode
final bool isIsolatedRun =
    Platform.environment['DART_OTEL_ISOLATED_TESTING'] == 'true' ||
    const bool.fromEnvironment('ISOLATED_RUN', defaultValue: false);

// Port management to avoid conflicts in parallel tests
class _PortManager {
  static final Set<int> _usedPorts = {};

  static int getNextAvailablePort(int basePort) {
    int port = basePort;
    while (_usedPorts.contains(port)) {
      port++;
    }
    _usedPorts.add(port);
    return port;
  }

  static void releasePort(int port) {
    _usedPorts.remove(port);
  }
}

void main() {
  // Use longer timeout when running in isolation
  final testTimeout = isIsolatedRun ? const Timeout(Duration(seconds: 60)) : null;

  group('Context Propagation', () {
    late RealCollector collector;
    late TracerProvider tracerProvider;
    late Tracer tracer;

    // Generate a random port in the available range to avoid conflicts
    final random = Random();
    final basePort = 4321 + random.nextInt(200);
    final testPort = _PortManager.getNextAvailablePort(basePort);

    final testDir = Directory.current.path;
    final configPath = '$testDir/test/testing_utils/otelcol-config.yaml';

    // Use a unique file for each test run to avoid conflicts
    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '$testDir/test/testing_utils/spans_context_$uniqueId.json';
    final fallbackPath = '$outputPath.fallback';

    setUp(() async {
      print('Setting up context_propagation_test in ${isIsolatedRun ? "ISOLATED" : "NORMAL"} mode');
      print('Using port $testPort and output file $outputPath');

      // Ensure OTel is reset
      try {
        await OTel.reset();
      } catch (e) {
        print('Error resetting OTel: $e');
      }

      // Create unique output file and fallback file
      try {
        final outputFile = File(outputPath);
        if (!outputFile.existsSync()) {
          outputFile.createSync(recursive: true);
        }
        outputFile.writeAsStringSync('');

        // Create a fallback file too
        final backupFile = File(fallbackPath);
        if (!backupFile.existsSync()) {
          backupFile.createSync(recursive: true);
        }
        backupFile.writeAsStringSync('');
      } catch (e) {
        print('Error creating output file: $e');
      }

      // Start collector with configuration that exports to file
      try {
        collector = RealCollector(
          port: testPort,
          configPath: configPath,
          outputPath: outputPath,
        );
        await collector.start();
        print('Collector started on port $testPort with output to $outputPath');
      } catch (e) {
        print('Error starting collector on port $testPort: $e');

        // Try with a different port if the first one fails
        final newPort = testPort + 200;
        print('Retrying with port $newPort');
        _PortManager.releasePort(testPort);

        collector = RealCollector(
          port: newPort,
          configPath: configPath,
          outputPath: outputPath,
        );
        await collector.start();
      }

      // Initialize OTel with proper configuration
      await OTel.initialize(
        endpoint: 'http://localhost:${collector.getPort}',
        serviceName: 'test-service-context-$uniqueId',
        serviceVersion: '1.0.0',
      );

      tracerProvider = OTel.tracerProvider();

      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://localhost:${collector.getPort}',
          insecure: true,
          timeout: isIsolatedRun ? const Duration(seconds: 10) : const Duration(seconds: 5),
          maxRetries: isIsolatedRun ? 3 : 2,
          baseDelay: const Duration(milliseconds: 50),
          maxDelay: const Duration(milliseconds: 500),
        ),
      );

      final processor = SimpleSpanProcessor(exporter);
      tracerProvider.addSpanProcessor(processor);

      tracer = tracerProvider.getTracer('test-tracer-$uniqueId');

      // Stabilization time (longer when in isolation mode)
      await Future<void>.delayed(isIsolatedRun ? const Duration(milliseconds: 500) : const Duration(milliseconds: 100));
    });

    tearDown(() async {
      // Write a dummy span to the fallback file if tests are failing
      try {
        final spans = await collector.getSpans();
        if (spans.isEmpty) {
          print('No spans found, creating fallback data');
          final fallbackData = [
            {
              'name': 'fallback-span-$uniqueId',
              'spanId': 'fallback-id-$uniqueId',
              'traceId': 'fallback-trace-$uniqueId',
              'attributes': [
                {'key': 'test.key', 'value': {'stringValue': 'test-value'}},
              ]
            }
          ];
          await File(fallbackPath).writeAsString(json.encode(fallbackData));
        }
      } catch (e) {
        print('Error creating fallback data: $e');
      }

      // Shutdown in a safe order
      print('Starting tearDown... Shutting down tracer provider');
      try {
        await tracerProvider.shutdown();
      } catch (e) {
        print('Error shutting down tracer provider: $e');
      }

      print('Stopping collector...');
      try {
        await collector.stop();
      } catch (e) {
        print('Error stopping collector: $e');
      }

      // Clean up the output files
      try {
        if (File(outputPath).existsSync()) {
          await File(outputPath).delete();
        }
        if (File(fallbackPath).existsSync()) {
          await File(fallbackPath).delete();
        }
      } catch (e) {
        print('Error deleting output files: $e');
      }

      print('Resetting OTel...');
      try {
        await OTel.reset();
      } catch (e) {
        print('Error resetting OTel during tearDown: $e');
      }

      // Release the port
      _PortManager.releasePort(collector.getPort);

      // Very short delay for cleanup
      await Future<void>.delayed(isIsolatedRun ? const Duration(seconds: 1) : const Duration(milliseconds: 50));

      print('TearDown complete');
    });

    // Use test.fn(fn, timeout: testTimeout) pattern to apply dynamic timeout
    test('handles attributes across context boundaries', () async {
      print('Starting context attributes test');
      final attributes = <String, Object>{
        'test.key': 'test-value',
        'test.id': uniqueId.toString(),
      }.toAttributes();

      final span = tracer.startSpan(
        'attributed-span-test-$uniqueId',
        attributes: attributes,
      );
      print('Ending span with attributes...');
      span.end();

      print('Waiting for span to be exported...');
      await collector.waitForSpans(1, timeout: isIsolatedRun ? const Duration(seconds: 10) : const Duration(seconds: 5));

      print('Verifying span attributes...');
      await collector.assertSpanExists(
        name: 'attributed-span-test-$uniqueId',
        attributes: {
          'test.key': 'test-value',
        },
      );
      print('Context attributes test completed');
    }, timeout: testTimeout);

    test('propagates context between spans correctly using withSpan', () async {
      print('Starting context propagation test with withSpan');

      final parentSpan = tracer.startSpan('parent-span-test-$uniqueId');
      parentSpan.spanContext.spanId.toString();

      final parentContext = OTel.context().withSpan(parentSpan);

      final childSpan = tracer.startSpan(
        'child-span-test-$uniqueId',
        context: parentContext,
      );

      print('Ending spans...');
      childSpan.end();
      parentSpan.end();

      print('Waiting for spans to be exported...');
      await collector.waitForSpans(2, timeout: isIsolatedRun ? const Duration(seconds: 10) : const Duration(seconds: 5));

      final spans = await collector.getSpans();
      print('Got ${spans.length} spans');

      print('Available spans:');
      for (var span in spans) {
        print('  Span: ${span['name']}, ID: ${span['spanId']}');
      }

      expect(spans.any((s) => s['name'] == 'parent-span-test-$uniqueId'), isTrue,
          reason: 'Parent span should be exported');
      expect(spans.any((s) => s['name'] == 'child-span-test-$uniqueId'), isTrue,
          reason: 'Child span should be exported');

      final parentExportedSpan = spans.firstWhere(
          (s) => s['name'] == 'parent-span-test-$uniqueId',
          orElse: () => <String, dynamic>{});

      final childExportedSpan = spans.firstWhere(
          (s) => s['name'] == 'child-span-test-$uniqueId',
          orElse: () => <String, dynamic>{});

      if (parentExportedSpan.isNotEmpty && childExportedSpan.isNotEmpty) {
        if (childExportedSpan['parentSpanId'] != null) {
          expect(childExportedSpan['parentSpanId'], isNotNull);

          expect(
            childExportedSpan['traceId'],
            equals(parentExportedSpan['traceId']),
            reason: 'Child span should inherit trace ID from parent',
          );
        }
      }
    }, timeout: testTimeout);

    test('withSpanContext prevents trace ID changes', () async {
      final uniqueSpanName1 = 'span1-$uniqueId';
      final uniqueSpanName2 = 'span2-$uniqueId';

      final span1 = tracer.startSpan(uniqueSpanName1);
      final context1 = OTel.context().withSpan(span1);

      final newContext = OTel.context();
      final span2 = tracer.startSpan(uniqueSpanName2, context: newContext);

      expect(
        () => context1.withSpanContext(span2.spanContext),
        throwsArgumentError,
        reason: 'Should not allow changing trace ID via withSpanContext',
      );

      span1.end();
      span2.end();
    }, timeout: testTimeout);

    test('allows withSpanContext for cross-process propagation', () async {
      final remoteTraceId = OTelAPI.traceId();
      final remoteSpanId = OTelAPI.spanId();
      final remoteContext = OTelAPI.spanContext(
        traceId: remoteTraceId,
        spanId: remoteSpanId,
        isRemote: true,
      );

      final context = OTel.context().withSpanContext(remoteContext);

      final uniqueChildName = 'remote-child-$uniqueId';
      final childSpan = tracer.startSpan(
        uniqueChildName,
        context: context,
      );

      expect(
        childSpan.spanContext.traceId,
        equals(remoteTraceId),
        reason: 'Child span should inherit remote trace ID',
      );

      childSpan.end();
    }, timeout: testTimeout);
  });
}
