// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/otlp_grpc_span_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/otlp_grpc_span_exporter_config.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:test/test.dart';

import '../../../testing_utils/real_collector.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';

// Helper function to create a test span using OTel factory methods
Span createTestSpan({
  required String name,
  String? traceId,
  String? spanId,
  Map<String, Object>? attributes,
  DateTime? startTime,
  DateTime? endTime,
}) {
  final context = OTel.spanContext(
    traceId: OTel.traceIdFrom(traceId ?? '00112233445566778899aabbccddeeff'),
    spanId: OTel.spanIdFrom(spanId ?? '0011223344556677'),
  );

  final tracer = OTel.tracerProvider().getTracer(
    'test-tracer',
    version: '1.0.0',
  );

  final span = tracer.createSpan(
    name: name,
    startTime: startTime,
    kind: SpanKind.internal,
    attributes: attributes != null ? OTel.attributesFromMap(attributes) : null,
    spanContext: context,
  );

  if (endTime != null) {
    span.end(endTime: endTime);
  }

  return span;
}

void main() {
  group('OtlpGrpcSpanExporter', () {
    late RealCollector collector;
    late OtlpGrpcSpanExporter exporter;
    final testDir = Directory.current.path;
    final configPath = '$testDir/test/testing_utils/otelcol-config.yaml';
    final outputPath = '$testDir/test/testing_utils/spans.json';

    setUpAll(() async {
      await OTel.reset();
      await OTel.initialize(
        endpoint: 'http://127.0.0.1:4316',
        serviceName: 'example-service',
        serviceVersion: '1.42.0.0');
    });

    setUp(() async {
      // Add delay to ensure port is free
      await Future.delayed(Duration(seconds: 1));
      // Ensure output file exists and is empty
      File(outputPath).writeAsStringSync('');

      collector = RealCollector(
        configPath: configPath,
        outputPath: outputPath,
      );
      await collector.start();

      exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://127.0.0.1:${collector.port}',
          insecure: true,
          maxRetries: 2,
          baseDelay: Duration(milliseconds: 50),
        ),
      );
    });

    tearDown(() async {
      // First force flush to ensure all spans are exported
      try {
        await exporter.forceFlush();
        await Future.delayed(Duration(seconds: 1));
      } catch (e) {
        print('Error during force flush: $e');
      }
      await exporter.shutdown();
      await collector.stop();
      await collector.clear();
    });

    test('exports spans successfully', () async {
      // Check that output file is clean
      final spans = await collector.getSpans();
      expect(spans, isEmpty, reason: 'Output file should be empty at start');

      final testSpan = createTestSpan(
        name: 'test-span',
        attributes: {
          'test.key': 'test.value',
        },
        traceId: '00112233445566778899aabbccddeeff',
        spanId: '0011223344556677',
      );

      // Export the span and give more time for processing
      await exporter.export([testSpan]);
      await Future.delayed(Duration(seconds: 2));

      // Check if file has any content
      final fileContent = await File(outputPath).readAsString();
      print('File content after export: ${fileContent.length} bytes');

      // Now wait for spans
      await collector.waitForSpans(1, timeout: Duration(seconds: 10));

      final spans2 = await collector.getSpans();
      print('Found ${spans2.length} spans: ${json.encode(spans2)}');

      // Check if we have spans with the expected attributes, not necessarily the exact name
      final newSpans = await collector.getSpans();
      expect(newSpans.isNotEmpty, isTrue, reason: 'Expected spans to be exported');

      // Look for the test.key attribute to verify our span was exported
      final hasSpanWithAttribute = newSpans.any((span) {
        final attrs = span['attributes'] as List?;
        if (attrs == null) return false;

        return attrs.any((attr) {
          return attr['key'] == 'test.key' &&
                 attr['value'] != null &&
                 attr['value']['stringValue'] == 'test.value';
        });
      });

      expect(hasSpanWithAttribute, isTrue, reason: 'Expected span with test.key attribute');
      print('Found span with the test.key attribute, test passed');
    });

    test('handles empty span list', () async {
      await exporter.export([]);
      final spans = await collector.getSpans();
      expect(spans, isEmpty);
    });

    test('exports multiple spans', () async {
      final spans = List.generate(
        3,
        (i) => createTestSpan(
          name: 'span-$i',
          attributes: {'index': '$i'},
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '00112233445566$i$i',
        ),
      );

      await exporter.export(spans);
      // Allow more time for span processing
      await Future.delayed(Duration(seconds: 2));
      await collector.waitForSpans(3, timeout: Duration(seconds: 10));

      for (var i = 0; i < 3; i++) {
        await collector.assertSpanExists(
          name: 'span-$i',
          attributes: {'index': '$i'},
        );
      }
    });

    test('handles timeout properly', () async {
      final slowExporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://127.0.0.1:${collector.port}',
          insecure: true,
          timeout: Duration(milliseconds: 1),
          maxRetries: 0,
        ),
      );

      final spans = [
        createTestSpan(
          name: 'timeout-test-span',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556677',
        )
      ];

      expect(
        () => slowExporter.export(spans),
        throwsA(isA<grpc.GrpcError>().having(
          (e) => e.code,
          'code',
          equals(grpc.StatusCode.deadlineExceeded),
        )),
      );
    });

    test('handles shutdown correctly', () async {
      await exporter.shutdown();
      expect(
        () => exporter.export([
          createTestSpan(
            name: 'post-shutdown-span',
            traceId: '00112233445566778899aabbccddeeff',
            spanId: '0011223344556677',
          )
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('forceFlush completes successfully', () async {
      final spans = [
        createTestSpan(
          name: 'flush-test-span',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556677',
        ),
      ];
      await exporter.export(spans);
      await exporter.forceFlush();
    });

    test('repeated shutdown is safe', () async {
      final spans = [
        createTestSpan(
          name: 'shutdown-test-span',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556677',
        ),
      ];
      await exporter.export(spans);
      await exporter.shutdown();
      await exporter.shutdown(); // Should not throw
    });
  });
}
