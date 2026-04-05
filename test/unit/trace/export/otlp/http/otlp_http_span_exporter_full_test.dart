// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpHttpSpanExporter full integration', () {
    late HttpServer server;
    late int port;
    late List<HttpRequest> receivedRequests;

    setUp(() async {
      await OTel.reset();
      receivedRequests = [];
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
      server.listen((request) async {
        receivedRequests.add(request);
        // Drain the request body so the connection completes properly
        await request.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        );
        request.response.statusCode = 200;
        await request.response.close();
      });
      await OTel.initialize(
        serviceName: 'test',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await server.close(force: true);
      await OTel.shutdown();
      await OTel.reset();
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

    test('export sends spans to endpoint', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
      );

      final spans = createTestSpans();
      await exporter.export(spans);

      expect(receivedRequests, hasLength(1));
      await exporter.shutdown();
    });

    test('export sends protobuf content type', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
      );

      final spans = createTestSpans();
      await exporter.export(spans);

      expect(receivedRequests, hasLength(1));
      expect(
        receivedRequests.first.headers.contentType.toString(),
        contains('application/x-protobuf'),
      );
      await exporter.shutdown();
    });

    test('export appends /v1/traces to endpoint', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
      );

      final spans = createTestSpans();
      await exporter.export(spans);

      expect(receivedRequests, hasLength(1));
      expect(receivedRequests.first.uri.path, equals('/v1/traces'));
      await exporter.shutdown();
    });

    test('export with compression sends gzip content encoding', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          compression: true,
        ),
      );

      final spans = createTestSpans();
      await exporter.export(spans);

      expect(receivedRequests, hasLength(1));
      expect(
        receivedRequests.first.headers.value('content-encoding'),
        equals('gzip'),
      );
      await exporter.shutdown();
    });

    test('export with custom headers includes them', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          headers: {'x-custom': 'test-value'},
        ),
      );

      final spans = createTestSpans();
      await exporter.export(spans);

      expect(receivedRequests, hasLength(1));
      expect(
        receivedRequests.first.headers.value('x-custom'),
        equals('test-value'),
      );
      await exporter.shutdown();
    });

    test('export with empty spans does nothing', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
      );

      await exporter.export([]);

      // No request should have been sent
      expect(receivedRequests, isEmpty);
      await exporter.shutdown();
    });

    test('export after shutdown throws StateError', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
      );

      await exporter.shutdown();

      final spans = createTestSpans();
      expect(() => exporter.export(spans), throwsA(isA<StateError>()));
    });

    test('export retries on 503', () async {
      // Close the default server and create one that returns 503 first
      await server.close(force: true);

      int requestCount = 0;
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
      server.listen((request) async {
        requestCount++;
        await request.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        );
        if (requestCount == 1) {
          request.response.statusCode = 503;
        } else {
          request.response.statusCode = 200;
        }
        await request.response.close();
      });

      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 10),
          maxDelay: const Duration(milliseconds: 50),
        ),
      );

      final spans = createTestSpans();
      await exporter.export(spans);

      // Should have retried: first attempt (503) + second attempt (200)
      expect(requestCount, equals(2));
      await exporter.shutdown();
    });

    test('export retries on 429', () async {
      await server.close(force: true);

      int requestCount = 0;
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
      server.listen((request) async {
        requestCount++;
        await request.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        );
        if (requestCount == 1) {
          request.response.statusCode = 429;
        } else {
          request.response.statusCode = 200;
        }
        await request.response.close();
      });

      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 10),
          maxDelay: const Duration(milliseconds: 50),
        ),
      );

      final spans = createTestSpans();
      await exporter.export(spans);

      expect(requestCount, equals(2));
      await exporter.shutdown();
    });

    test('export does not retry on 400', () async {
      await server.close(force: true);

      int requestCount = 0;
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
      server.listen((request) async {
        requestCount++;
        await request.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        );
        request.response.statusCode = 400;
        await request.response.close();
      });

      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 10),
          maxDelay: const Duration(milliseconds: 50),
        ),
      );

      final spans = createTestSpans();
      // 400 is not retryable, so this should throw after a single attempt
      expect(() => exporter.export(spans), throwsA(anything));

      // Allow the async operations to settle
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(requestCount, equals(1));
      await exporter.shutdown();
    });

    test('forceFlush completes successfully', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
      );

      // forceFlush should complete without error
      await exporter.forceFlush();
      await exporter.shutdown();
    });

    test('shutdown then export throws', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
      );

      await exporter.shutdown();

      final spans = createTestSpans();
      expect(() => exporter.export(spans), throwsA(isA<StateError>()));
    });

    test(
      '_getEndpointUrl appends /v1/traces to endpoint without path',
      () async {
        final exporter = OtlpHttpSpanExporter(
          OtlpHttpExporterConfig(endpoint: 'http://localhost:$port'),
        );

        final spans = createTestSpans();
        await exporter.export(spans);

        expect(receivedRequests, hasLength(1));
        expect(receivedRequests.first.uri.path, equals('/v1/traces'));
        await exporter.shutdown();
      },
    );

    test('_getEndpointUrl preserves existing /v1/traces', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port/v1/traces'),
      );

      final spans = createTestSpans();
      await exporter.export(spans);

      expect(receivedRequests, hasLength(1));
      // Should not double-append
      expect(receivedRequests.first.uri.path, equals('/v1/traces'));
      await exporter.shutdown();
    });

    test('export with trailing slash endpoint appends /v1/traces', () async {
      final exporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:$port/'),
      );

      final spans = createTestSpans();
      await exporter.export(spans);

      expect(receivedRequests, hasLength(1));
      expect(receivedRequests.first.uri.path, equals('/v1/traces'));
      await exporter.shutdown();
    });
  });
}
