// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// Integration tests for OTLP exporter environment variable configuration.
///
/// These tests verify that:
/// 1. OTLP headers are properly configured from environment variables
/// 2. Certificate paths are properly configured from environment variables
/// 3. Both trace and metric exporters use the configuration correctly
/// 4. Signal-specific configuration takes precedence over general configuration
void main() {
  group('OTLP Headers and Certificates Integration Tests', () {
    tearDown(() async {
      EnvironmentService.instance.clearTestEnvironment();
      await OTel.reset();
    });

    test('should configure trace exporter with headers from environment',
        () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'header-test-service',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:4317',
        'OTEL_EXPORTER_OTLP_HEADERS':
            'Authorization=Bearer test-token,X-Custom-Header=custom-value',
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
        'OTEL_TRACES_EXPORTER': 'otlp',
      });

      // Initialize OTel - this should configure the exporter with headers
      await OTel.initialize();

      // Verify configuration was read
      final config = OTelEnv.getOtlpConfig(signal: 'traces');
      final headers = config['headers'] as Map<String, String>?;

      expect(headers, isNotNull);
      expect(headers!['Authorization'], equals('Bearer test-token'));
      expect(headers['X-Custom-Header'], equals('custom-value'));

      // Verify tracer provider was created
      final tracerProvider = OTel.tracerProvider();
      expect(tracerProvider, isNotNull);
    });

    test('should configure metric exporter with headers from environment',
        () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'metrics-header-test',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:4318',
        'OTEL_EXPORTER_OTLP_METRICS_HEADERS':
            'X-API-Key=metrics-key,X-Tenant-ID=tenant123',
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'http/protobuf',
        'OTEL_METRICS_EXPORTER': 'otlp',
      });

      await OTel.initialize(enableMetrics: true);

      // Verify configuration was read
      final config = OTelEnv.getOtlpConfig(signal: 'metrics');
      final headers = config['headers'] as Map<String, String>?;

      expect(headers, isNotNull);
      expect(headers!['X-API-Key'], equals('metrics-key'));
      expect(headers['X-Tenant-ID'], equals('tenant123'));

      // Verify meter provider was created
      final meterProvider = OTel.meterProvider();
      expect(meterProvider, isNotNull);
    });

    test('should use signal-specific headers over general headers', () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'signal-specific-test',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:4317',
        'OTEL_EXPORTER_OTLP_HEADERS': 'Authorization=Bearer general-token',
        'OTEL_EXPORTER_OTLP_TRACES_HEADERS':
            'Authorization=Bearer traces-token,X-Trace-ID=123',
        'OTEL_EXPORTER_OTLP_METRICS_HEADERS':
            'Authorization=Bearer metrics-token,X-Metric-Type=gauge',
        'OTEL_TRACES_EXPORTER': 'otlp',
        'OTEL_METRICS_EXPORTER': 'otlp',
      });

      await OTel.initialize(enableMetrics: true);

      // Verify traces config uses signal-specific headers
      final tracesConfig = OTelEnv.getOtlpConfig(signal: 'traces');
      final tracesHeaders = tracesConfig['headers'] as Map<String, String>?;

      expect(tracesHeaders, isNotNull);
      expect(tracesHeaders!['Authorization'], equals('Bearer traces-token'));
      expect(tracesHeaders['X-Trace-ID'], equals('123'));

      // Verify metrics config uses signal-specific headers
      final metricsConfig = OTelEnv.getOtlpConfig(signal: 'metrics');
      final metricsHeaders = metricsConfig['headers'] as Map<String, String>?;

      expect(metricsHeaders, isNotNull);
      expect(metricsHeaders!['Authorization'], equals('Bearer metrics-token'));
      expect(metricsHeaders['X-Metric-Type'], equals('gauge'));
    });

    test('should configure trace exporter with certificates from environment',
        () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'cert-test-service',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://secure-collector:4317',
        'OTEL_EXPORTER_OTLP_CERTIFICATE': 'test://ca.pem',
        'OTEL_EXPORTER_OTLP_CLIENT_KEY': 'test://client.key',
        'OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE': 'test://client.pem',
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
        'OTEL_TRACES_EXPORTER': 'otlp',
      });

      await OTel.initialize();

      // Verify configuration was read
      final config = OTelEnv.getOtlpConfig(signal: 'traces');

      expect(config['certificate'], equals('test://ca.pem'));
      expect(config['clientKey'], equals('test://client.key'));
      expect(config['clientCertificate'], equals('test://client.pem'));
    });

    test('should configure metric exporter with certificates from environment',
        () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'metrics-cert-test',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://metrics-collector:4318',
        'OTEL_EXPORTER_OTLP_METRICS_CERTIFICATE': 'test://metrics-ca.pem',
        'OTEL_EXPORTER_OTLP_METRICS_CLIENT_KEY': 'test://metrics-client.key',
        'OTEL_EXPORTER_OTLP_METRICS_CLIENT_CERTIFICATE':
            'test://metrics-client.pem',
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'http/protobuf',
        'OTEL_METRICS_EXPORTER': 'otlp',
      });

      await OTel.initialize(enableMetrics: true);

      // Verify configuration was read
      final config = OTelEnv.getOtlpConfig(signal: 'metrics');

      expect(config['certificate'], equals('test://metrics-ca.pem'));
      expect(config['clientKey'], equals('test://metrics-client.key'));
      expect(config['clientCertificate'], equals('test://metrics-client.pem'));
    });

    test('should use both headers and certificates together', () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'full-config-test',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://full-collector:4317',
        'OTEL_EXPORTER_OTLP_HEADERS':
            'Authorization=Bearer full-token,X-Tenant=prod',
        'OTEL_EXPORTER_OTLP_CERTIFICATE': 'test://full-ca.pem',
        'OTEL_EXPORTER_OTLP_CLIENT_KEY': 'test://full-client.key',
        'OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE': 'test://full-client.pem',
        'OTEL_EXPORTER_OTLP_COMPRESSION': 'gzip',
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
        'OTEL_TRACES_EXPORTER': 'otlp',
        'OTEL_METRICS_EXPORTER': 'otlp',
      });

      await OTel.initialize(enableMetrics: true);

      // Verify traces configuration
      final tracesConfig = OTelEnv.getOtlpConfig(signal: 'traces');

      expect(tracesConfig['headers'], isNotNull);
      expect((tracesConfig['headers'] as Map<String, String>)['Authorization'],
          equals('Bearer full-token'));
      expect((tracesConfig['headers'] as Map<String, String>)['X-Tenant'],
          equals('prod'));
      expect(tracesConfig['certificate'], equals('test://full-ca.pem'));
      expect(tracesConfig['clientKey'], equals('test://full-client.key'));
      expect(
          tracesConfig['clientCertificate'], equals('test://full-client.pem'));
      expect(tracesConfig['compression'], equals('gzip'));

      // Verify metrics configuration
      final metricsConfig = OTelEnv.getOtlpConfig(signal: 'metrics');

      expect(metricsConfig['headers'], isNotNull);
      expect((metricsConfig['headers'] as Map<String, String>)['Authorization'],
          equals('Bearer full-token'));
      expect((metricsConfig['headers'] as Map<String, String>)['X-Tenant'],
          equals('prod'));
      expect(metricsConfig['certificate'], equals('test://full-ca.pem'));
      expect(metricsConfig['clientKey'], equals('test://full-client.key'));
      expect(
          metricsConfig['clientCertificate'], equals('test://full-client.pem'));
      expect(metricsConfig['compression'], equals('gzip'));
    });

    test('should support Grafana Cloud authentication pattern', () async {
      // Simulate Grafana Cloud configuration
      const instanceId = '123456';
      const apiToken = 'glc_secret_token';
      final credentials = '$instanceId:$apiToken';
      // In a real scenario, this would be base64 encoded
      final authHeader = 'Basic $credentials';

      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'grafana-cloud-service',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_EXPORTER_OTLP_ENDPOINT':
            'https://otlp-gateway-prod-us-central-0.grafana.net/otlp',
        'OTEL_EXPORTER_OTLP_HEADERS': 'Authorization=$authHeader',
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'http/protobuf',
        'OTEL_EXPORTER_OTLP_COMPRESSION': 'gzip',
        'OTEL_TRACES_EXPORTER': 'otlp',
        'OTEL_METRICS_EXPORTER': 'otlp',
      });

      await OTel.initialize(enableMetrics: true);

      // Verify configuration for traces
      final tracesConfig = OTelEnv.getOtlpConfig(signal: 'traces');
      final tracesHeaders = tracesConfig['headers'] as Map<String, String>?;

      expect(tracesHeaders, isNotNull);
      expect(tracesHeaders!['Authorization'], equals(authHeader));
      expect(tracesConfig['compression'], equals('gzip'));
      expect(tracesConfig['protocol'], equals('http/protobuf'));

      // Verify configuration for metrics
      final metricsConfig = OTelEnv.getOtlpConfig(signal: 'metrics');
      final metricsHeaders = metricsConfig['headers'] as Map<String, String>?;

      expect(metricsHeaders, isNotNull);
      expect(metricsHeaders!['Authorization'], equals(authHeader));
      expect(metricsConfig['compression'], equals('gzip'));
      expect(metricsConfig['protocol'], equals('http/protobuf'));
    });

    test('should handle different protocols for different signals', () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'multi-protocol-test',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT': 'http://traces:4317',
        'OTEL_EXPORTER_OTLP_TRACES_PROTOCOL': 'grpc',
        'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT': 'http://metrics:4318',
        'OTEL_EXPORTER_OTLP_METRICS_PROTOCOL': 'http/protobuf',
        'OTEL_TRACES_EXPORTER': 'otlp',
        'OTEL_METRICS_EXPORTER': 'otlp',
      });

      await OTel.initialize(enableMetrics: true);

      // Verify traces use gRPC
      final tracesConfig = OTelEnv.getOtlpConfig(signal: 'traces');
      expect(tracesConfig['protocol'], equals('grpc'));
      expect(tracesConfig['endpoint'], equals('http://traces:4317'));

      // Verify metrics use HTTP
      final metricsConfig = OTelEnv.getOtlpConfig(signal: 'metrics');
      expect(metricsConfig['protocol'], equals('http/protobuf'));
      expect(metricsConfig['endpoint'], equals('http://metrics:4318'));
    });
  });
}
