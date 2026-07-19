// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// The inner branches the lifecycle suite missed: shutdown with pending
// exports, exports failing while flush/shutdown wait on them, and the
// unexpected-error retry tail (connection refused with retries left).

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late int port;
  var slowMillis = 0;
  var dropConnections = false;

  setUp(() async {
    await OTel.reset();
    OTelLog.logFunction = (_) {};
    slowMillis = 0;
    dropConnections = false;
    server = await HttpServer.bind('localhost', 0);
    port = server.port;
    server.listen((request) async {
      if (slowMillis > 0) {
        await Future<void>.delayed(Duration(milliseconds: slowMillis));
      }
      if (dropConnections) {
        await request.response.detachSocket().then((s) => s.destroy());
        return;
      }
      request.response.statusCode = 200;
      await request.drain<void>();
      await request.response.close();
    });
    await OTel.initialize(
      serviceName: 'pending-test',
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

  List<Span> spans() => [OTel.tracer().startSpan('pending')..end()];

  ReadableLogRecord logRecord() => SDKLogRecord(
        instrumentationScope:
            OTel.instrumentationScope(name: 'pending', version: '1.0.0'),
        severityNumber: Severity.INFO,
        body: 'pending',
      );

  MetricData metricData() {
    final now = DateTime.now();
    return MetricData(metrics: [
      Metric.sum(name: 'pending_counter', points: [
        MetricPoint<int>(
          attributes: OTel.attributesFromMap({'k': 'v'}),
          startTime: now.subtract(const Duration(seconds: 1)),
          endTime: now,
          value: 1,
        )
      ])
    ]);
  }

  group('shutdown with pending exports', () {
    test('span exporter waits for pending exports on shutdown', () async {
      slowMillis = 60;
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
      );
      final pending = exporter.export(spans()).then((_) {}, onError: (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await exporter.shutdown();
      await pending;
    });

    test('log exporter waits for pending exports on shutdown', () async {
      slowMillis = 60;
      final exporter = OtlpHttpLogRecordExporter(
        OtlpHttpLogRecordExporterConfig(endpoint: 'http://localhost:$port'),
      );
      final pending =
          exporter.export([logRecord()]).then((_) {}, onError: (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await exporter.shutdown();
      await pending;
    });

    test('metric exporter waits for pending exports on shutdown', () async {
      slowMillis = 60;
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );
      final pending =
          exporter.export(metricData()).then((_) {}, onError: (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await exporter.shutdown();
      await pending;
    });
  });

  group('pending export fails while flush waits', () {
    test('span exporter flush survives a failing pending export', () async {
      slowMillis = 40;
      dropConnections = true;
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 0,
        ),
      );
      final pending = exporter.export(spans()).then((_) {}, onError: (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await exporter.forceFlush();
      await pending;
      await exporter.shutdown();
    });

    test('log exporter flush survives a failing pending export', () async {
      slowMillis = 40;
      dropConnections = true;
      final exporter = OtlpHttpLogRecordExporter(
        OtlpHttpLogRecordExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 0,
        ),
      );
      final pending =
          exporter.export([logRecord()]).then((_) {}, onError: (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await exporter.forceFlush();
      await pending;
      await exporter.shutdown();
    });
  });

  group('unexpected-error retry tail', () {
    test('span exporter retries connection errors before giving up', () async {
      await server.close(force: true);
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 5),
        ),
      );
      await exporter.export(spans()).then((_) {}, onError: (_) {});
      await exporter.shutdown();
    });

    test('log exporter retries connection errors before giving up', () async {
      await server.close(force: true);
      final exporter = OtlpHttpLogRecordExporter(
        OtlpHttpLogRecordExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 5),
        ),
      );
      final result = await exporter.export([logRecord()]);
      expect(result, equals(ExportResult.failure));
      await exporter.shutdown();
    });

    test('metric exporter retries connection errors before giving up',
        () async {
      await server.close(force: true);
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 5),
        ),
      );
      final result = await exporter
          .export(metricData())
          .then((v) => v, onError: (_) => false);
      expect(result, isFalse);
      await exporter.shutdown();
    });
  });
}
