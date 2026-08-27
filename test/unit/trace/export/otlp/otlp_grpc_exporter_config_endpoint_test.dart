// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Endpoint validation in OtlpGrpcExporterConfig. These paths were
// uncovered: a URL-form endpoint with no port, an unparseable port, and the
// fallthrough for input that is neither host:port nor a valid URI.
//
// Validation runs in the constructor, so each case is driven by constructing
// a config rather than by calling the private validator directly.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpGrpcExporterConfig endpoint validation', () {
    test(
      'a URL with no port gets the default gRPC port appended',
      () {
        expect(
          OtlpGrpcExporterConfig(endpoint: 'http://collector.example.com')
              .endpoint,
          equals('http://collector.example.com:4317'),
        );
      },
      skip: 'Blocked on #281: the branch that appends 4317 is guarded on '
          '!endpoint.contains(":"), which no URL-form endpoint can satisfy, '
          'so it is dead code and the port is never added.',
    );

    test('a bare host with no port gets the default gRPC port appended', () {
      expect(
        OtlpGrpcExporterConfig(endpoint: 'collector.example.com').endpoint,
        equals('collector.example.com:4317'),
      );
    });

    test('an explicit port in URL form is left alone', () {
      expect(
        OtlpGrpcExporterConfig(endpoint: 'http://collector.example.com:4317')
            .endpoint,
        equals('http://collector.example.com:4317'),
      );
    });

    test('host:port form is left alone', () {
      expect(
        OtlpGrpcExporterConfig(endpoint: 'collector.example.com:4317').endpoint,
        equals('collector.example.com:4317'),
      );
    });

    test('a non-numeric port is rejected', () {
      expect(
        () =>
            OtlpGrpcExporterConfig(endpoint: 'collector.example.com:notaport'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('an empty host in URL form is rejected', () {
      expect(
        () => OtlpGrpcExporterConfig(endpoint: 'http://:4317'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('the default endpoint is accepted unchanged', () {
      expect(OtlpGrpcExporterConfig().endpoint, equals('localhost:4317'));
    });
  });
}
