// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Retry and error handling for OtlpHttpLogRecordExporter, mirroring the
// span exporter's retry suite.

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpHttpLogRecordExporter retry and error handling', () {
    late HttpServer server;
    late int port;
    late List<int> statusCodes;
    var requestCount = 0;
    String? lastAuthHeader;

    setUp(() async {
      await OTel.reset();
      OTelLog.logFunction = (_) {};
      requestCount = 0;
      lastAuthHeader = null;
      statusCodes = [];
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
      server.listen((request) async {
        requestCount++;
        lastAuthHeader = request.headers.value('authorization');
        final code = statusCodes.isNotEmpty ? statusCodes.removeAt(0) : 200;
        request.response.statusCode = code;
        await request.drain<void>();
        await request.response.close();
      });
      await OTel.initialize(
        serviceName: 'log-retry-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );
      // Light up the debug/error log branches; set AFTER initialize since
      // initializeLogging() would override a level set before it.
      OTelLog.enableTraceLogging();
    });

    tearDown(() async {
      await server.close(force: true);
      await OTel.shutdown();
      await OTel.reset();
      OTelLog.logFunction = null;
      OTelLog.currentLevel = LogLevel.info;
    });

    ReadableLogRecord createTestLogRecord() {
      final scope =
          OTel.instrumentationScope(name: 'retry-test', version: '1.0.0');
      return SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'retry-me',
      );
    }

    OtlpHttpLogRecordExporter createExporter({
      int maxRetries = 2,
      bool compression = false,
      Map<String, String>? headers,
    }) {
      return OtlpHttpLogRecordExporter(
        OtlpHttpLogRecordExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: maxRetries,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
          compression: compression,
          headers: headers,
        ),
      );
    }

    test('succeeds on first try', () async {
      final exporter = createExporter();
      final result = await exporter.export([createTestLogRecord()]);
      expect(result, equals(ExportResult.success));
      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('retries on 503 and 429 then succeeds', () async {
      statusCodes = [503, 429, 200];
      final exporter = createExporter(maxRetries: 3);
      final result = await exporter.export([createTestLogRecord()]);
      expect(result, equals(ExportResult.success));
      expect(requestCount, equals(3));
      await exporter.shutdown();
    });

    test('does not retry a non-retryable 400', () async {
      statusCodes = [400, 200];
      final exporter = createExporter();
      final result = await exporter.export([createTestLogRecord()]);
      expect(result, equals(ExportResult.failure));
      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('gives up after max retries of 503', () async {
      statusCodes = [503, 503, 503, 503];
      final exporter = createExporter(maxRetries: 2);
      final result = await exporter.export([createTestLogRecord()]);
      expect(result, equals(ExportResult.failure));
      await exporter.shutdown();
    });

    test('connection refused takes the unexpected-error retry path', () async {
      await server.close(force: true);
      final exporter = createExporter(maxRetries: 2);
      final result = await exporter.export([createTestLogRecord()]);
      expect(result, equals(ExportResult.failure));
      await exporter.shutdown();
    });

    test('gzip compression and authorization redaction', () async {
      final exporter = createExporter(
        compression: true,
        headers: {'authorization': 'Bearer secret-token'},
      );
      final result = await exporter.export([createTestLogRecord()]);
      expect(result, equals(ExportResult.success));
      expect(lastAuthHeader, equals('Bearer secret-token'));
      await exporter.shutdown();
    });

    test('export after shutdown fails fast', () async {
      final exporter = createExporter();
      await exporter.shutdown();
      final result = await exporter.export([createTestLogRecord()]);
      expect(result, equals(ExportResult.failure));
      expect(requestCount, equals(0));
    });

    test('empty batch succeeds without a request', () async {
      final exporter = createExporter();
      final result = await exporter.export([]);
      expect(result, equals(ExportResult.success));
      expect(requestCount, equals(0));
      await exporter.forceFlush();
      await exporter.shutdown();
      // Second shutdown is a no-op.
      await exporter.shutdown();
    });
  });
}
