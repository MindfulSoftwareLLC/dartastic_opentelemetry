// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/environment/otel_env.dart';
import 'package:dartastic_opentelemetry/src/metrics/export/metrics_sdk_config.dart';
import 'package:test/test.dart';

void main() {
  group('Metrics SDK config parsing', () {
    test('uses defaults when values are missing', () {
      final config = OTelEnv.parseMetricsSdkConfig();

      expect(config.exemplarFilter, equals(MetricsExemplarFilter.traceBased));
      expect(config.exportInterval, equals(const Duration(seconds: 60)));
      expect(config.exportTimeout, equals(const Duration(seconds: 30)));
    });

    test('parses valid values', () {
      final config = OTelEnv.parseMetricsSdkConfig(
        exemplarFilter: 'always_on',
        exportInterval: '1500',
        exportTimeout: '2500',
      );

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
      final config = OTelEnv.parseMetricsSdkConfig(
        exemplarFilter: 'invalid_value',
        exportInterval: 'not-a-number',
        exportTimeout: '-1',
      );

      expect(config.exemplarFilter, equals(MetricsExemplarFilter.traceBased));
      expect(config.exportInterval, equals(const Duration(seconds: 60)));
      expect(config.exportTimeout, equals(const Duration(seconds: 30)));
    });
  });
}