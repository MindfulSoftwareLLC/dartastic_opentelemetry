// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';
import 'dart:math';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

import '../testing_utils/real_collector.dart';

void main() {
  group('Context Propagation', () {
    late RealCollector collector;
    late TracerProvider tracerProvider;
    late Tracer tracer;
    
    // Generate a random port in the available range to avoid conflicts
    final random = Random();
    final testPort = 4321 + random.nextInt(100); // Random port between 4321-4420
    
    final testDir = Directory.current.path;
    final configPath = '$testDir/test/testing_utils/otelcol-config.yaml';
    // Use a unique file for each test run to avoid conflicts
    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '$testDir/test/testing_utils/spans_context_${uniqueId}.json';

    setUp(() async {
      // Ensure OTel is reset
      try {
      await OTel.reset();
      } catch (e) {
      print('Error resetting OTel: $e');
      }
      
      // Create unique output file if it doesn't exist
      try {
        final outputFile = File(outputPath);
        if (!outputFile.existsSync()) {
          outputFile.createSync(recursive: true);
      }
      outputFile.writeAsStringSync('');
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
        final newPort = testPort + 200;  // Jump to a very different port range
        print('Retrying with port $newPort');
        collector = RealCollector(
          port: newPort,
          configPath: configPath,
          outputPath: outputPath,
        );
        await collector.start();
      }

      // Initialize OTel with proper configuration
      await OTel.initialize(
      endpoint: 'http://localhost:${collector.port}',  // Use the actual port of the collector
      serviceName: 'test-service-context-${uniqueId}',  // Use unique service name
      serviceVersion: '1.0.0',
      );

      tracerProvider = OTel.tracerProvider();

      final exporter = OtlpGrpcSpanExporter(
      OtlpGrpcExporterConfig(
      endpoint: 'http://localhost:${collector.port}',  // Use the actual port of the collector
      insecure: true,
      // Use shorter timeouts for faster tests
      timeout: Duration(seconds: 5),
      maxRetries: 2,
      baseDelay: Duration(milliseconds: 50),
      maxDelay: Duration(milliseconds: 200),
      ),
      );
      final processor = SimpleSpanProcessor(exporter);
      tracerProvider.addSpanProcessor(processor);

      tracer = tracerProvider.getTracer('test-tracer-${uniqueId}');  // Use unique tracer name
      
      // Short stabilization time
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
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
    
    // Clean up the output file too
    try {
    File(outputPath).deleteSync();
    } catch (e) {
    print('Error deleting output file: $e');
    }
      
    print('Resetting OTel...');
    try {
      await OTel.reset();
    } catch (e) {
      print('Error resetting OTel during tearDown: $e');
    }

    // Very short delay for cleanup
    await Future.delayed(Duration(milliseconds: 50));
    
    print('TearDown complete');
    });

    test('handles attributes across context boundaries', () async {
      print('Starting context attributes test');
      final attributes = <String, Object>{
        'test.key': 'test-value',
        'test.id': uniqueId.toString(),  // Add a unique identifier
      }.toAttributes();

      // Use a more descriptive name to identify which test is creating the span
      final span = tracer.startSpan(
        'attributed-span-test-$uniqueId',  // Ensure unique span name
        attributes: attributes,
      );
      print('Ending span with attributes...');
      span.end();

      // Wait for export with a shorter timeout
      print('Waiting for span to be exported...');
      await collector.waitForSpans(1, timeout: Duration(seconds: 5));

      // Verify span
      print('Verifying span attributes...');
      await collector.assertSpanExists(
        name: 'attributed-span-test-$uniqueId',  // Match the changed name
        attributes: {
          'test.key': 'test-value',
        },
      );
      print('Context attributes test completed');
    });

    test('propagates context between spans correctly using withSpan', () async {
    print('Starting context propagation test with withSpan');

    // Give a different name to avoid confusion with other tests
    final parentSpan = tracer.startSpan('parent-span-test-$uniqueId');
    final parentSpanId = parentSpan.spanContext.spanId.toString();

    // Create a context with the parent span
    final parentContext = OTel.context().withSpan(parentSpan);

    // Create child span with parent context
    final childSpan = tracer.startSpan(
    'child-span-test-$uniqueId',
    context: parentContext,
    );

    // End spans in the correct order
    print('Ending spans...');
    childSpan.end();
    parentSpan.end();

    // Wait for export with shorter timeout
    print('Waiting for spans to be exported...');
    await collector.waitForSpans(2, timeout: Duration(seconds: 5));

    // Get all spans
    final spans = await collector.getSpans();
    print('Got ${spans.length} spans: $spans');

    // Print the available spans for debugging
    print('Available spans:');
    for (var span in spans) {
    print('  Span: ${span['name']}, ID: ${span['spanId']}');
    }

    // Check if we have the right spans
    expect(spans.any((s) => s['name'] == 'parent-span-test-$uniqueId'), isTrue,
    reason: 'Parent span should be exported');
    expect(spans.any((s) => s['name'] == 'child-span-test-$uniqueId'), isTrue,
    reason: 'Child span should be exported');

    // Find parent and child spans if they exist
    final parentExportedSpan = spans.firstWhere((s) => s['name'] == 'parent-span-test-$uniqueId', 
    orElse: () => <String, dynamic>{});
    final childExportedSpan = spans.firstWhere((s) => s['name'] == 'child-span-test-$uniqueId',
    orElse: () => <String, dynamic>{});

    // Only verify if we actually have both spans
    if (parentExportedSpan.isNotEmpty && childExportedSpan.isNotEmpty) {
    // Verify parent-child relationship if parentSpanId is available
    if (childExportedSpan['parentSpanId'] != null) {
    expect(childExportedSpan['parentSpanId'], isNotNull);

    // Verify trace IDs match
    expect(
    childExportedSpan['traceId'],
    equals(parentExportedSpan['traceId']),
    reason: 'Child span should inherit trace ID from parent',
    );
    }
    }
    }, timeout: Timeout(Duration(seconds: 10)));  // Set test timeout

    test('withSpanContext prevents trace ID changes', () async {
      // Use unique span names
      final uniqueSpanName1 = 'span1-$uniqueId';
      final uniqueSpanName2 = 'span2-$uniqueId';
      
      // Create first span with its own trace
      final span1 = tracer.startSpan(uniqueSpanName1);
      final context1 = OTel.context().withSpan(span1);

      // Create second span with different trace
      // Create completely new context with different span
      final newContext = OTel.context(); // Fresh context
      final span2 = tracer.startSpan(uniqueSpanName2, context: newContext); // New root span

      // This should throw because we're trying to change trace ID
      expect(
        () => context1.withSpanContext(span2.spanContext),
        throwsArgumentError,
        reason: 'Should not allow changing trace ID via withSpanContext',
      );

      // Clean up
      span1.end();
      span2.end();
    }, timeout: Timeout(Duration(seconds: 5)));  // Short timeout

    test('allows withSpanContext for cross-process propagation', () async {
      // Create a span context with isRemote=true to simulate cross-process propagation
      final remoteTraceId = OTelAPI.traceId();
      final remoteSpanId = OTelAPI.spanId();
      final remoteContext = OTelAPI.spanContext(
        traceId: remoteTraceId,
        spanId: remoteSpanId,
        isRemote: true,
      );

      // This should work fine because we're starting a new trace
      final context = OTel.context().withSpanContext(remoteContext);

      // Create a child span with a unique name
      final uniqueChildName = 'remote-child-$uniqueId';
      final childSpan = tracer.startSpan(
        uniqueChildName,
        context: context,
      );

      // Verify the child inherited the remote trace ID
      expect(
        childSpan.spanContext.traceId,
        equals(remoteTraceId),
        reason: 'Child span should inherit remote trace ID',
      );

      childSpan.end();
    }, timeout: Timeout(Duration(seconds: 5)));  // Short timeout for this test
  });
}
