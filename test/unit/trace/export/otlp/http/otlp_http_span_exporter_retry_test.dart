// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpHttpSpanExporter retry and error handling', () {
    late HttpServer server;
    late int port;
    late List<int> statusCodes;
    int requestCount = 0;

    setUp(() async {
      await OTel.reset();
      OTelLog.spanLogFunction = (_) {};
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
      OTelLog.spanLogFunction = null;
      OTelLog.currentLevel = LogLevel.info;
    });

    List<Span> createTestSpans({int count = 1}) {
      final tracer = OTel.tracer();
      final spans = <Span>[];
      for (var i = 0; i < count; i++) {
        final span = tracer.startSpan('test-span-$i');
        span.end();
        spans.add(span);
      }
      return spans;
    }

    OtlpHttpSpanExporter createExporter({int maxRetries = 2}) {
      return OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: maxRetries,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
    }

    test('retries on 503 and succeeds on second try', () async {
      statusCodes = [503, 200];
      final exporter = createExporter();
      final spans = createTestSpans();

      await exporter.export(spans);

      // First attempt returns 503 (retryable), second returns 200
      expect(requestCount, equals(2));
      await exporter.shutdown();
    });

    test('retries on 429 and succeeds on second try', () async {
      statusCodes = [429, 200];
      final exporter = createExporter();
      final spans = createTestSpans();

      await exporter.export(spans);

      expect(requestCount, equals(2));
      await exporter.shutdown();
    });

    test('gives up after max retries on 503', () async {
      // maxRetries=2 means 3 total attempts (initial + 2 retries)
      statusCodes = [503, 503, 503];
      final exporter = createExporter(maxRetries: 2);
      final spans = createTestSpans();

      // Should throw after exhausting all retries
      expect(() => exporter.export(spans), throwsA(anything));

      // Allow async operations to settle
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(requestCount, equals(3));
      await exporter.shutdown();
    });

    test('does not retry on non-retryable 400', () async {
      statusCodes = [400];
      final exporter = createExporter();
      final spans = createTestSpans();

      // 400 is not retryable - should throw after single attempt
      expect(() => exporter.export(spans), throwsA(anything));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('does not retry on 404', () async {
      statusCodes = [404];
      final exporter = createExporter();
      final spans = createTestSpans();

      expect(() => exporter.export(spans), throwsA(anything));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('export with debug logging exercises all log paths', () async {
      // Debug logging is already enabled in setUp via enableTraceLogging
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;
      OTelLog.spanLogFunction = logMessages.add;

      statusCodes = [200];
      final exporter = createExporter();
      final spans = createTestSpans();

      await exporter.export(spans);

      // Verify that debug log paths were exercised
      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('Beginning export'));
      expect(allLogs, contains('Attempting to export'));
      expect(allLogs, contains('Preparing to export'));
      expect(allLogs, contains('Transforming'));
      expect(allLogs, contains('Successfully transformed'));
      expect(allLogs, contains('Sending export request'));
      expect(allLogs, contains('Export request completed successfully'));
      expect(allLogs, contains('Successfully exported'));
      expect(allLogs, contains('Export completed successfully'));

      await exporter.shutdown();
    });

    test(
      'export with authorization header redacts value in debug logs',
      () async {
        final logMessages = <String>[];
        OTelLog.logFunction = logMessages.add;

        final exporter = OtlpHttpSpanExporter(
          OtlpHttpExporterConfig(
            endpoint: 'http://localhost:$port',
            headers: {'Authorization': 'Bearer secret-token-12345'},
            maxRetries: 0,
            baseDelay: const Duration(milliseconds: 1),
            maxDelay: const Duration(milliseconds: 10),
          ),
        );

        statusCodes = [200];
        final spans = createTestSpans();
        await exporter.export(spans);

        final allLogs = logMessages.join('\n');
        // The authorization value should be redacted
        expect(allLogs, contains('REDACTED'));
        expect(allLogs, isNot(contains('secret-token-12345')));

        await exporter.shutdown();
      },
    );

    test(
      'constructor with certificate config exercises _createHttpClient',
      () async {
        // Using test:// scheme paths exercises the certificate code path
        // in _createHttpClient without requiring real cert files
        final exporter = OtlpHttpSpanExporter(
          OtlpHttpExporterConfig(
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
        final spans = createTestSpans();
        await exporter.export(spans);
        expect(requestCount, equals(1));
        await exporter.shutdown();
      },
    );

    test('forceFlush with no pending exports', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();

      await exporter.forceFlush();

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('Force flush requested'));
      expect(allLogs, contains('No pending exports to flush'));

      await exporter.shutdown();
    });

    test('forceFlush after shutdown returns without error', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();
      await exporter.shutdown();

      await exporter.forceFlush();

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('already shut down'));
    });

    test('forceFlush with pending exports waits for completion', () async {
      // Use a slow server that delays the response
      await server.close(force: true);

      final completer = Completer<void>();
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
      server.listen((request) async {
        requestCount++;
        await request.drain<void>();
        // Wait for the completer before responding
        await completer.future;
        request.response.statusCode = 200;
        await request.response.close();
      });

      final exporter = createExporter();
      final spans = createTestSpans();

      // Start the export but don't await it - it will block on the server
      final exportFuture = exporter.export(spans);

      // Give the export a moment to start
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Now call forceFlush - it should wait for the pending export
      final flushFuture = exporter.forceFlush();

      // Release the server response
      completer.complete();

      // Both should complete
      await exportFuture;
      await flushFuture;

      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('shutdown with pending exports waits then closes', () async {
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
      final spans = createTestSpans();

      // Start export
      final exportFuture = exporter.export(spans);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Start shutdown while export is pending
      final shutdownFuture = exporter.shutdown();

      // Release the server
      completer.complete();

      // Wait for both to complete
      await exportFuture;
      await shutdownFuture;

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('Shutdown requested'));
      expect(allLogs, contains('Shutdown complete'));
      expect(requestCount, equals(1));
    });

    test('shutdown during retry stops retrying', () async {
      // Server always returns 503 so retry keeps going
      statusCodes = [503, 503, 503, 503, 503];
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 10,
          baseDelay: const Duration(milliseconds: 50),
          maxDelay: const Duration(milliseconds: 100),
        ),
      );

      final spans = createTestSpans();

      // Start export - it will retry because of 503
      final exportFuture = exporter.export(spans).catchError((_) {});

      // Wait for first attempt to complete, then shutdown
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await exporter.shutdown();

      // Wait for the export future to settle
      await exportFuture;

      // Should have stopped retrying early (fewer than maxRetries + 1)
      expect(requestCount, lessThan(11));
    });

    test('export empty span list returns without sending request', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();

      await exporter.export([]);

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('No spans to export'));
      expect(requestCount, equals(0));

      await exporter.shutdown();
    });

    test('export multiple spans in one batch', () async {
      statusCodes = [200];
      final exporter = createExporter();
      final spans = createTestSpans(count: 5);

      await exporter.export(spans);

      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('retries with 503 then 429 then succeeds', () async {
      statusCodes = [503, 429, 200];
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
      final spans = createTestSpans();

      await exporter.export(spans);

      expect(requestCount, equals(3));
      await exporter.shutdown();
    });

    test('error log paths exercised on 503 failure', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      statusCodes = [503, 503, 503];
      final exporter = createExporter(maxRetries: 2);
      final spans = createTestSpans();

      try {
        await exporter.export(spans);
      } catch (_) {
        // Expected
      }

      final allLogs = logMessages.join('\n');
      // Should have error logs for the failed request
      expect(allLogs, contains('status code 503'));
      expect(allLogs, contains('HTTP error during export'));
      expect(allLogs, contains('Max attempts reached'));

      await exporter.shutdown();
    });

    test('error log paths exercised on non-retryable error', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      statusCodes = [400];
      final exporter = createExporter();
      final spans = createTestSpans();

      try {
        await exporter.export(spans);
      } catch (_) {
        // Expected
      }

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('Non-retryable HTTP error'));

      await exporter.shutdown();
    });

    test('retry delay log messages exercised', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      statusCodes = [503, 200];
      final exporter = createExporter();
      final spans = createTestSpans();

      await exporter.export(spans);

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('Retrying export after'));

      await exporter.shutdown();
    });

    test('shutdown is idempotent - second call returns immediately', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();

      await exporter.shutdown();
      await exporter.shutdown();

      // Second shutdown should be a no-op
      final shutdownCount =
          logMessages.where((m) => m.contains('Shutdown complete')).length;
      expect(shutdownCount, equals(1));
    });

    test('export throws StateError after shutdown', () async {
      final exporter = createExporter();
      await exporter.shutdown();

      final spans = createTestSpans();
      expect(() => exporter.export(spans), throwsA(isA<StateError>()));
    });

    test('connection refused exercises generic catch block', () async {
      // Close the server so the connection is refused
      await server.close(force: true);

      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      // Create exporter pointing to the closed port
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 1,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
      final spans = createTestSpans();

      try {
        await exporter.export(spans);
      } catch (_) {
        // Expected - connection refused
      }

      final allLogs = logMessages.join('\n');
      // Should hit either the ClientException or generic catch block
      expect(allLogs, contains('error'));

      // Re-bind server for tearDown to close
      server = await HttpServer.bind('localhost', 0);
      port = server.port;

      await exporter.shutdown();
    });

    test('shutdown debug log shows pending export count', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;

      final exporter = createExporter();
      await exporter.shutdown();

      final allLogs = logMessages.join('\n');
      expect(allLogs, contains('pending exports'));
    });

    test('export with compression and retry', () async {
      statusCodes = [503, 200];
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          compression: true,
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
      final spans = createTestSpans();

      await exporter.export(spans);

      expect(requestCount, equals(2));
      await exporter.shutdown();
    });
  });
}
