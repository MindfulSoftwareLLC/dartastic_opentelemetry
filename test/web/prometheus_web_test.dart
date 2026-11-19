// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

@TestOn('browser')
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await OTel.reset();
    EnvironmentService.testOverrides = null;
  });

  test('Prometheus alone falls back to OTLP on web', () async {
    EnvironmentService.testOverrides = {
      'OTEL_TRACES_EXPORTER': 'none',
      'OTEL_LOGS_EXPORTER': 'none',
      'OTEL_METRICS_EXPORTER': 'prometheus',
    };
    await OTel.initialize(detectPlatformResources: false);
    expect(PrometheusMetricReader.isSupported, isFalse);
    final reader = OTel.meterProvider().metricReaders.single
        as PeriodicExportingMetricReader;
    expect(reader.exporter, isA<OtlpHttpMetricExporter>());
  });

  test('unsupported Prometheus does not displace console on web', () async {
    EnvironmentService.testOverrides = {
      'OTEL_TRACES_EXPORTER': 'none',
      'OTEL_LOGS_EXPORTER': 'none',
      'OTEL_METRICS_EXPORTER': 'prometheus,console',
    };
    await OTel.initialize(detectPlatformResources: false);
    final reader = OTel.meterProvider().metricReaders.single
        as PeriodicExportingMetricReader;
    expect(reader.exporter, isA<ConsoleMetricExporter>());
  });
}
