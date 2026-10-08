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
    test('a URL with no port gets the default gRPC port appended', () {
      expect(
        OtlpGrpcExporterConfig(endpoint: 'http://collector.example.com')
            .endpoint,
        equals('http://collector.example.com:4317'),
      );
    });

    test('the default port goes before the path, query and fragment', () {
      expect(
        OtlpGrpcExporterConfig(endpoint: 'https://c.example.com/ingest?a=b#f')
            .endpoint,
        equals('https://c.example.com:4317/ingest?a=b#f'),
      );
    });

    test('an IPv6 URL with no port keeps its brackets', () {
      expect(
        OtlpGrpcExporterConfig(endpoint: 'http://[::1]').endpoint,
        equals('http://[::1]:4317'),
      );
    });

    test('userinfo is not mistaken for a port', () {
      expect(
        OtlpGrpcExporterConfig(endpoint: 'http://user:pw@c.example.com')
            .endpoint,
        equals('http://user:pw@c.example.com:4317'),
      );
    });

    test('an explicit scheme-default port is left alone', () {
      expect(
        OtlpGrpcExporterConfig(endpoint: 'http://c.example.com:80').endpoint,
        equals('http://c.example.com:80'),
      );
      expect(
        OtlpGrpcExporterConfig(endpoint: 'http://[::1]:4317').endpoint,
        equals('http://[::1]:4317'),
      );
    });

    test('a URL with an empty or non-numeric port is rejected', () {
      expect(
        () => OtlpGrpcExporterConfig(endpoint: 'http://c.example.com:'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => OtlpGrpcExporterConfig(endpoint: 'http://c.example.com:abc'),
        throwsA(isA<ArgumentError>()),
      );
    });

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
