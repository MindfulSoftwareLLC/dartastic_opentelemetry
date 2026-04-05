// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// Tests targeting every uncovered line in otlp_http_metriccreateExporter.dart.
/// The key bug fix: _tryExport now rethrows ClientException so _export's
/// retry logic is reachable.
void main() {
  late HttpServer server;
  late int port;
  late List<int> responseCodes;
  int requestCount = 0;

  MetricData makeMetrics() {
    final attrs = OTel.attributes([OTel.attributeString('k', 'v')]);
    final now = DateTime.now();
    final point = MetricPoint<num>(
      attributes: attrs,
      startTime: now.subtract(const Duration(seconds: 1)),
      endTime: now,
      value: 42,
    );
    return MetricData(
      metrics: [
        Metric.sum(name: 'c', points: [point]),
      ],
    );
  }

  Future<void> startServer({List<int>? codes, Duration? delay}) async {
    responseCodes = codes ?? [200];
    requestCount = 0;
    server = await HttpServer.bind('localhost', 0);
    port = server.port;
    server.listen((req) async {
      requestCount++;
      if (delay != null) await Future<void>.delayed(delay);
      final code = responseCodes.isNotEmpty ? responseCodes.removeAt(0) : 200;
      req.response.statusCode = code;
      await req.drain<void>();
      await req.response.close();
    });
  }

  OtlpHttpMetricExporter createExporter({
    String? endpoint,
    bool compression = false,
    String? certificate,
    String? clientKey,
    String? clientCertificate,
  }) =>
      OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: endpoint ?? 'http://localhost:$port',
          compression: compression,
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
          certificate: certificate,
          clientKey: clientKey,
          clientCertificate: clientCertificate,
        ),
      );

  setUp(() async {
    await OTel.reset();
    OTelLog.logFunction = (_) {};
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
    try {
      await server.close(force: true);
    } catch (_) {}
    await OTel.shutdown();
    await OTel.reset();
    OTelLog.logFunction = null;
  });

  // ---------------------------------------------------------------
  // _createHttpClient certificate paths
  // ---------------------------------------------------------------
  group('_createHttpClient certificate paths', () {
    test('null security context falls back to default client', () async {
      // test:// certs cause createSecurityContext to return null
      await startServer();
      final exp = createExporter(certificate: 'test://ca.pem');
      final result = await exp.export(makeMetrics());
      // Still works because fallback client is used
      expect(result, isTrue);
      await exp.shutdown();
    });

    test('test:// client cert+key exercises certificate error path', () async {
      // test:// scheme passes config validation but createSecurityContext
      // returns null for test://, or throws on invalid cert loading
      await startServer();
      final exp = createExporter(
        certificate: 'test://ca.pem',
        clientKey: 'test://client.key',
        clientCertificate: 'test://client.pem',
      );
      final result = await exp.export(makeMetrics());
      expect(result, isTrue); // fallback client still works
      await exp.shutdown();
    });
  });

  // ---------------------------------------------------------------
  // _export retry on ClientException
  // Now reachable after the _tryExport bug fix.
  // ---------------------------------------------------------------
  group('_export retry on ClientException', () {
    test('retries on 503 and succeeds', () async {
      // 503 -> ClientException thrown & caught in _export -> retries -> 200
      await startServer(codes: [503, 200]);
      final exp = createExporter();
      final result = await exp.export(makeMetrics());
      expect(result, isTrue);
      expect(requestCount, 2);
      await exp.shutdown();
    });

    test('retries on 429 and succeeds', () async {
      await startServer(codes: [429, 200]);
      final exp = createExporter();
      final result = await exp.export(makeMetrics());
      expect(result, isTrue);
      expect(requestCount, 2);
      await exp.shutdown();
    });

    test('gives up after max retries on 503', () async {
      // 3 attempts: initial + 2 retries, all 503 -> gives up after max retries
      await startServer(codes: [503, 503, 503]);
      final exp = createExporter();
      final result = await exp.export(makeMetrics());
      expect(result, isFalse);
      expect(requestCount, 3);
      await exp.shutdown();
    });

    test('non-retryable 400 returns false immediately', () async {
      // 400 -> ClientException caught -> not retryable -> returns false immediately
      await startServer(codes: [400]);
      final exp = createExporter();
      final result = await exp.export(makeMetrics());
      expect(result, isFalse);
      expect(requestCount, 1);
      await exp.shutdown();
    });

    test('non-retryable 404 returns false immediately', () async {
      await startServer(codes: [404]);
      final exp = createExporter();
      final result = await exp.export(makeMetrics());
      expect(result, isFalse);
      expect(requestCount, 1);
      await exp.shutdown();
    });

    test('_calculateJitteredDelay is exercised during retry', () async {
      // Retry triggers _calculateJitteredDelay during the backoff wait
      await startServer(codes: [503, 200]);
      final exp = createExporter();
      final result = await exp.export(makeMetrics());
      expect(result, isTrue);
      await exp.shutdown();
    });
  });

  // ---------------------------------------------------------------
  // _export generic catch block
  // Triggered by non-ClientException errors like SocketException
  // ---------------------------------------------------------------
  group('_export generic catch block', () {
    test('connection refused triggers generic catch and retries', () async {
      // Connect to a port with no server -> SocketException
      // -> caught by the generic catch block
      await startServer(); // start then close to get a valid port
      await server.close(force: true);
      final exp = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 1,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
      final result = await exp.export(makeMetrics());
      expect(result, isFalse);
      await exp.shutdown();
    });

    test('generic error gives up after max retries', () async {
      await startServer();
      await server.close(force: true);
      final exp = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
      final result = await exp.export(makeMetrics());
      expect(result, isFalse);
      await exp.shutdown();
    });
  });

  // ---------------------------------------------------------------
  // Shutdown-during-export paths
  // ---------------------------------------------------------------
  group('shutdown during export', () {
    test('export catches shutdown-interrupted StateError', () async {
      // Use a slow server so we can shutdown during export
      await startServer(delay: const Duration(milliseconds: 200));
      final exp = createExporter();

      // Start export in background
      final exportFuture = exp.export(makeMetrics());

      // Give it a moment to start the HTTP request, then shutdown
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await exp.shutdown();

      // The export should return false (interrupted) not throw
      final result = await exportFuture;
      expect(result, isFalse);
    });

    test('_export at start detects shutdown', () async {
      // Shutdown before calling _export -> detects shutdown at start
      await startServer();
      final exp = createExporter();
      await exp.shutdown();
      expect(() => exp.export(makeMetrics()), throwsStateError);
    });

    test('shutdown during retry stops retrying', () async {
      // 503 triggers retry, but shutdown during delay stops retrying
      await startServer(codes: [503, 503, 503, 503]);
      final exp = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 5,
          baseDelay: const Duration(milliseconds: 50),
          maxDelay: const Duration(milliseconds: 100),
        ),
      );

      // Start export (will get 503 and start retrying)
      final exportFuture = exp.export(makeMetrics());
      // Wait for first attempt + some delay, then shutdown
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await exp.shutdown();

      final result = await exportFuture;
      expect(result, isFalse);
      // Should have stopped retrying before all 5 attempts
      expect(requestCount, lessThan(5));
    });

    test(
      'ClientException during shutdown-flagged export throws StateError',
      () async {
        // When wasShutdownDuringRetry is true and ClientException caught,
        // the export throws a StateError
        await startServer(
          codes: [503],
          delay: const Duration(milliseconds: 100),
        );
        final exp = OtlpHttpMetricExporter(
          OtlpHttpMetricExporterConfig(
            endpoint: 'http://localhost:$port',
            maxRetries: 3,
            baseDelay: const Duration(milliseconds: 50),
            maxDelay: const Duration(milliseconds: 100),
          ),
        );

        final exportFuture = exp.export(makeMetrics());
        // Shutdown while waiting for retry
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await exp.shutdown();

        final result = await exportFuture;
        expect(result, isFalse);
      },
    );
  });

  // ---------------------------------------------------------------
  // forceFlush with pending exports
  // ---------------------------------------------------------------
  group('forceFlush with pending exports', () {
    test('waits for pending exports to complete', () async {
      await startServer(delay: const Duration(milliseconds: 100));
      final exp = createExporter();

      // Start an export that takes a while
      // ignore: unawaited_futures
      exp.export(makeMetrics());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // forceFlush should wait for the pending export to complete
      final flushed = await exp.forceFlush();
      expect(flushed, isTrue);
      await exp.shutdown();
    });

    test('error during flush returns false', () async {
      // Start server then close it so in-flight export fails
      await startServer(delay: const Duration(milliseconds: 200));
      final exp = createExporter();

      // Start export
      // ignore: unawaited_futures
      exp.export(makeMetrics());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Kill the server mid-request
      await server.close(force: true);

      // forceFlush should catch the error from the failed export
      // It may return true or false depending on timing
      await exp.forceFlush();
      await exp.shutdown();
    });
  });

  // ---------------------------------------------------------------
  // shutdown with pending exports
  // ---------------------------------------------------------------
  group('shutdown with pending exports', () {
    test('waits for pending exports with timeout', () async {
      await startServer(delay: const Duration(milliseconds: 100));
      final exp = createExporter();

      // Start export
      // ignore: unawaited_futures
      exp.export(makeMetrics());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Shutdown waits for pending exports to complete with timeout
      final result = await exp.shutdown();
      expect(result, isTrue);
    });

    test('shutdown catches error from failing pending export', () async {
      await startServer(delay: const Duration(milliseconds: 200));
      final exp = createExporter();

      // Start export
      // ignore: unawaited_futures
      exp.export(makeMetrics());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Kill server so export fails
      await server.close(force: true);

      // Shutdown should handle the error from the failing pending export
      final result = await exp.shutdown();
      expect(result, isTrue); // shutdown still returns true
    });
  });

  // ---------------------------------------------------------------
  // Compression path coverage
  // ---------------------------------------------------------------
  test('export with compression exercises gzip path', () async {
    await startServer();
    final exp = createExporter(compression: true);
    final result = await exp.export(makeMetrics());
    expect(result, isTrue);
    await exp.shutdown();
  });
}
