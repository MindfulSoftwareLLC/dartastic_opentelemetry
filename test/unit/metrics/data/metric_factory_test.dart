// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'test',
      detectPlatformResources: false,
    );
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  group('Metric constructor', () {
    test('sets all fields correctly', () {
      final now = DateTime.now();
      final scope = OTelAPI.instrumentationScope(name: 'test-scope');
      final points = <MetricPoint<dynamic>>[
        MetricPoint<int>(
          attributes: Attributes.of({'key': 'value'}),
          startTime: now.subtract(const Duration(seconds: 10)),
          endTime: now,
          value: 42,
        ),
      ];

      final metric = Metric(
        name: 'my_metric',
        description: 'A test metric',
        unit: 'ms',
        type: MetricType.sum,
        temporality: AggregationTemporality.delta,
        instrumentationScope: scope,
        points: points,
        isMonotonic: false,
      );

      expect(metric.name, equals('my_metric'));
      expect(metric.description, equals('A test metric'));
      expect(metric.unit, equals('ms'));
      expect(metric.type, equals(MetricType.sum));
      expect(metric.temporality, equals(AggregationTemporality.delta));
      expect(metric.instrumentationScope, equals(scope));
      expect(metric.points, equals(points));
      expect(metric.isMonotonic, isFalse);
    });
  });

  group('Metric.sum factory', () {
    test(
        'sets type to sum with default monotonic true and cumulative temporality',
        () {
      final now = DateTime.now();
      final points = <MetricPoint<dynamic>>[
        MetricPoint<int>(
          attributes: Attributes.of({'key': 'value'}),
          startTime: now.subtract(const Duration(seconds: 5)),
          endTime: now,
          value: 10,
        ),
      ];

      final metric = Metric.sum(
        name: 'sum_metric',
        description: 'A sum metric',
        unit: 'requests',
        points: points,
      );

      expect(metric.name, equals('sum_metric'));
      expect(metric.description, equals('A sum metric'));
      expect(metric.unit, equals('requests'));
      expect(metric.type, equals(MetricType.sum));
      expect(metric.temporality, equals(AggregationTemporality.cumulative));
      expect(metric.isMonotonic, isTrue);
      expect(metric.points, equals(points));
    });

    test('with delta temporality', () {
      final now = DateTime.now();
      final points = <MetricPoint<dynamic>>[
        MetricPoint<int>(
          attributes: Attributes.of({'key': 'value'}),
          startTime: now.subtract(const Duration(seconds: 5)),
          endTime: now,
          value: 10,
        ),
      ];

      final metric = Metric.sum(
        name: 'delta_sum',
        points: points,
        temporality: AggregationTemporality.delta,
      );

      expect(metric.temporality, equals(AggregationTemporality.delta));
      expect(metric.type, equals(MetricType.sum));
    });

    test('with isMonotonic false', () {
      final now = DateTime.now();
      final points = <MetricPoint<dynamic>>[
        MetricPoint<int>(
          attributes: Attributes.of({'key': 'value'}),
          startTime: now.subtract(const Duration(seconds: 5)),
          endTime: now,
          value: -3,
        ),
      ];

      final metric = Metric.sum(
        name: 'non_monotonic_sum',
        points: points,
        isMonotonic: false,
      );

      expect(metric.isMonotonic, isFalse);
      expect(metric.type, equals(MetricType.sum));
    });
  });

  group('Metric.gauge factory', () {
    test('sets type to gauge with temporality always cumulative', () {
      final now = DateTime.now();
      final scope = OTelAPI.instrumentationScope(name: 'gauge-scope');
      final points = <MetricPoint<dynamic>>[
        MetricPoint<double>(
          attributes: Attributes.of({'host': 'server1'}),
          startTime: now.subtract(const Duration(seconds: 1)),
          endTime: now,
          value: 72.5,
        ),
      ];

      final metric = Metric.gauge(
        name: 'cpu_usage',
        description: 'CPU usage percentage',
        unit: 'percent',
        points: points,
        instrumentationScope: scope,
      );

      expect(metric.name, equals('cpu_usage'));
      expect(metric.description, equals('CPU usage percentage'));
      expect(metric.unit, equals('percent'));
      expect(metric.type, equals(MetricType.gauge));
      expect(metric.temporality, equals(AggregationTemporality.cumulative));
      expect(metric.instrumentationScope, equals(scope));
      expect(metric.points, equals(points));
      // Gauge should not set isMonotonic
      expect(metric.isMonotonic, isNull);
    });
  });

  group('Metric.histogram factory', () {
    test('sets type to histogram with default cumulative temporality', () {
      final now = DateTime.now();
      final points = <MetricPoint<dynamic>>[
        MetricPoint<int>(
          attributes: Attributes.of({'endpoint': '/api/test'}),
          startTime: now.subtract(const Duration(seconds: 30)),
          endTime: now,
          value: 150,
        ),
      ];

      final metric = Metric.histogram(
        name: 'request_duration',
        description: 'Request duration in ms',
        unit: 'ms',
        points: points,
      );

      expect(metric.name, equals('request_duration'));
      expect(metric.description, equals('Request duration in ms'));
      expect(metric.unit, equals('ms'));
      expect(metric.type, equals(MetricType.histogram));
      expect(metric.temporality, equals(AggregationTemporality.cumulative));
      expect(metric.points, equals(points));
      // Histogram should not set isMonotonic
      expect(metric.isMonotonic, isNull);
    });

    test('with delta temporality', () {
      final now = DateTime.now();
      final points = <MetricPoint<dynamic>>[
        MetricPoint<int>(
          attributes: Attributes.of({'key': 'value'}),
          startTime: now.subtract(const Duration(seconds: 5)),
          endTime: now,
          value: 100,
        ),
      ];

      final metric = Metric.histogram(
        name: 'delta_histogram',
        points: points,
        temporality: AggregationTemporality.delta,
      );

      expect(metric.temporality, equals(AggregationTemporality.delta));
      expect(metric.type, equals(MetricType.histogram));
    });
  });

  group('MetricType enum', () {
    test('has all expected values', () {
      expect(MetricType.values, hasLength(3));
      expect(MetricType.values, contains(MetricType.sum));
      expect(MetricType.values, contains(MetricType.gauge));
      expect(MetricType.values, contains(MetricType.histogram));
    });
  });

  group('AggregationTemporality enum', () {
    test('has all expected values', () {
      expect(AggregationTemporality.values, hasLength(2));
      expect(AggregationTemporality.values,
          contains(AggregationTemporality.cumulative));
      expect(AggregationTemporality.values,
          contains(AggregationTemporality.delta));
    });
  });

  group('MetricPointKind enum', () {
    test('has all expected values', () {
      expect(MetricPointKind.values, hasLength(4));
      expect(MetricPointKind.values, contains(MetricPointKind.sum));
      expect(MetricPointKind.values, contains(MetricPointKind.gauge));
      expect(MetricPointKind.values, contains(MetricPointKind.histogram));
      expect(MetricPointKind.values,
          contains(MetricPointKind.exponentialHistogram));
    });
  });
}
