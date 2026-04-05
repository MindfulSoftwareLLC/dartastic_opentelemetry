// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpHttpMetricExporter retry and error handling', () {
    late HttpServer server;
    late int port;
    late List<int> statusCodes;
    int requestCount = 0;

    setUp(() async {
      await OTel.reset();
      OTelLog.metricLogFunction = (_) {};
      OTelLog.logFunction = (_) {};
      requestCount = 0;
      statusCodes = [];
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
      server.listen((request) async {
        requestCount++;
        final code = statusCodes.isNotEmpty ? statusCodes.removeAt(0) : 200;
        request.response.statusCode = code;
        await request.drain<void>();
        await request.response.close();
      });
      await OTel.initialize(
        serviceName: 'test',
        detectPlatformResources: false,
        enableLogs: false,
      );
      // Set trace logging AFTER initialize, since initializeLogging() reads
      // OTEL_LOG_LEVEL from env and would override a level set before it.
      OTelLog.enableTraceLogging();
    });

    tearDown(() async {
      await server.close(force: true);
      await OTel.shutdown();
      await OTel.reset();
      OTelLog.logFunction = null;
      OTelLog.metricLogFunction = null;
      OTelLog.currentLevel = LogLevel.info;
    });

    MetricData createTestMetricData() {
      final attrs = OTel.attributes([OTel.attributeString('key', 'value')]);
      final now = DateTime.now();
      final point = MetricPoint<num>(
        attributes: attrs,
        startTime: now.subtract(const Duration(seconds: 1)),
        endTime: now,
        value: 42,
      );
      final metric = Metric.sum(name: 'test_counter', points: [point]);
      return MetricData(metrics: [metric]);
    }

    OtlpHttpMetricExporter createExporter({int maxRetries = 2}) {
      return OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: maxRetries,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
    }

    test('export with debug logging exercises all log paths', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;
      OTelLog.metricLogFunction = logMessages.add;

      statusCodes = [200];
      final exporter = createExporter();
      final metricData = createTestMetricData();

      final result = await exporter.export(metricData);
      expect(result, isTrue);

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('Beginning export'));
      expect(allLogs, contains('Attempting to export'));
      expect(allLogs, contains('Preparing to export'));
      expect(allLogs, contains('Transforming metrics'));
      expect(allLogs, contains('Successfully transformed metrics'));
      expect(allLogs, contains('Sending export request'));
      expect(allLogs, contains('Export request completed successfully'));
      expect(allLogs, contains('Successfully exported metrics'));
      expect(allLogs, contains('Export completed successfully'));

      await exporter.shutdown();
    });

    test('export successful with metrics returns true', () async {
      statusCodes = [200];
      final exporter = createExporter();
      final metricData = createTestMetricData();

      final result = await exporter.export(metricData);

      expect(result, isTrue);
      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('export with empty metrics returns true without sending', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();
      final result = await exporter.export(MetricData.empty());

      expect(result, isTrue);
      expect(requestCount, equals(0));

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('No metrics to export'));

      await exporter.shutdown();
    });

    test(
      'constructor with certificate config exercises _createHttpClient',
      () async {
        // Using test:// scheme paths exercises the certificate code path
        // in _createHttpClient without requiring real cert files
        final exporter = OtlpHttpMetricExporter(
          OtlpHttpMetricExporterConfig(
            endpoint: 'http://localhost:$port',
            certificate: 'test://ca-cert',
            clientKey: 'test://client-key',
            clientCertificate: 'test://client-cert',
            maxRetries: 0,
            baseDelay: const Duration(milliseconds: 1),
            maxDelay: const Duration(milliseconds: 10),
          ),
        );
        expect(exporter, isNotNull);

        // It should still work with the test:// certificate client
        statusCodes = [200];
        final metricData = createTestMetricData();
        final result = await exporter.export(metricData);
        expect(result, isTrue);
        expect(requestCount, equals(1));
        await exporter.shutdown();
      },
    );

    test('retries on 503 and gives up after max retries', () async {
      // After the _tryExport fix, ClientException is rethrown,
      // allowing _export's retry logic to trigger on 503.
      statusCodes = [503, 503, 503];
      final exporter = createExporter(maxRetries: 2);
      final metricData = createTestMetricData();

      final result = await exporter.export(metricData);

      // 3 attempts (initial + 2 retries), all fail
      expect(result, isFalse);
      expect(requestCount, equals(3));
      await exporter.shutdown();
    });

    test('export returns false on non-retryable 400', () async {
      statusCodes = [400];
      final exporter = createExporter();
      final metricData = createTestMetricData();

      final result = await exporter.export(metricData);

      // _tryExport catches the ClientException and returns false
      expect(result, isFalse);
      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('export returns false on 404', () async {
      statusCodes = [404];
      final exporter = createExporter();
      final metricData = createTestMetricData();

      final result = await exporter.export(metricData);

      expect(result, isFalse);
      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('forceFlush with no pending exports returns true', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();
      final result = await exporter.forceFlush();

      expect(result, isTrue);

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('Force flush requested'));
      expect(allLogs, contains('No pending exports to flush'));

      await exporter.shutdown();
    });

    test('forceFlush after shutdown returns true', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();
      await exporter.shutdown();

      final result = await exporter.forceFlush();
      expect(result, isTrue);

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('already shut down'));
    });

    test('forceFlush with pending exports waits for completion', () async {
      await server.close(force: true);

      final completer = Completer<void>();
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
      server.listen((request) async {
        requestCount++;
        await request.drain<void>();
        await completer.future;
        request.response.statusCode = 200;
        await request.response.close();
      });

      final exporter = createExporter();
      final metricData = createTestMetricData();

      // Start export but don't await - it will block on the server
      final exportFuture = exporter.export(metricData);

      // Give the export a moment to start
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // forceFlush should wait for pending exports
      final flushFuture = exporter.forceFlush();

      // Release the server response
      completer.complete();

      // Both should complete
      await exportFuture;
      final flushResult = await flushFuture;
      expect(flushResult, isTrue);

      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('shutdown with pending exports and timeout', () async {
      await server.close(force: true);

      final completer = Completer<void>();
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
      server.listen((request) async {
        requestCount++;
        await request.drain<void>();
        await completer.future;
        request.response.statusCode = 200;
        await request.response.close();
      });

      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();
      final metricData = createTestMetricData();

      // Start export
      final exportFuture = exporter.export(metricData);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Start shutdown while export is pending
      final shutdownFuture = exporter.shutdown();

      // Release the server
      completer.complete();

      // Wait for both to complete
      await exportFuture;
      final shutdownResult = await shutdownFuture;
      expect(shutdownResult, isTrue);

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('Shutdown requested'));
      expect(allLogs, contains('Shutdown complete'));
      expect(requestCount, equals(1));
    });

    test('export catches generic exceptions from connection refused', () async {
      // Close the server so the connection is refused
      await server.close(force: true);

      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 0,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
      final metricData = createTestMetricData();

      final result = await exporter.export(metricData);

      // Connection refused results in false (either via _tryExport catch or _export catch)
      expect(result, isFalse);

      // Re-bind server for tearDown
      server = await HttpServer.bind('localhost', 0);
      port = server.port;

      await exporter.shutdown();
    });

    test('shutdown is idempotent - second call returns true', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();

      final result1 = await exporter.shutdown();
      final result2 = await exporter.shutdown();

      expect(result1, isTrue);
      expect(result2, isTrue);

      // Shutdown complete should only appear once
      final shutdownCount =
          logMessages.where((m) => m.contains('Shutdown complete')).length;
      expect(shutdownCount, equals(1));
    });

    test('export throws StateError after shutdown', () async {
      final exporter = createExporter();
      await exporter.shutdown();

      final metricData = createTestMetricData();
      expect(() => exporter.export(metricData), throwsA(isA<StateError>()));
    });

    test('shutdown debug log shows pending export count', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();
      await exporter.shutdown();

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('pending exports'));
    });

    test('export with compression succeeds', () async {
      statusCodes = [200];
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          compression: true,
          maxRetries: 0,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
      final metricData = createTestMetricData();

      final result = await exporter.export(metricData);
      expect(result, isTrue);
      expect(requestCount, equals(1));

      await exporter.shutdown();
    });

    test('export with resource in metric data', () async {
      statusCodes = [200];
      final exporter = createExporter();
      final attrs = OTel.attributes([OTel.attributeString('key', 'value')]);
      final now = DateTime.now();
      final point = MetricPoint<num>(
        attributes: attrs,
        startTime: now.subtract(const Duration(seconds: 1)),
        endTime: now,
        value: 42,
      );
      final metric = Metric.sum(name: 'test_counter', points: [point]);
      final metricData = MetricData(
        metrics: [metric],
        resource: OTel.resource(null),
      );

      final result = await exporter.export(metricData);
      expect(result, isTrue);

      await exporter.shutdown();
    });

    test('error log paths exercised on 503', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      statusCodes = [503];
      final exporter = createExporter(maxRetries: 0);
      final metricData = createTestMetricData();

      final result = await exporter.export(metricData);
      expect(result, isFalse);

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('status code 503'));
      expect(allLogs, contains('Export request failed'));

      await exporter.shutdown();
    });

    test('export with multiple metrics in batch', () async {
      statusCodes = [200];
      final exporter = createExporter();
      final attrs = OTel.attributes([OTel.attributeString('key', 'value')]);
      final now = DateTime.now();

      final metrics = <Metric>[];
      for (var i = 0; i < 5; i++) {
        final point = MetricPoint<num>(
          attributes: attrs,
          startTime: now.subtract(const Duration(seconds: 1)),
          endTime: now,
          value: i * 10,
        );
        metrics.add(Metric.sum(name: 'counter_$i', points: [point]));
      }
      final metricData = MetricData(metrics: metrics);

      final result = await exporter.export(metricData);
      expect(result, isTrue);
      expect(requestCount, equals(1));

      await exporter.shutdown();
    });

    test('endpoint url with trailing slash', () async {
      statusCodes = [200];
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port/',
          maxRetries: 0,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
      final metricData = createTestMetricData();

      final result = await exporter.export(metricData);
      expect(result, isTrue);

      await exporter.shutdown();
    });

    test('endpoint url already has /v1/metrics', () async {
      statusCodes = [200];
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port/v1/metrics',
          maxRetries: 0,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
      final metricData = createTestMetricData();

      final result = await exporter.export(metricData);
      expect(result, isTrue);

      await exporter.shutdown();
    });

    test('metric logging is exercised when metricLogFunction is set', () async {
      final metricLogs = <String>[];
      OTelLog.metricLogFunction = metricLogs.add;

      statusCodes = [200];
      final exporter = createExporter();
      final metricData = createTestMetricData();

      await exporter.export(metricData);

      final allMetricLogs = metricLogs.join('\n');
      expect(allMetricLogs, contains('Exporting metrics via HTTP'));

      await exporter.shutdown();
    });
  });
}
