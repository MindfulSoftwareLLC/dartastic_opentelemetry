// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpGrpcMetricExporterConfig Tests', () {
    setUp(() async {
      await OTel.reset();
      // Initialize OTel with the metric reader
      await OTel.initialize(
        serviceName: 'otl[-grpc-metric-exporter-test',
        detectPlatformResources: false,
      );
    });
    test('constructor sets values correctly', () {
      // Test with just required parameters
      final config1 = OtlpGrpcMetricExporterConfig(
        endpoint: 'http://localhost:4317',
      );

      expect(config1.endpoint, equals('http://localhost:4317'));
      expect(config1.insecure, equals(false));
      expect(config1.headers, isNull);
      expect(config1.timeoutMillis, equals(10000));

      // Test with all parameters
      final headers = {'api-key': 'test-key', 'custom-header': 'value'};
      final config2 = OtlpGrpcMetricExporterConfig(
        endpoint: 'https://example.com:4317',
        insecure: true,
        headers: headers,
        timeoutMillis: 5000,
      );

      expect(config2.endpoint, equals('https://example.com:4317'));
      expect(config2.insecure, equals(true));
      expect(config2.headers, equals(headers));
      expect(config2.timeoutMillis, equals(5000));
    });

    test('different timeout values are respected', () {
      final config1 = OtlpGrpcMetricExporterConfig(
        endpoint: 'http://localhost:4317',
        timeoutMillis: 1000,
      );

      final config2 = OtlpGrpcMetricExporterConfig(
        endpoint: 'http://localhost:4317',
        timeoutMillis: 30000,
      );

      expect(config1.timeoutMillis, equals(1000));
      expect(config2.timeoutMillis, equals(30000));
    });
  });
}
