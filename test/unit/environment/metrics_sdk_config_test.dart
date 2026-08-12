// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

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

    test('parses valid values', () {
      final config = MetricsSdkConfig.fromEnvironment((
        exemplarFilter: 'always_on',
        exportInterval: '1500',
        exportTimeout: '2500',
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
        exportInterval: 'not-a-number',
        exportTimeout: '-1',
      ));

      expect(config.exemplarFilter, equals(MetricsExemplarFilter.traceBased));
      expect(config.exportInterval, equals(const Duration(seconds: 60)));
      expect(config.exportTimeout, equals(const Duration(seconds: 30)));
    });

    test('maps 0 export timeout to no limit (365 days)', () {
      final config = MetricsSdkConfig.fromEnvironment((
        exemplarFilter: null,
        exportInterval: null,
        exportTimeout: '0',
      ));

      expect(config.exportTimeout, equals(const Duration(days: 365)));
    });
  });
}
