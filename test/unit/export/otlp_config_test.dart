// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/trace/export/otlp/otlp_grpc_span_exporter_config.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpGrpcExporterConfig', () {
    test('provides default values', () {
      final config = OtlpGrpcExporterConfig(endpoint: 'localhost:4317');

      expect(config.endpoint, equals('localhost:4317'));
      expect(config.insecure, isFalse);
      expect(config.timeout, equals(const Duration(seconds: 10)));
      expect(config.maxRetries, equals(3));
      expect(config.baseDelay, equals(const Duration(milliseconds: 100)));
      expect(config.maxDelay, equals(const Duration(seconds: 1)));
      expect(config.headers, isEmpty);
    });

    test('accepts custom values', () {
      final config = OtlpGrpcExporterConfig(
        endpoint: 'custom:1234',
        insecure: true,
        timeout: const Duration(seconds: 5),
        maxRetries: 5,
        baseDelay: const Duration(milliseconds: 500),
        maxDelay: const Duration(seconds: 3),
        headers: {'custom-header': 'value'},
      );

      expect(config.endpoint, equals('custom:1234'));
      expect(config.insecure, isTrue);
      expect(config.timeout, equals(const Duration(seconds: 5)));
      expect(config.maxRetries, equals(5));
      expect(config.baseDelay, equals(const Duration(milliseconds: 500)));
      expect(config.maxDelay, equals(const Duration(seconds: 3)));
      expect(config.headers['custom-header'], equals('value'));
    });

    test('validates endpoint format', () {
      expect(
        () => OtlpGrpcExporterConfig(endpoint: ''),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => OtlpGrpcExporterConfig(endpoint: 'invalid endpoint'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates timeout values', () {
      expect(
        () => OtlpGrpcExporterConfig(
          endpoint: 'localhost:4317',
          timeout: const Duration(microseconds: 1),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => OtlpGrpcExporterConfig(
          endpoint: 'localhost:4317',
          timeout: const Duration(days: 1000),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates retry parameters', () {
      expect(
        () => OtlpGrpcExporterConfig(
          endpoint: 'localhost:4317',
          maxRetries: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => OtlpGrpcExporterConfig(
          endpoint: 'localhost:4317',
          baseDelay: const Duration(microseconds: 1),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => OtlpGrpcExporterConfig(
          endpoint: 'localhost:4317',
          maxDelay: const Duration(microseconds: 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates delay relationship', () {
      expect(
        () => OtlpGrpcExporterConfig(
          endpoint: 'localhost:4317',
          baseDelay: const Duration(seconds: 2),
          maxDelay: const Duration(seconds: 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles header validation', () {
      expect(
        () => OtlpGrpcExporterConfig(
          endpoint: 'localhost:4317',
          headers: {'': 'empty-key'},
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => OtlpGrpcExporterConfig(
          endpoint: 'localhost:4317',
          headers: {'key': ''},
        ),
        throwsA(isA<ArgumentError>()),
      );

      final validHeaders = {
        'authorization': 'Bearer token',
        'custom-header': 'value',
      };
      final config = OtlpGrpcExporterConfig(
        endpoint: 'localhost:4317',
        headers: validHeaders,
      );
      expect(config.headers, equals({
        'authorization': 'Bearer token',
        'custom-header': 'value',
      }));
    });

    test('supports header case insensitivity', () {
      final config = OtlpGrpcExporterConfig(
        endpoint: 'localhost:4317',
        headers: {
          'Authorization': 'Bearer token',
          'custom-HEADER': 'value',
        },
      );

      expect(config.headers['authorization'], equals('Bearer token'));
      expect(config.headers['custom-header'], equals('value'));
    });

    test('handles URL parsing', () {
      var config = OtlpGrpcExporterConfig(endpoint: 'localhost:4317');
      expect(config.endpoint, equals('localhost:4317'));

      config = OtlpGrpcExporterConfig(endpoint: 'http://localhost:4317');
      expect(config.endpoint, equals('http://localhost:4317'));

      config = OtlpGrpcExporterConfig(endpoint: 'https://collector:4317');
      expect(config.endpoint, equals('https://collector:4317'));
      expect(config.insecure, isFalse);

      config = OtlpGrpcExporterConfig(
        endpoint: 'https://collector:4317',
        insecure: true,
      );
      expect(config.endpoint, equals('https://collector:4317'));
      expect(config.insecure, isTrue);
    });

    test('validates URL components', () {
      expect(
        () => OtlpGrpcExporterConfig(endpoint: 'http://'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => OtlpGrpcExporterConfig(endpoint: 'localhost:'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => OtlpGrpcExporterConfig(endpoint: ':4317'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => OtlpGrpcExporterConfig(endpoint: 'http://localhost:port'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles compression configuration', () {
      final config = OtlpGrpcExporterConfig(
        endpoint: 'localhost:4317',
        compression: true,
      );
      expect(config.compression, isTrue);

      final uncompressedConfig = OtlpGrpcExporterConfig(
        endpoint: 'localhost:4317',
        compression: false,
      );
      expect(uncompressedConfig.compression, isFalse);
    });

    test('handles certificate configuration', () {
      expect(
        () => OtlpGrpcExporterConfig(
          endpoint: 'localhost:4317',
          certificate: 'invalid-cert-path',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final config = OtlpGrpcExporterConfig(
        endpoint: 'localhost:4317',
        certificate: 'test://cert',
      );
      expect(config.certificate, equals('test://cert'));
    });

    test('handles client authentication configuration', () {
      final config = OtlpGrpcExporterConfig(
        endpoint: 'localhost:4317',
        clientKey: 'test://key',
        clientCertificate: 'test://cert',
      );

      expect(config.clientKey, equals('test://key'));
      expect(config.clientCertificate, equals('test://cert'));
    });
  });
}
