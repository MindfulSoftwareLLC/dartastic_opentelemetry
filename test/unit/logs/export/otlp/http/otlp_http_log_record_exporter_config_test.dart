// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpHttpLogRecordExporterConfig endpoint normalisation', () {
    test('a bare localhost gets the OTLP/HTTP default port', () {
      final config =
          OtlpHttpLogRecordExporterConfig(endpoint: 'http://localhost');
      expect(config.endpoint, equals('http://localhost:4318'));
    });

    test('an endpoint with a port and a path is kept as given', () {
      final config = OtlpHttpLogRecordExporterConfig(
          endpoint: 'https://collector.example:4318/v1/logs');
      expect(config.endpoint, equals('https://collector.example:4318/v1/logs'));
    });

    test('a scheme with no host is refused', () {
      expect(
        () => OtlpHttpLogRecordExporterConfig(endpoint: 'http://'),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', contains('Invalid host'))),
      );
    });

    test('an endpoint the URI parser cannot read is refused', () {
      expect(
        () => OtlpHttpLogRecordExporterConfig(endpoint: 'http://[::1'),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', contains('Invalid URL format'))),
      );
    });
  });
}
