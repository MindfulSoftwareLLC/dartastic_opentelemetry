// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Tests for #253: the programmatic `secure` parameter of
// MetricsConfiguration.configureMeterProvider and
// LogsConfiguration.configureLoggerProvider takes effect with the
// same precedence as OTel.initialize's parameter: a non-null value is
// the explicit choice and wins over OTEL_EXPORTER_OTLP_INSECURE; null
// defers to the endpoint scheme, then the env var, then insecure.
// The endpoint scheme still decides at the gRPC exporter for
// scheme-carrying endpoints, per the OTLP endpoint rule (#225).

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  // The regression that makes this fix load-bearing: OTel.initialize
  // resolves `secure` for the traces signal and reassigns its own
  // parameter to that boolean. If that resolved value is handed to the
  // metrics/logs configurations as their *explicit* choice, it outranks
  // their own per-signal endpoint scheme - silently turning TLS off for a
  // signal the operator pointed at an https endpoint.
  group('OTel.initialize does not leak the traces decision (#253)', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      EnvironmentService.testOverrides = null;
      await OTel.shutdown();
      await OTel.reset();
    });

    test('an https logs endpoint keeps TLS when traces resolve insecure',
        () async {
      EnvironmentService.testOverrides = {
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
        // Generic endpoint is plaintext, so the traces signal resolves
        // insecure...
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:4317',
        // ...while the operator points logs at a TLS endpoint.
        'OTEL_EXPORTER_OTLP_LOGS_ENDPOINT': 'https://logs.example.com:4317',
      };

      // No `secure:` argument, so nothing the caller said may override the
      // per-signal scheme.
      await OTel.initialize(
        serviceName: 'secure-initialize-test',
        detectPlatformResources: false,
        enableMetrics: false,
      );

      final provider = OTel.loggerProvider();
      final processor =
          provider.logRecordProcessors.last as BatchLogRecordProcessor;
      final exporter = processor.exporter as OtlpGrpcLogRecordExporter;

      expect(
        exporter.config.insecure,
        isFalse,
        reason: 'the logs endpoint is https, so the logs exporter must use '
            'TLS; the traces signal resolving to insecure must not become '
            "the logs signal's explicit choice",
      );
    });
  });
  group('programmatic secure parameter precedence (#253)', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'secure-param-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );
    });

    tearDown(() async {
      EnvironmentService.testOverrides = null;
      await OTel.shutdown();
      await OTel.reset();
    });

    OtlpGrpcMetricExporter metricsExporter({
      required String endpoint,
      bool? secure,
    }) {
      final provider = MetricsConfiguration.configureMeterProvider(
        endpoint: endpoint,
        secure: secure,
      );
      final reader =
          provider.metricReaders.last as PeriodicExportingMetricReader;
      return reader.exporter as OtlpGrpcMetricExporter;
    }

    OtlpGrpcLogRecordExporter logsExporter({
      required String endpoint,
      bool? secure,
    }) {
      final provider = LogsConfiguration.configureLoggerProvider(
        endpoint: endpoint,
        secure: secure,
      );
      final processor =
          provider.logRecordProcessors.last as BatchLogRecordProcessor;
      return processor.exporter as OtlpGrpcLogRecordExporter;
    }

    group('metrics', () {
      test(
          'secure: true beats OTEL_EXPORTER_OTLP_INSECURE on a '
          'scheme-less endpoint', () {
        EnvironmentService.testOverrides = {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_INSECURE': 'true',
        };
        final exporter =
            metricsExporter(endpoint: 'localhost:4317', secure: true);
        expect(exporter.config.insecure, isFalse,
            reason: 'the explicit programmatic choice must win over env');
      });

      test(
          'secure: false beats an env demand for TLS on a scheme-less '
          'endpoint', () {
        EnvironmentService.testOverrides = {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_INSECURE': 'false',
        };
        final exporter =
            metricsExporter(endpoint: 'localhost:4317', secure: false);
        expect(exporter.config.insecure, isTrue);
      });

      test('null defers to OTEL_EXPORTER_OTLP_INSECURE', () {
        EnvironmentService.testOverrides = {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_INSECURE': 'false',
        };
        final exporter = metricsExporter(endpoint: 'localhost:4317');
        expect(exporter.config.insecure, isFalse);
      });

      test('null with no scheme and no env falls back to TLS', () {
        EnvironmentService.testOverrides = {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
        };
        final exporter = metricsExporter(endpoint: 'localhost:4317');
        expect(exporter.config.insecure, isFalse,
            reason: 'resolveOtlpSecure falls back to secure when neither a '
                'scheme, an env var, nor the parameter decides');
      });

      test('an https scheme yields TLS without any parameter', () {
        EnvironmentService.testOverrides = {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
        };
        final exporter = metricsExporter(endpoint: 'https://collector:4317');
        expect(exporter.config.insecure, isFalse);
      });

      test(
          'an explicit secure: true currently outranks an http scheme '
          '(see #225)', () {
        EnvironmentService.testOverrides = {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
        };
        final exporter = metricsExporter(
          endpoint: 'http://localhost:4317',
          secure: true,
        );
        expect(exporter.config.insecure, isFalse,
            reason: 'resolveOtlpSecure returns the explicit parameter '
                'before consulting the scheme. #225 tracks making the '
                'endpoint scheme decisive at the gRPC exporter layer, '
                'which will invert this expectation.');
      });
    });

    group('logs', () {
      test(
          'secure: true beats OTEL_EXPORTER_OTLP_INSECURE on a '
          'scheme-less endpoint', () {
        EnvironmentService.testOverrides = {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_INSECURE': 'true',
        };
        final exporter = logsExporter(endpoint: 'localhost:4317', secure: true);
        expect(exporter.config.insecure, isFalse);
      });

      test(
          'secure: false beats an env demand for TLS on a scheme-less '
          'endpoint', () {
        EnvironmentService.testOverrides = {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_INSECURE': 'false',
        };
        final exporter =
            logsExporter(endpoint: 'localhost:4317', secure: false);
        expect(exporter.config.insecure, isTrue);
      });

      test('null defers to OTEL_EXPORTER_OTLP_INSECURE', () {
        EnvironmentService.testOverrides = {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_INSECURE': 'false',
        };
        final exporter = logsExporter(endpoint: 'localhost:4317');
        expect(exporter.config.insecure, isFalse);
      });

      test('null with no scheme and no env falls back to TLS', () {
        EnvironmentService.testOverrides = {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
        };
        final exporter = logsExporter(endpoint: 'localhost:4317');
        expect(exporter.config.insecure, isFalse,
            reason: 'resolveOtlpSecure falls back to secure when neither a '
                'scheme, an env var, nor the parameter decides');
      });
    });
  });
}
