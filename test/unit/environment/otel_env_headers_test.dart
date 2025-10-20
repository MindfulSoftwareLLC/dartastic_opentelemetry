// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/environment/environment_service/environment_service.dart';
import 'package:dartastic_opentelemetry/src/environment/otel_env.dart';
import 'package:test/test.dart';

void main() {
  group('OTelEnv Headers Parsing', () {
    setUp(() {
      EnvironmentService.instance.clearTestEnvironment();
    });

    tearDown(() {
      EnvironmentService.instance.clearTestEnvironment();
    });

    test('should parse simple headers correctly', () {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_EXPORTER_OTLP_HEADERS': 'key1=value1,key2=value2',
      });

      final config = OTelEnv.getOtlpConfig(signal: 'traces');
      final headers = config['headers'] as Map<String, String>?;

      expect(headers, isNotNull);
      expect(headers!.length, equals(2));
      expect(headers['key1'], equals('value1'));
      expect(headers['key2'], equals('value2'));
    });

    test('should parse headers with base64 values containing equals signs', () {
      // This simulates a Grafana Cloud Authorization header with base64 encoding
      const base64Value =
          'Basic MTEwMjg5MDpnbGNfZXlKdklqb2lNVEk0TXpFME55SXNJbTRpT2lKemRHRmpheTB4TVRBeU9Ea3dMVzkwYkhBdGQzSnBkR1V0WkdGeWRHRnpkR2xqTFhOdGIydGxJaXdpYXlJNklrczVjR3ROTVRCaFUxWTJPSFYyTTFSTE5GZ3hPRU15WVNJc0ltMGlPbnNpY2lJNkluQnliMlF0ZFhNdFpXRnpkQzB3SW4xOQ==';

      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_EXPORTER_OTLP_HEADERS': 'Authorization=$base64Value',
      });

      final config = OTelEnv.getOtlpConfig(signal: 'traces');
      final headers = config['headers'] as Map<String, String>?;

      expect(headers, isNotNull);
      expect(headers!.length, equals(1));
      expect(headers['Authorization'], equals(base64Value));
    });

    test('should parse multiple headers including base64 authorization', () {
      const base64Value =
          'Basic MTEwMjg5MDpnbGNfZXlKdklqb2lNVEk0TXpFME55SXNJbTRpT2lKemRHRmpheTB4TVRBeU9Ea3dMVzkwYkhBdGQzSnBkR1V0WkdGeWRHRnpkR2xqTFhOdGIydGxJaXdpYXlJNklrczVjR3ROTVRCaFUxWTJPSFYyTTFSTE5GZ3hPRU15WVNJc0ltMGlPbnNpY2lJNkluQnliMlF0ZFhNdFpXRnpkQzB3SW4xOQ==';

      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_EXPORTER_OTLP_HEADERS':
            'Authorization=$base64Value,Custom-Header=value',
      });

      final config = OTelEnv.getOtlpConfig(signal: 'traces');
      final headers = config['headers'] as Map<String, String>?;

      expect(headers, isNotNull);
      expect(headers!.length, equals(2));
      expect(headers['Authorization'], equals(base64Value));
      expect(headers['Custom-Header'], equals('value'));
    });

    test('should handle headers with spaces around delimiters', () {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_EXPORTER_OTLP_HEADERS': ' key1 = value1 , key2 = value2 ',
      });

      final config = OTelEnv.getOtlpConfig(signal: 'traces');
      final headers = config['headers'] as Map<String, String>?;

      expect(headers, isNotNull);
      expect(headers!.length, equals(2));
      expect(headers['key1'], equals('value1'));
      expect(headers['key2'], equals('value2'));
    });

    test('should ignore malformed header pairs', () {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_EXPORTER_OTLP_HEADERS': 'key1=value1,invalid,key2=value2',
      });

      final config = OTelEnv.getOtlpConfig(signal: 'traces');
      final headers = config['headers'] as Map<String, String>?;

      expect(headers, isNotNull);
      expect(headers!.length, equals(2));
      expect(headers['key1'], equals('value1'));
      expect(headers['key2'], equals('value2'));
    });

    test('should prefer signal-specific headers over general headers', () {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_EXPORTER_OTLP_HEADERS': 'key=general',
        'OTEL_EXPORTER_OTLP_TRACES_HEADERS': 'key=traces-specific',
      });

      final config = OTelEnv.getOtlpConfig(signal: 'traces');
      final headers = config['headers'] as Map<String, String>?;

      expect(headers, isNotNull);
      expect(headers!['key'], equals('traces-specific'));
    });
  });
}
