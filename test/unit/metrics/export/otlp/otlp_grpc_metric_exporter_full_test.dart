// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/collector/metrics/v1/metrics_service.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Mock gRPC metrics service
// ---------------------------------------------------------------------------

/// A mock MetricsService that records all requests and can optionally fail.
class MockMetricsService extends MetricsServiceBase {
  int exportCount = 0;
  List<ExportMetricsServiceRequest> requests = [];
  int? errorCode;

  @override
  Future<ExportMetricsServiceResponse> export(
    ServiceCall call,
    ExportMetricsServiceRequest request,
  ) async {
    exportCount++;
    requests.add(request);
    if (errorCode != null) {
      throw GrpcError.custom(errorCode!, 'Mock metrics error');
    }
    return ExportMetricsServiceResponse();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a simple MetricData payload for testing.
MetricData _createTestMetricData({String metricName = 'test.counter'}) {
  final now = DateTime.now();
  final point = MetricPoint<int>(
    attributes: OTel.attributes(),
    startTime: now.subtract(const Duration(seconds: 10)),
    endTime: now,
    value: 42,
  );

  final metric = Metric.sum(
    name: metricName,
    description: 'A test counter',
    unit: 'requests',
    points: [point],
  );

  return MetricData(
    resource: OTel.resource(
      OTel.attributesFromMap({'service.name': 'test-service'}),
    ),
    metrics: [metric],
  );
}

OtlpGrpcMetricExporter _createExporter(
  int port, {
  Map<String, String>? headers,
  bool compression = false,
}) {
  return OtlpGrpcMetricExporter(
    OtlpGrpcMetricExporterConfig(
      endpoint: 'http://localhost:$port',
      insecure: true,
      headers: headers,
      compression: compression,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OtlpGrpcMetricExporter full gRPC integration', () {
    late Server grpcServer;
    late int port;
    late MockMetricsService mockService;

    setUp(() async {
      await OTel.reset();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = (_) {};
      OTelLog.exportLogFunction = (_) {};

      mockService = MockMetricsService();
      grpcServer = Server.create(services: [mockService]);
      await grpcServer.serve(port: 0); // random available port
      port = grpcServer.port!;

      await OTel.initialize(
        serviceName: 'test',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await grpcServer.shutdown();
      await OTel.shutdown();
      await OTel.reset();
      OTelLog.logFunction = null;
      OTelLog.exportLogFunction = null;
    });

    // 1
    test('export sends metrics to gRPC endpoint', () async {
      final exporter = _createExporter(port);
      final data = _createTestMetricData();

      final result = await exporter.export(data);

      expect(result, isTrue);
      expect(mockService.exportCount, equals(1));
      expect(mockService.requests, hasLength(1));

      // Verify the request has resource metrics
      final request = mockService.requests.first;
      expect(request.resourceMetrics, isNotEmpty);

      await exporter.shutdown();
    });

    // 2
    test(
      'export with empty metrics returns true without calling server',
      () async {
        final exporter = _createExporter(port);

        final result = await exporter.export(MetricData.empty());

        expect(result, isTrue);
        expect(mockService.exportCount, equals(0));

        await exporter.shutdown();
      },
    );

    // 3
    test('export after shutdown returns false', () async {
      final exporter = _createExporter(port);
      await exporter.shutdown();

      final data = _createTestMetricData();
      final result = await exporter.export(data);

      expect(result, isFalse);
      expect(mockService.exportCount, equals(0));
    });

    // 4
    test('shutdown completes successfully', () async {
      final exporter = _createExporter(port);

      final result = await exporter.shutdown();

      expect(result, isTrue);
    });

    // 5
    test('shutdown is idempotent', () async {
      final exporter = _createExporter(port);

      final result1 = await exporter.shutdown();
      final result2 = await exporter.shutdown();
      final result3 = await exporter.shutdown();

      expect(result1, isTrue);
      expect(result2, isTrue);
      expect(result3, isTrue);
    });

    // 6
    test('forceFlush returns true', () async {
      final exporter = _createExporter(port);

      final result = await exporter.forceFlush();

      expect(result, isTrue);

      await exporter.shutdown();
    });

    // 7
    test('multiple exports reuse channel', () async {
      final exporter = _createExporter(port);

      final data1 = _createTestMetricData(metricName: 'test.counter.1');
      final data2 = _createTestMetricData(metricName: 'test.counter.2');

      final result1 = await exporter.export(data1);
      final result2 = await exporter.export(data2);

      expect(result1, isTrue);
      expect(result2, isTrue);
      expect(mockService.exportCount, equals(2));
      expect(mockService.requests, hasLength(2));

      await exporter.shutdown();
    });

    // 8
    test('debug logging exercises all export paths', () async {
      final logMessages = <String>[];
      OTelLog.exportLogFunction = logMessages.add;
      OTelLog.enableTraceLogging();

      final exporter = _createExporter(port);
      final data = _createTestMetricData();

      await exporter.export(data);

      // Verify that log messages were emitted during export
      expect(logMessages, isNotEmpty);
      expect(
        logMessages.any((msg) => msg.contains('OtlpGrpcMetricExporter')),
        isTrue,
        reason: 'Expected OtlpGrpcMetricExporter log messages',
      );

      await exporter.shutdown();
    });

    // 9
    test('export with null resource uses OTel.resource(null)', () async {
      final exporter = _createExporter(port);
      final now = DateTime.now();
      final point = MetricPoint<int>(
        attributes: OTel.attributes(),
        startTime: now.subtract(const Duration(seconds: 5)),
        endTime: now,
        value: 10,
      );
      final metric = Metric.sum(name: 'test.no-resource', points: [point]);
      // MetricData with null resource
      final data = MetricData(resource: null, metrics: [metric]);

      final result = await exporter.export(data);

      expect(result, isTrue);
      expect(mockService.exportCount, equals(1));

      await exporter.shutdown();
    });

    // 10
    test(
      'export logs each metric detail when export logging enabled',
      () async {
        final logMessages = <String>[];
        OTelLog.exportLogFunction = logMessages.add;
        OTelLog.enableTraceLogging();

        final exporter = _createExporter(port);
        final now = DateTime.now();
        final point = MetricPoint<int>(
          attributes: OTel.attributes(),
          startTime: now.subtract(const Duration(seconds: 5)),
          endTime: now,
          value: 99,
        );
        final metric = Metric.sum(
          name: 'test.detailed',
          description: 'detailed metric',
          unit: 'ops',
          points: [point],
        );
        final data = MetricData(
          resource: OTel.resource(null),
          metrics: [metric],
        );

        await exporter.export(data);

        // Should log individual metric details
        expect(
          logMessages.any((msg) => msg.contains('test.detailed')),
          isTrue,
          reason: 'Expected metric name in log output',
        );

        await exporter.shutdown();
      },
    );

    // 11
    test('export failure returns false', () async {
      // Make the mock service return an error
      mockService.errorCode = StatusCode.internal;

      final exporter = _createExporter(port);
      final data = _createTestMetricData();

      final result = await exporter.export(data);

      expect(result, isFalse);

      await exporter.shutdown();
    });

    // 12
    test('export failure logs error when export logging enabled', () async {
      final logMessages = <String>[];
      OTelLog.exportLogFunction = logMessages.add;
      OTelLog.enableTraceLogging();

      mockService.errorCode = StatusCode.internal;

      final exporter = _createExporter(port);
      final data = _createTestMetricData();

      await exporter.export(data);

      // Should log the failure
      expect(
        logMessages.any((msg) => msg.contains('Export failed')),
        isTrue,
        reason: 'Expected export failure log message',
      );

      await exporter.shutdown();
    });

    // 13
    test('exporter with custom headers', () async {
      final exporter = _createExporter(
        port,
        headers: {
          'x-custom-header': 'custom-value',
          'authorization': 'Bearer test-token',
        },
      );
      final data = _createTestMetricData();

      final result = await exporter.export(data);

      expect(result, isTrue);
      expect(mockService.exportCount, equals(1));

      await exporter.shutdown();
    });

    // 14
    test('exporter with compression enabled', () async {
      final exporter = _createExporter(port, compression: true);
      final data = _createTestMetricData();

      final result = await exporter.export(data);

      expect(result, isTrue);
      expect(mockService.exportCount, equals(1));

      await exporter.shutdown();
    });

    // 15
    test('shutdown logs completion when export logging enabled', () async {
      final logMessages = <String>[];
      OTelLog.exportLogFunction = logMessages.add;
      OTelLog.enableTraceLogging();

      final exporter = _createExporter(port);
      // Export once to ensure channel is created
      await exporter.export(_createTestMetricData());

      await exporter.shutdown();

      expect(
        logMessages.any((msg) => msg.contains('shutdown')),
        isTrue,
        reason: 'Expected shutdown log message',
      );
    });

    // 16
    test('export with multiple metrics in single data', () async {
      final now = DateTime.now();
      final point1 = MetricPoint<int>(
        attributes: OTel.attributes(),
        startTime: now.subtract(const Duration(seconds: 10)),
        endTime: now,
        value: 100,
      );
      final point2 = MetricPoint<double>(
        attributes: OTel.attributes(),
        startTime: now.subtract(const Duration(seconds: 10)),
        endTime: now,
        value: 3.14,
      );
      final metrics = [
        Metric.sum(name: 'test.requests', points: [point1]),
        Metric.gauge(name: 'test.temperature', points: [point2]),
      ];
      final data = MetricData(resource: OTel.resource(null), metrics: metrics);

      final exporter = _createExporter(port);
      final result = await exporter.export(data);

      expect(result, isTrue);
      expect(mockService.exportCount, equals(1));

      await exporter.shutdown();
    });

    // 17
    test('export after shutdown logs cannot-export message', () async {
      final logMessages = <String>[];
      OTelLog.exportLogFunction = logMessages.add;
      OTelLog.enableTraceLogging();

      final exporter = _createExporter(port);
      await exporter.shutdown();

      await exporter.export(_createTestMetricData());

      expect(
        logMessages.any((msg) => msg.contains('Cannot export after shutdown')),
        isTrue,
        reason: 'Expected cannot-export-after-shutdown log message',
      );
    });

    // 18
    test('export empty metrics logs no-metrics message', () async {
      final logMessages = <String>[];
      OTelLog.exportLogFunction = logMessages.add;
      OTelLog.enableTraceLogging();

      final exporter = _createExporter(port);
      await exporter.export(MetricData.empty());

      expect(
        logMessages.any((msg) => msg.contains('No metrics to export')),
        isTrue,
        reason: 'Expected no-metrics-to-export log message',
      );

      await exporter.shutdown();
    });
  });
}
