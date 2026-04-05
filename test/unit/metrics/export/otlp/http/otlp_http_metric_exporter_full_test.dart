// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpHttpMetricExporter full integration', () {
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

    test('export sends metrics to endpoint', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );

      final metricData = createTestMetricData();
      final result = await exporter.export(metricData);

      expect(result, isTrue);
      expect(receivedRequests, hasLength(1));
      await exporter.shutdown();
    });

    test('export sends protobuf content type', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );

      final metricData = createTestMetricData();
      await exporter.export(metricData);

      expect(receivedRequests, hasLength(1));
      expect(
        receivedRequests.first.headers.contentType.toString(),
        contains('application/x-protobuf'),
      );
      await exporter.shutdown();
    });

    test('export appends /v1/metrics to endpoint', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );

      final metricData = createTestMetricData();
      await exporter.export(metricData);

      expect(receivedRequests, hasLength(1));
      expect(receivedRequests.first.uri.path, equals('/v1/metrics'));
      await exporter.shutdown();
    });

    test('export with compression sends gzip content encoding', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          compression: true,
        ),
      );

      final metricData = createTestMetricData();
      await exporter.export(metricData);

      expect(receivedRequests, hasLength(1));
      expect(
        receivedRequests.first.headers.value('content-encoding'),
        equals('gzip'),
      );
      await exporter.shutdown();
    });

    test('export with custom headers includes them', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          headers: {'x-custom': 'test-value'},
        ),
      );

      final metricData = createTestMetricData();
      await exporter.export(metricData);

      expect(receivedRequests, hasLength(1));
      expect(
        receivedRequests.first.headers.value('x-custom'),
        equals('test-value'),
      );
      await exporter.shutdown();
    });

    test('export with empty metrics returns true', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );

      final result = await exporter.export(MetricData.empty());

      expect(result, isTrue);
      // No request should have been sent for empty metrics
      expect(receivedRequests, isEmpty);
      await exporter.shutdown();
    });

    test('export after shutdown throws StateError', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );

      await exporter.shutdown();

      final metricData = createTestMetricData();
      expect(() => exporter.export(metricData), throwsA(isA<StateError>()));
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

      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 10),
          maxDelay: const Duration(milliseconds: 50),
        ),
      );

      final metricData = createTestMetricData();
      final result = await exporter.export(metricData);

      // After the _tryExport fix, ClientException is rethrown, allowing retry.
      // 503 is retryable, so 2 requests: initial 503 + retry 200
      expect(requestCount, equals(2));
      expect(result, isTrue);
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

      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: 'http://localhost:$port',
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 10),
          maxDelay: const Duration(milliseconds: 50),
        ),
      );

      final metricData = createTestMetricData();
      final result = await exporter.export(metricData);

      // 400 is not retryable, single attempt only
      expect(requestCount, equals(1));
      expect(result, isFalse);
      await exporter.shutdown();
    });

    test('forceFlush returns true', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );

      final result = await exporter.forceFlush();
      expect(result, isTrue);
      await exporter.shutdown();
    });

    test('shutdown then export throws', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );

      await exporter.shutdown();

      final metricData = createTestMetricData();
      expect(() => exporter.export(metricData), throwsA(isA<StateError>()));
    });

    test('_getEndpointUrl appends /v1/metrics', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port'),
      );

      final metricData = createTestMetricData();
      await exporter.export(metricData);

      expect(receivedRequests, hasLength(1));
      expect(receivedRequests.first.uri.path, equals('/v1/metrics'));
      await exporter.shutdown();
    });

    test('export with trailing slash endpoint appends /v1/metrics', () async {
      final exporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:$port/'),
      );

      final metricData = createTestMetricData();
      await exporter.export(metricData);

      expect(receivedRequests, hasLength(1));
      expect(receivedRequests.first.uri.path, equals('/v1/metrics'));
      await exporter.shutdown();
    });
  });
}
