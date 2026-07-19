// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Lifecycle edge coverage shared by the OTLP HTTP exporters:
// shutdown-during-retry, forceFlush with pending exports, and
// flush/export after shutdown.

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late int port;
  var slowMillis = 0;
  late List<int> statusCodes;

  setUp(() async {
    await OTel.reset();
    OTelLog.logFunction = (_) {};
    slowMillis = 0;
    statusCodes = [];
    server = await HttpServer.bind('localhost', 0);
    port = server.port;
    server.listen((request) async {
      if (slowMillis > 0) {
        await Future<void>.delayed(Duration(milliseconds: slowMillis));
      }
      final code = statusCodes.isNotEmpty ? statusCodes.removeAt(0) : 200;
      request.response.statusCode = code;
      await request.drain<void>();
      await request.response.close();
    });
    await OTel.initialize(
      serviceName: 'lifecycle-test',
      detectPlatformResources: false,
      enableMetrics: false,
      enableLogs: false,
    );
    OTelLog.enableTraceLogging();
  });

  tearDown(() async {
    await server.close(force: true);
    await OTel.shutdown();
    await OTel.reset();
    OTelLog.logFunction = null;
    OTelLog.currentLevel = LogLevel.info;
  });

  List<Span> spans() {
    final span = OTel.tracer().startSpan('lifecycle')..end();
    return [span];
  }

  MetricData metricData() {
    final now = DateTime.now();
    final point = MetricPoint<int>(
      attributes: OTel.attributesFromMap({'k': 'v'}),
      startTime: now.subtract(const Duration(seconds: 1)),
      endTime: now,
      value: 7,
    );
    return MetricData(metrics: [
      Metric.sum(name: 'lifecycle_counter', points: [point])
    ]);
  }

  group('OtlpHttpSpanExporter lifecycle', () {
    OtlpHttpSpanExporter slowRetryExporter() => OtlpHttpSpanExporter(
          OtlpHttpExporterConfig(
            endpoint: 'http://localhost:$port',
            maxRetries: 5,
            baseDelay: const Duration(milliseconds: 40),
            maxDelay: const Duration(milliseconds: 80),
          ),
        );

    test('shutdown during retry aborts the export', () async {
      statusCodes = [503, 503, 503, 503, 503, 503];
      final exporter = slowRetryExporter();
      final pending = exporter.export(spans()).then((_) {}, onError: (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await exporter.shutdown();
      await pending;
    });

    test('forceFlush waits for a pending export', () async {
      slowMillis = 60;
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
      );
      final pending = exporter.export(spans());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await exporter.forceFlush();
      await pending;
      await exporter.shutdown();
    });

    test('forceFlush after shutdown is a no-op', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
      );
      await exporter.shutdown();
      await exporter.forceFlush();
    });
  });

  group('OtlpHttpMetricExporter lifecycle', () {
    OtlpHttpMetricExporter slowRetryExporter() => OtlpHttpMetricExporter(
          OtlpHttpMetricExporterConfig(
            endpoint: 'http://localhost:$port',
            maxRetries: 5,
            baseDelay: const Duration(milliseconds: 40),
            maxDelay: const Duration(milliseconds: 80),
          ),
        );

    test('shutdown during retry aborts the export', () async {
      statusCodes = [503, 503, 503, 503, 503, 503];
      final exporter = slowRetryExporter();
      final pending =
          exporter.export(metricData()).then((_) {}, onError: (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await exporter.shutdown();
      await pending;
    });

    test('forceFlush waits for a pending export', () async {
      slowMillis = 60;
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );
      final pending = exporter.export(metricData());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await exporter.forceFlush();
      await pending;
      await exporter.shutdown();
    });

    test('flush and export after shutdown', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );
      await exporter.shutdown();
      await exporter.forceFlush();
      await exporter
          .export(metricData())
          .then((v) => expect(v, isFalse), onError: (_) {});
      // Second shutdown is a no-op.
      await exporter.shutdown();
    });
  });

  group('OtlpHttpLogRecordExporter lifecycle', () {
    test('forceFlush waits for a pending export', () async {
      slowMillis = 60;
      final exporter = OtlpHttpLogRecordExporter(
        OtlpHttpLogRecordExporterConfig(endpoint: 'http://localhost:$port'),
      );
      final record = SDKLogRecord(
        instrumentationScope:
            OTel.instrumentationScope(name: 'lifecycle', version: '1.0.0'),
        severityNumber: Severity.INFO,
        body: 'pending',
      );
      final pending = exporter.export([record]);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await exporter.forceFlush();
      await pending;
      await exporter.shutdown();
      await exporter.forceFlush();
    });
  });
}
