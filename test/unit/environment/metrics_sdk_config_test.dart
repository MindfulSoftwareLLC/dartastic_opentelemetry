// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/metrics/export/metrics_sdk_config.dart';

import 'package:test/test.dart';

void main() {
  group('Metrics SDK config parsing', () {
    test('uses defaults when values are missing', () {
      final config = MetricsSdkConfig.fromEnvironment((
        exemplarFilter: null,
        exportInterval: null,
        exportTimeout: null,
      ));

      expect(config.exemplarFilter, equals(MetricsExemplarFilter.traceBased));
      expect(config.exportInterval, equals(const Duration(seconds: 60)));
      expect(config.exportTimeout, equals(const Duration(seconds: 30)));
    });

    test('a zero export interval falls back to the default', () {
      // getPositiveIntEnv admits 0 (minInclusive: 0) and the negative
      // guard does not catch it, so a zero reaches
      // Timer.periodic(Duration.zero) in PeriodicExportingMetricReader -
      // which fires every event-loop turn, spinning the CPU and flooding
      // the exporter. Java rejects non-positive intervals; Go falls back
      // to the default.
      final config = MetricsSdkConfig.fromEnvironment((
        exemplarFilter: null,
        exportInterval: Duration.zero,
        exportTimeout: null,
      ));

      expect(
        config.exportInterval,
        greaterThan(Duration.zero),
        reason: 'a zero interval must never reach Timer.periodic',
      );
      expect(
        config.exportInterval,
        equals(MetricsSdkConfig.defaultExportInterval),
      );
    });

    test('parses valid values', () {
      final config = MetricsSdkConfig.fromEnvironment((
        exemplarFilter: 'always_on',
        exportInterval: const Duration(milliseconds: 1500),
        exportTimeout: const Duration(milliseconds: 2500),
      ));

      expect(config.exemplarFilter, equals(MetricsExemplarFilter.alwaysOn));
      expect(
        config.exportInterval,
        equals(const Duration(milliseconds: 1500)),
      );
      expect(
        config.exportTimeout,
        equals(const Duration(milliseconds: 2500)),
      );
    });

    test('falls back to defaults for invalid values', () {
      final config = MetricsSdkConfig.fromEnvironment((
        exemplarFilter: 'invalid_value',
        exportInterval:
            null, // OTelEnv parser handles non-numeric and converts to null
        exportTimeout: const Duration(milliseconds: -1),
      ));

      expect(config.exemplarFilter, equals(MetricsExemplarFilter.traceBased));
      expect(config.exportInterval, equals(const Duration(seconds: 60)));
      expect(config.exportTimeout, equals(const Duration(seconds: 30)));
    });

    test('maps 0 export timeout to no limit (365 days)', () {
      final config = MetricsSdkConfig.fromEnvironment((
        exemplarFilter: null,
        exportInterval: null,
        exportTimeout: Duration.zero,
      ));

      expect(config.exportTimeout, equals(const Duration(days: 365)));
    });
  });
}
