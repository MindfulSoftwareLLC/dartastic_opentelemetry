// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// OTLP spec precedence for connection security (#88): explicit choice >
// endpoint scheme > OTEL_EXPORTER_OTLP_INSECURE > secure default. The
// INSECURE variable "only applies ... when an endpoint is provided
// without the http or https scheme".

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OTelEnv.resolveOtlpSecure', () {
    test('a scheme outranks an explicit choice (#225)', () {
      // protocol/exporter.md, Endpoint (OTLP/gRPC): an https scheme
      // "indicates a secure connection and takes precedence over the
      // insecure configuration setting", and likewise http for insecure.
      // The setting - from either the parameter or the environment - only
      // applies to a scheme-less endpoint.
      //
      // This inverts the expectation originally pinned in #89, which had
      // the explicit parameter winning over the scheme.
      expect(
        OTelEnv.resolveOtlpSecure(
          explicitSecure: true,
          envInsecure: true,
          endpoint: 'http://collector:4317',
        ),
        isFalse,
        reason: 'an http scheme means plaintext even when asked for TLS',
      );
      expect(
        OTelEnv.resolveOtlpSecure(
          explicitSecure: false,
          endpoint: 'https://collector:4317',
        ),
        isTrue,
        reason: 'an https scheme means TLS even when asked for plaintext',
      );
    });

    test('the explicit choice decides for a scheme-less endpoint', () {
      // The window where the setting actually applies: gRPC's native
      // host:port form. Here the parameter beats the environment, being
      // the code equivalent of OTEL_EXPORTER_OTLP_INSECURE.
      expect(
        OTelEnv.resolveOtlpSecure(
          explicitSecure: false,
          envInsecure: false,
          endpoint: 'collector:4317',
        ),
        isFalse,
        reason: 'code beats env',
      );
      expect(
        OTelEnv.resolveOtlpSecure(
          explicitSecure: true,
          envInsecure: true,
          endpoint: 'collector:4317',
        ),
        isTrue,
      );
    });

    test('http scheme means insecure, even against the env var', () {
      expect(
        OTelEnv.resolveOtlpSecure(endpoint: 'http://collector:4317'),
        isFalse,
      );
      expect(
        OTelEnv.resolveOtlpSecure(
          endpoint: 'http://collector:4317',
          envInsecure: false, // scheme takes precedence per spec
        ),
        isFalse,
      );
    });

    test('https scheme means secure, even against the env var', () {
      expect(
        OTelEnv.resolveOtlpSecure(endpoint: 'https://collector:4317'),
        isTrue,
      );
      expect(
        OTelEnv.resolveOtlpSecure(
          endpoint: 'https://collector:4317',
          envInsecure: true, // scheme takes precedence per spec
        ),
        isTrue,
      );
    });

    test('scheme-less endpoints defer to the env var', () {
      expect(
        OTelEnv.resolveOtlpSecure(
          endpoint: 'collector:4317',
          envInsecure: true,
        ),
        isFalse,
      );
      expect(
        OTelEnv.resolveOtlpSecure(
          endpoint: 'collector:4317',
          envInsecure: false,
        ),
        isTrue,
      );
    });

    test('bare host:port is not mistaken for a scheme', () {
      // Uri.parse('collector:4317') reports scheme "collector"; only
      // exact http/https participate in the scheme rule.
      expect(
        OTelEnv.resolveOtlpSecure(endpoint: 'collector:4317'),
        isTrue,
        reason: 'falls through to the secure default',
      );
    });

    test('fallback applies when nothing else decides', () {
      expect(OTelEnv.resolveOtlpSecure(), isTrue);
      expect(OTelEnv.resolveOtlpSecure(fallback: false), isFalse);
      expect(OTelEnv.resolveOtlpSecure(endpoint: null), isTrue);
    });
  });

  group('pipeline integration', () {
    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
      EnvironmentService.testOverrides = null;
    });

    test(
        'an http:// endpoint from env no longer requires'
        ' OTEL_EXPORTER_OTLP_INSECURE', () async {
      await OTel.reset();
      EnvironmentService.testOverrides = {
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://collector:4317',
        'OTEL_TRACES_EXPORTER': 'none',
        'OTEL_METRICS_EXPORTER': 'none',
        'OTEL_LOGS_EXPORTER': 'none',
      };
      // Initialization resolving secure=false from the scheme is the
      // observable contract; before #88 this required the extra flag.
      await OTel.initialize(
        serviceName: 'scheme-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );
      expect(OTel.tracerProvider().spanProcessors, isEmpty);
    });
  });
}
