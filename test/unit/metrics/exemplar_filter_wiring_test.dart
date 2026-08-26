// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// OTEL_METRICS_EXEMPLAR_FILTER has to reach the exporter, not just be
// parsed. Asserting that the variable is readable proves nothing about
// whether setting it changes behaviour - the defect this PR fixes was
// exactly a value that was parsed and then dropped on the floor.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('OTEL_METRICS_EXEMPLAR_FILTER reaches the exporter', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'exemplar-filter-wiring',
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

    OtlpGrpcMetricExporter exporterFor(String? filterValue) {
      EnvironmentService.testOverrides = {
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
        if (filterValue != null) 'OTEL_METRICS_EXEMPLAR_FILTER': filterValue,
      };
      final provider = MetricsConfiguration.configureMeterProvider();
      final reader =
          provider.metricReaders.last as PeriodicExportingMetricReader;
      return reader.exporter as OtlpGrpcMetricExporter;
    }

    // One row per accepted spelling, plus the default and a bad value.
    const cases = <(String, String?, MetricsExemplarFilter)>[
      ('always_on', 'always_on', MetricsExemplarFilter.alwaysOn),
      ('always_off', 'always_off', MetricsExemplarFilter.alwaysOff),
      ('trace_based', 'trace_based', MetricsExemplarFilter.traceBased),
      ('mixed case', 'Always_On', MetricsExemplarFilter.alwaysOn),
      ('unset defaults to trace_based', null, MetricsExemplarFilter.traceBased),
      (
        'an unusable value falls back to trace_based',
        'nonsense',
        MetricsExemplarFilter.traceBased
      ),
    ];

    for (final (label, value, expected) in cases) {
      test(label, () {
        expect(
          exporterFor(value).config.exemplarFilter,
          equals(expected),
          reason: 'the parsed value must be carried into the exporter '
              'configuration, not merely read from the environment',
        );
      });
    }

    test('an explicit exporter is left alone', () async {
      // A caller who supplies their own exporter owns its configuration;
      // the environment must not reach past it.
      EnvironmentService.testOverrides = {
        'OTEL_METRICS_EXEMPLAR_FILTER': 'always_off',
      };
      final mine = MemoryMetricExporter();

      final provider =
          MetricsConfiguration.configureMeterProvider(metricExporter: mine);

      final reader =
          provider.metricReaders.last as PeriodicExportingMetricReader;
      expect(reader.exporter, same(mine));
    });
  });
}
