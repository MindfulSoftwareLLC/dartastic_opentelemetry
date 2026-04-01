// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpGrpcExporterConfig', () {
    group('default values', () {
      test('default config has expected values', () {
        final config = OtlpGrpcExporterConfig();

        // Default endpoint is localhost:4317
        expect(config.endpoint, equals('localhost:4317'));
        expect(config.headers, isEmpty);
        expect(config.timeout, equals(const Duration(seconds: 10)));
        expect(config.compression, isFalse);
        expect(config.insecure, isFalse);
        expect(config.maxRetries, equals(3));
        expect(config.baseDelay, equals(const Duration(milliseconds: 100)));
        expect(config.maxDelay, equals(const Duration(seconds: 1)));
        expect(config.certificate, isNull);
        expect(config.clientKey, isNull);
        expect(config.clientCertificate, isNull);
      });
    });

    group('endpoint validation', () {
      test('custom endpoint is preserved', () {
        final config =
            OtlpGrpcExporterConfig(endpoint: 'collector.example.com:4317');
        expect(config.endpoint, equals('collector.example.com:4317'));
      });

      test('empty endpoint throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(endpoint: ''),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          )),
        );
      });

      test('endpoint with spaces throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(endpoint: 'host name:4317'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('spaces'),
          )),
        );
      });

      test('endpoint without scheme is accepted as host:port', () {
        final config =
            OtlpGrpcExporterConfig(endpoint: 'myhost.example.com:4317');
        expect(config.endpoint, equals('myhost.example.com:4317'));
      });

      test('endpoint with http:// scheme is preserved', () {
        final config =
            OtlpGrpcExporterConfig(endpoint: 'http://collector:4317');
        expect(config.endpoint, equals('http://collector:4317'));
      });

      test('localhost without port gets :4317 appended', () {
        final config = OtlpGrpcExporterConfig(endpoint: 'localhost');
        expect(config.endpoint, equals('localhost:4317'));
      });

      test('127.0.0.1 without port gets :4317 appended', () {
        final config = OtlpGrpcExporterConfig(endpoint: '127.0.0.1');
        expect(config.endpoint, equals('127.0.0.1:4317'));
      });

      test('host-only endpoint gets default port appended', () {
        final config =
            OtlpGrpcExporterConfig(endpoint: 'collector.example.com');
        expect(config.endpoint, equals('collector.example.com:4317'));
      });
    });

    group('header validation', () {
      test('custom headers are normalized to lowercase keys', () {
        final config = OtlpGrpcExporterConfig(
          headers: {'Authorization': 'Bearer token123', 'X-Custom': 'value'},
        );
        expect(
            config.headers, containsPair('authorization', 'Bearer token123'));
        expect(config.headers, containsPair('x-custom', 'value'));
        // Original casing key should not be present
        expect(config.headers.containsKey('Authorization'), isFalse);
      });

      test('empty header key throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(headers: {'': 'value'}),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          )),
        );
      });

      test('empty header value throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(headers: {'key': ''}),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          )),
        );
      });
    });

    group('retry validation', () {
      test('negative maxRetries throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(maxRetries: -1),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('negative'),
          )),
        );
      });

      test('zero retries is valid', () {
        final config = OtlpGrpcExporterConfig(maxRetries: 0);
        expect(config.maxRetries, equals(0));
      });

      test('positive maxRetries is valid', () {
        final config = OtlpGrpcExporterConfig(maxRetries: 10);
        expect(config.maxRetries, equals(10));
      });
    });

    group('timeout validation', () {
      test('timeout below 1ms throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(timeout: Duration.zero),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Timeout'),
          )),
        );
      });

      test('timeout above 10 minutes throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(
              timeout: const Duration(minutes: 10, milliseconds: 1)),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Timeout'),
          )),
        );
      });

      test('timeout at lower bound (1ms) is valid', () {
        final config =
            OtlpGrpcExporterConfig(timeout: const Duration(milliseconds: 1));
        expect(config.timeout, equals(const Duration(milliseconds: 1)));
      });

      test('timeout at upper bound (10 minutes) is valid', () {
        final config =
            OtlpGrpcExporterConfig(timeout: const Duration(minutes: 10));
        expect(config.timeout, equals(const Duration(minutes: 10)));
      });
    });

    group('delay validation', () {
      test('baseDelay below 1ms throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(baseDelay: Duration.zero),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('baseDelay'),
          )),
        );
      });

      test('maxDelay below 1ms throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(
            baseDelay: const Duration(milliseconds: 1),
            maxDelay: Duration.zero,
          ),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('maxDelay'),
          )),
        );
      });

      test('baseDelay above 5 minutes throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(
            baseDelay: const Duration(minutes: 5, milliseconds: 1),
            maxDelay: const Duration(minutes: 5, milliseconds: 2),
          ),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('baseDelay'),
          )),
        );
      });

      test('maxDelay above 5 minutes throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(
            maxDelay: const Duration(minutes: 5, milliseconds: 1),
          ),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('maxDelay'),
          )),
        );
      });

      test('baseDelay greater than maxDelay throws ArgumentError', () {
        expect(
          () => OtlpGrpcExporterConfig(
            baseDelay: const Duration(seconds: 2),
            maxDelay: const Duration(seconds: 1),
          ),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('maxDelay cannot be less than baseDelay'),
          )),
        );
      });

      test('baseDelay equal to maxDelay is valid', () {
        final config = OtlpGrpcExporterConfig(
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 1),
        );
        expect(config.baseDelay, equals(const Duration(seconds: 1)));
        expect(config.maxDelay, equals(const Duration(seconds: 1)));
      });
    });

    group('flags', () {
      test('insecure flag is set correctly', () {
        final insecureConfig = OtlpGrpcExporterConfig(insecure: true);
        expect(insecureConfig.insecure, isTrue);

        final secureConfig = OtlpGrpcExporterConfig(insecure: false);
        expect(secureConfig.insecure, isFalse);
      });

      test('compression flag is set correctly', () {
        final compressedConfig = OtlpGrpcExporterConfig(compression: true);
        expect(compressedConfig.compression, isTrue);

        final uncompressedConfig = OtlpGrpcExporterConfig(compression: false);
        expect(uncompressedConfig.compression, isFalse);
      });
    });
  });
}
