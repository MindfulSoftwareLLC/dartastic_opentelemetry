// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Certificate Tests', () {
    tearDown(() async {
      // Reset OTel between tests
      await OTel.reset();
      // Note: Platform.environment is unmodifiable, so we can't clear it
      // The environment variables are set by the shell script and will
      // persist for the duration of the test run
    });

    test('TLS with CA cert', () async {
      // This test expects the collector to be running with TLS
      // The environment variables should be set by the cert_test.sh script

      final endpoint = Platform.environment['OTEL_EXPORTER_OTLP_ENDPOINT'];
      final caCert = Platform.environment['OTEL_EXPORTER_OTLP_CERTIFICATE'];

      expect(endpoint, isNotNull,
          reason: 'OTEL_EXPORTER_OTLP_ENDPOINT must be set');
      expect(caCert, isNotNull,
          reason: 'OTEL_EXPORTER_OTLP_CERTIFICATE must be set');
      expect(endpoint, startsWith('https://'),
          reason: 'Endpoint must use HTTPS for TLS');

      // Verify certificate file exists
      final certFile = File(caCert!);
      expect(certFile.existsSync(), isTrue,
          reason: 'CA certificate file must exist');

      print('Testing TLS with CA certificate: $caCert');
      print('Endpoint: $endpoint');

      // Initialize OTel - it will read from environment variables
      await OTel.initialize(
        serviceName: 'cert-test-tls',
      );

      // Create a span
      final tracer =
          OTel.tracerProvider().getTracer('cert-test', version: '1.0.0');
      await tracer.startActiveSpanAsync(
          name: 'tls-test-span',
          fn: (span) async {
            span.addAttributes(Attributes.of({
              'test.type': 'tls',
              'test.timestamp': DateTime.now().toIso8601String()
            }));
            await Future<void>.delayed(const Duration(milliseconds: 100));
            span.end();
          });

      // Shutdown and flush
      await OTel.shutdown();

      print('✅ TLS test completed successfully');
    }, timeout: const Timeout(Duration(seconds: 30)), skip: true);

    test('mTLS with client cert', () async {
      // This test expects the collector to be running with mTLS enabled
      // The environment variables should be set by the cert_test.sh script

      final endpoint = Platform.environment['OTEL_EXPORTER_OTLP_ENDPOINT'];
      final caCert = Platform.environment['OTEL_EXPORTER_OTLP_CERTIFICATE'];
      final clientCert =
          Platform.environment['OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE'];
      final clientKey = Platform.environment['OTEL_EXPORTER_OTLP_CLIENT_KEY'];

      expect(endpoint, isNotNull,
          reason: 'OTEL_EXPORTER_OTLP_ENDPOINT must be set');
      expect(caCert, isNotNull,
          reason: 'OTEL_EXPORTER_OTLP_CERTIFICATE must be set');
      expect(clientCert, isNotNull,
          reason: 'OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE must be set');
      expect(clientKey, isNotNull,
          reason: 'OTEL_EXPORTER_OTLP_CLIENT_KEY must be set');

      // Verify certificate files exist
      expect(File(caCert!).existsSync(), isTrue,
          reason: 'CA certificate file must exist');
      expect(File(clientCert!).existsSync(), isTrue,
          reason: 'Client certificate file must exist');
      expect(File(clientKey!).existsSync(), isTrue,
          reason: 'Client key file must exist');

      print('Testing mTLS with client certificate');
      print('Endpoint: $endpoint');
      print('CA cert: $caCert');
      print('Client cert: $clientCert');
      print('Client key: $clientKey');

      // Initialize OTel - it will read from environment variables
      await OTel.initialize(
        serviceName: 'cert-test-mtls',
      );

      // Create a span
      final tracer =
          OTel.tracerProvider().getTracer('cert-test', version: '1.0.0');
      await tracer.startActiveSpanAsync(
          name: 'mtls-test-span',
          fn: (span) async {
            span.addAttributes(Attributes.of({
              'test.type': 'mtls',
              'test.timestamp': DateTime.now().toIso8601String()
            }));
            await Future<void>.delayed(const Duration(milliseconds: 100));
            span.end();
          });

      // Shutdown and flush
      await OTel.shutdown();

      print('✅ mTLS test completed successfully');
    }, timeout: const Timeout(Duration(seconds: 30)), skip: true);
  });
}
