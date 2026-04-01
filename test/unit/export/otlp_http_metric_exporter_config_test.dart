// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpHttpMetricExporterConfig', () {
    test('default config creates with expected defaults', () {
      final config = OtlpHttpMetricExporterConfig();

      expect(config.endpoint, equals('http://localhost:4318'));
      expect(config.headers, isEmpty);
      expect(config.timeout, equals(const Duration(seconds: 10)));
      expect(config.compression, isFalse);
      expect(config.maxRetries, equals(3));
      expect(config.baseDelay, equals(const Duration(milliseconds: 100)));
      expect(config.maxDelay, equals(const Duration(seconds: 1)));
      expect(config.certificate, isNull);
      expect(config.clientKey, isNull);
      expect(config.clientCertificate, isNull);
    });

    test('custom endpoint is preserved', () {
      final config = OtlpHttpMetricExporterConfig(
        endpoint: 'http://collector.example.com:4318',
      );
      expect(config.endpoint, equals('http://collector.example.com:4318'));
    });

    test('empty endpoint throws ArgumentError', () {
      expect(
        () => OtlpHttpMetricExporterConfig(endpoint: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('endpoint with spaces throws ArgumentError', () {
      expect(
        () => OtlpHttpMetricExporterConfig(endpoint: 'http://local host:4318'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('endpoint without scheme gets http:// prepended', () {
      final config = OtlpHttpMetricExporterConfig(
        endpoint: 'collector.example.com:4318',
      );
      expect(config.endpoint, equals('http://collector.example.com:4318'));
    });

    test('http://localhost without port gets :4318 appended', () {
      final config = OtlpHttpMetricExporterConfig(
        endpoint: 'http://localhost',
      );
      expect(config.endpoint, equals('http://localhost:4318'));
    });

    test('http://127.0.0.1 without port gets :4318 appended', () {
      final config = OtlpHttpMetricExporterConfig(
        endpoint: 'http://127.0.0.1',
      );
      expect(config.endpoint, equals('http://127.0.0.1:4318'));
    });

    test('https://localhost without port gets :4318 appended', () {
      final config = OtlpHttpMetricExporterConfig(
        endpoint: 'https://localhost',
      );
      expect(config.endpoint, equals('https://localhost:4318'));
    });

    test('custom headers are normalized to lowercase', () {
      final config = OtlpHttpMetricExporterConfig(
        headers: {
          'Content-Type': 'application/json',
          'X-Custom-Header': 'my-value',
          'Authorization': 'Bearer token123',
        },
      );
      expect(config.headers['content-type'], equals('application/json'));
      expect(config.headers['x-custom-header'], equals('my-value'));
      expect(config.headers['authorization'], equals('Bearer token123'));
      expect(config.headers.containsKey('Content-Type'), isFalse);
      expect(config.headers.containsKey('X-Custom-Header'), isFalse);
    });

    test('empty header key throws ArgumentError', () {
      expect(
        () => OtlpHttpMetricExporterConfig(
          headers: {'': 'some-value'},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty header value throws ArgumentError', () {
      expect(
        () => OtlpHttpMetricExporterConfig(
          headers: {'valid-key': ''},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('timeout below 1ms throws ArgumentError', () {
      expect(
        () => OtlpHttpMetricExporterConfig(
          timeout: const Duration(microseconds: 500),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('timeout above 10 minutes throws ArgumentError', () {
      expect(
        () => OtlpHttpMetricExporterConfig(
          timeout: const Duration(minutes: 11),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('valid timeout is accepted', () {
      final config = OtlpHttpMetricExporterConfig(
        timeout: const Duration(seconds: 30),
      );
      expect(config.timeout, equals(const Duration(seconds: 30)));
    });

    test('negative maxRetries throws ArgumentError', () {
      expect(
        () => OtlpHttpMetricExporterConfig(maxRetries: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('zero retries is valid', () {
      final config = OtlpHttpMetricExporterConfig(maxRetries: 0);
      expect(config.maxRetries, equals(0));
    });

    test('baseDelay below 1ms throws ArgumentError', () {
      expect(
        () => OtlpHttpMetricExporterConfig(
          baseDelay: const Duration(microseconds: 100),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('maxDelay above 5 minutes throws ArgumentError', () {
      expect(
        () => OtlpHttpMetricExporterConfig(
          maxDelay: const Duration(minutes: 6),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('baseDelay greater than maxDelay throws ArgumentError', () {
      expect(
        () => OtlpHttpMetricExporterConfig(
          baseDelay: const Duration(seconds: 5),
          maxDelay: const Duration(seconds: 2),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('compression flag is set correctly', () {
      final compressedConfig = OtlpHttpMetricExporterConfig(compression: true);
      expect(compressedConfig.compression, isTrue);

      final uncompressedConfig =
          OtlpHttpMetricExporterConfig(compression: false);
      expect(uncompressedConfig.compression, isFalse);
    });

    test('custom endpoint with port is preserved', () {
      final config = OtlpHttpMetricExporterConfig(
        endpoint: 'http://otel-collector.monitoring.svc:9090',
      );
      expect(
        config.endpoint,
        equals('http://otel-collector.monitoring.svc:9090'),
      );
    });
  });
}
