// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/otlp_grpc_span_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/otlp_grpc_span_exporter_config.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';

import '../../../testing_utils/real_collector.dart';
import '../../../testing_utils/network_proxy.dart';

// Helper function to create a test span using OTel factory methods
Span createTestSpan({
  required String name,
  String? traceId,
  String? spanId,
  Map<String, Object>? attributes,
}) {
  final spanContext = OTel.spanContext(
    traceId: OTel.traceIdFrom(traceId ?? '00112233445566778899aabbccddeeff'),
    spanId: OTel.spanIdFrom(spanId ?? '0011223344556677'),
  );

  final resource = OTel.resource(OTel.attributesFromMap({
    'service.name': 'test-service',
  }));

  final tracer = OTel.tracerProvider().getTracer(
    'test-tracer',
    version: '1.0.0',
  );

  final span = tracer.startSpan(
    name,
    context: OTel.context().withSpanContext(spanContext),
    kind: SpanKind.internal,
    attributes: attributes != null ? OTel.attributesFromMap(attributes) : null,
  );

  return span;
}

void main() {
  group('OtlpGrpcSpanExporter Retry Behavior', () {
    late RealCollector collector;
    late NetworkProxy proxy;
    late OtlpGrpcSpanExporter exporter;
    final testDir = Directory.current.path;
    final configPath = '$testDir/test/testing_utils/otelcol-config.yaml';
    final outputPath = '$testDir/test/testing_utils/spans.json';

    setUp(() async {
      await OTel.initialize(spanProcessor: null);
      // Ensure output file exists and is empty
      File(outputPath).writeAsStringSync('');

      // Setup collector and proxy
      collector = RealCollector(
        configPath: configPath,
        outputPath: outputPath,
      );
      await collector.start();

      proxy = NetworkProxy(
        listenPort: 4317,  // Use standard OTLP port
        targetHost: 'localhost',
        targetPort: 4316,  // Collector uses different port
      );
      await proxy.start();

      // Setup exporter to connect through proxy
      exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://localhost:4317',  // Standard OTLP port
          insecure: true,
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 50),
          maxDelay: Duration(milliseconds: 200),
        ),
      );
    });

    tearDown(() async {
      await OTel.reset();
      await exporter.shutdown();
      await proxy.stop();
      await collector.stop();
      await collector.clear();
    });

    test('retries on temporary failures', () async {
      proxy.failNextRequests(2);  // First attempt + 1 retry will fail

      final spans = [
        createTestSpan(
          name: 'retry-test-span',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556677',
        ),
      ];

      await exporter.export(spans);
      await collector.waitForSpans(1);
      await collector.assertSpanExists(name: 'retry-test-span');
    });

    test('respects max retry limit', () async {
      proxy.failNextRequests(5, errorCode: grpc.StatusCode.unavailable);  // More failures than max retries

      final spans = [
        createTestSpan(
          name: 'max-retry-test-span',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556677',
        ),
      ];

      await expectLater(
        () => exporter.export(spans),
        throwsA(isA<grpc.GrpcError>().having(
          (e) => e.code,
          'code',
          equals(grpc.StatusCode.unavailable),
        )),
      );

      final allSpans = await collector.getSpans();
      expect(allSpans, isEmpty);  // Should fail after max retries
    });

    test('handles permanent failure without retrying', () async {
      // When a proxy rejects with invalid argument, it shouldn't retry
      proxy.failNextRequests(1, errorCode: grpc.StatusCode.invalidArgument);

      final spans = [
        createTestSpan(
          name: 'permanent-failure-span',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556677',
        ),
      ];

      await expectLater(
        () => exporter.export(spans),
        throwsA(isA<grpc.GrpcError>().having(
          (e) => e.code,
          'code',
          equals(grpc.StatusCode.invalidArgument),
        )),
      );

      final allSpans = await collector.getSpans();
      expect(allSpans, isEmpty);  // Should not have retried or exported
    });

    test('handles intermittent failures with backoff', () async {
      // Alternate between failing and succeeding
      proxy.setFailurePattern([
        grpc.StatusCode.unavailable,
        null,  // success
        grpc.StatusCode.unavailable,
        null,  // success
      ]);

      final spans = List.generate(
        4,
        (i) => createTestSpan(
          name: 'intermittent-span-$i',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '00112233445566$i$i',
        ),
      );

      for (var span in spans) {
        await exporter.export([span]);
      }

      await collector.waitForSpans(4);
      for (var i = 0; i < 4; i++) {
        await collector.assertSpanExists(name: 'intermittent-span-$i');
      }
    });

    test('handles shutdown during active retries', () async {
      // Set up failures that will cause retries
      proxy.failNextRequests(3, errorCode: grpc.StatusCode.unavailable);

      final exportFuture = exporter.export([
        createTestSpan(
          name: 'shutdown-during-retry',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556677',
        ),
      ]);

      // Shutdown while export is still retrying
      await Future.delayed(Duration(milliseconds: 100));
      await exporter.shutdown();

      // Export should complete before shutdown finishes
      await exportFuture;
      // Verify span was eventually exported
      await collector.assertSpanExists(name: 'shutdown-during-retry');
    });

    test('handles large batch exports with retry', () async {
      proxy.failNextRequests(1, errorCode: grpc.StatusCode.unavailable); // First attempt fails

      final largeSpanBatch = List.generate(
        100,
        (i) => createTestSpan(
          name: 'large-batch-span-$i',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556677',
          attributes: {'index': '$i'},
        ),
      );

      await exporter.export(largeSpanBatch);
      await collector.waitForSpans(100);

      for (var i = 0; i < 100; i++) {
        await collector.assertSpanExists(
          name: 'large-batch-span-$i',
          attributes: {'index': '$i'},
        );
      }
    });

    test('handles multiple concurrent exports with retries', () async {
      // Each concurrent request will fail once
      proxy.failNextRequests(3, errorCode: grpc.StatusCode.unavailable);  // One failure per export

      final exports = List.generate(
        3,
        (i) => exporter.export([
          createTestSpan(
            name: 'concurrent-span-$i',
            traceId: '00112233445566778899aabbccddeeff',
            spanId: '00112233445566$i$i',
          ),
        ]),
      );

      await Future.wait(exports);
      await collector.waitForSpans(3);

      for (var i = 0; i < 3; i++) {
        await collector.assertSpanExists(name: 'concurrent-span-$i');
      }
    });

    test('handles connection loss and recovery', () async {
      final spans = [
        createTestSpan(
          name: 'connection-loss-span',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556677',
        ),
      ];

      // Export with working connection
      await exporter.export(spans);
      await collector.waitForSpans(1);

      // Stop proxy to simulate connection loss
      await proxy.stop();

      // Attempt export during connection loss
      final exportFuture = exporter.export([
        createTestSpan(
          name: 'during-connection-loss',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556688',
        ),
      ]);

      // Restart proxy before retries complete
      await Future.delayed(Duration(milliseconds: 100));
      await proxy.start();  // Will create new server socket

      await exportFuture;
      await collector.waitForSpans(2);
      await collector.assertSpanExists(name: 'during-connection-loss');
    });

    test('handles multiple concurrent exports with retries', () async {
      // Each concurrent request will fail once
      proxy.failNextRequests(3, errorCode: grpc.StatusCode.unavailable);  // One failure per export

      final exports = List.generate(
        3,
            (i) => exporter.export([
          createTestSpan(
            name: 'concurrent-span-$i',
            traceId: '00112233445566778899aabbccddeeff',
            spanId: '00112233445566$i$i',
          ),
        ]),
      );

      await Future.wait(exports);
      await collector.waitForSpans(3);

      for (var i = 0; i < 3; i++) {
        await collector.assertSpanExists(name: 'concurrent-span-$i');
      }
    });

    test('handles connection loss and recovery', () async {
      final spans = [
        createTestSpan(
          name: 'connection-loss-span',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556677',
        ),
      ];

      // Export with working connection
      await exporter.export(spans);
      await collector.waitForSpans(1);

      // Stop proxy to simulate connection loss
      await proxy.stop();

      // Attempt export during connection loss
      final exportFuture = exporter.export([
        createTestSpan(
          name: 'during-connection-loss',
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '0011223344556688',
        ),
      ]);

      // Restart proxy before retries complete
      await Future.delayed(Duration(milliseconds: 100));
      await proxy.start();  // Will create new server socket

      await exportFuture;
      await collector.waitForSpans(2);
      await collector.assertSpanExists(name: 'during-connection-loss');
    });

  });
}
