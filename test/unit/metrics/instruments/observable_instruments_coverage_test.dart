// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('Observable Instruments Coverage Tests', () {
    late MeterProvider meterProvider;
    late Meter meter;
    late MemoryMetricExporter memoryExporter;
    late MemoryMetricReader metricReader;

    setUp(() async {
      await OTel.reset();
      memoryExporter = MemoryMetricExporter();
      metricReader = MemoryMetricReader(exporter: memoryExporter);
      await OTel.initialize(
        serviceName: 'test',
        metricReader: metricReader,
        detectPlatformResources: false,
      );
      meterProvider = OTel.meterProvider();
      meter = meterProvider.getMeter(name: 'test-meter') as Meter;
    });

    tearDown(() async {
      await OTel.reset();
    });

    group('ObservableCounter', () {
      test('callback is invoked during collection', () {
        bool callbackInvoked = false;

        final counter = meter.createObservableCounter<int>(
          name: 'obs_counter_invoked',
          callback: (APIObservableResult<int> result) {
            callbackInvoked = true;
            result.observe(10);
          },
        ) as ObservableCounter<int>;

        counter.collect();

        expect(callbackInvoked, isTrue);
      });

      test('records value correctly', () {
        final counter = meter.createObservableCounter<int>(
          name: 'obs_counter_value',
          callback: (APIObservableResult<int> result) {
            result.observe(42);
          },
        ) as ObservableCounter<int>;

        final measurements = counter.collect();
        expect(measurements, isNotEmpty);
        expect(measurements.first.value, equals(42));

        final points = counter.collectPoints();
        expect(points, isNotEmpty);
        expect(points.first.value, equals(42));
      });
    });

    group('ObservableUpDownCounter', () {
      test('callback invoked during collection', () {
        bool callbackInvoked = false;

        final counter = meter.createObservableUpDownCounter<int>(
          name: 'obs_updown_invoked',
          callback: (APIObservableResult<int> result) {
            callbackInvoked = true;
            result.observe(5);
          },
        ) as ObservableUpDownCounter<int>;

        counter.collect();

        expect(callbackInvoked, isTrue);
      });

      test('records positive and negative values', () {
        int callCount = 0;

        final counter = meter.createObservableUpDownCounter<int>(
          name: 'obs_updown_values',
          callback: (APIObservableResult<int> result) {
            callCount++;
            if (callCount == 1) {
              result.observe(50);
            } else {
              result.observe(-10);
            }
          },
        ) as ObservableUpDownCounter<int>;

        // First collection: positive value
        counter.collect();
        var points = counter.collectPoints();
        expect(points, isNotEmpty);
        expect(points.first.value, equals(50));

        // Second collection: negative value
        counter.collect();
        points = counter.collectPoints();
        expect(points, isNotEmpty);
        expect(points.first.value, equals(-10));
      });
    });

    group('ObservableGauge', () {
      test('callback invoked during collection', () {
        bool callbackInvoked = false;

        final gauge = meter.createObservableGauge<double>(
          name: 'obs_gauge_invoked',
          callback: (APIObservableResult<double> result) {
            callbackInvoked = true;
            result.observe(99.9);
          },
        ) as ObservableGauge<double>;

        gauge.collect();

        expect(callbackInvoked, isTrue);
      });

      test('records latest value', () {
        int callCount = 0;

        final gauge = meter.createObservableGauge<double>(
          name: 'obs_gauge_latest',
          callback: (APIObservableResult<double> result) {
            callCount++;
            result.observe(callCount * 10.0);
          },
        ) as ObservableGauge<double>;

        // First collection
        gauge.collect();
        var points = gauge.collectPoints();
        expect(points, isNotEmpty);
        expect(points.first.value, equals(10.0));

        // Second collection: should have latest value
        gauge.collect();
        points = gauge.collectPoints();
        expect(points, isNotEmpty);
        expect(points.first.value, equals(20.0));
      });
    });

    group('Multiple callbacks', () {
      test('ObservableCounter with multiple callbacks works', () {
        final counter = meter.createObservableCounter<int>(
            name: 'multi_callback_counter') as ObservableCounter<int>;

        final attr1 = {'source': 'cb1'}.toAttributes();
        final attr2 = {'source': 'cb2'}.toAttributes();

        counter.addCallback((APIObservableResult<int> result) {
          result.observe(100, attr1);
        });
        counter.addCallback((APIObservableResult<int> result) {
          result.observe(200, attr2);
        });

        expect(counter.callbacks, hasLength(2));

        final measurements = counter.collect();
        expect(measurements, hasLength(2));
        expect(
          measurements.where((m) => m.attributes == attr1).first.value,
          equals(100),
        );
        expect(
          measurements.where((m) => m.attributes == attr2).first.value,
          equals(200),
        );
      });

      test('ObservableGauge with multiple callbacks works', () {
        final gauge = meter.createObservableGauge<double>(
            name: 'multi_callback_gauge') as ObservableGauge<double>;

        final attr1 = {'sensor': 'indoor'}.toAttributes();
        final attr2 = {'sensor': 'outdoor'}.toAttributes();

        gauge.addCallback((APIObservableResult<double> result) {
          result.observe(22.5, attr1);
        });
        gauge.addCallback((APIObservableResult<double> result) {
          result.observe(15.0, attr2);
        });

        expect(gauge.callbacks, hasLength(2));

        final measurements = gauge.collect();
        expect(measurements, hasLength(2));
        expect(
          measurements.where((m) => m.attributes == attr1).first.value,
          closeTo(22.5, 0.001),
        );
        expect(
          measurements.where((m) => m.attributes == attr2).first.value,
          closeTo(15.0, 0.001),
        );
      });

      test('ObservableUpDownCounter with multiple callbacks works', () {
        final counter = meter.createObservableUpDownCounter<int>(
          name: 'multi_callback_updown',
        ) as ObservableUpDownCounter<int>;

        final attr1 = {'pool': 'workers'}.toAttributes();
        final attr2 = {'pool': 'connections'}.toAttributes();

        counter.addCallback((APIObservableResult<int> result) {
          result.observe(10, attr1);
        });
        counter.addCallback((APIObservableResult<int> result) {
          result.observe(-5, attr2);
        });

        expect(counter.callbacks, hasLength(2));

        final measurements = counter.collect();
        expect(measurements, hasLength(2));
        expect(
          measurements.where((m) => m.attributes == attr1).first.value,
          equals(10),
        );
        expect(
          measurements.where((m) => m.attributes == attr2).first.value,
          equals(-5),
        );
      });
    });

    group('Observable with attributes', () {
      test(
        'ObservableCounter with attributes reports per-attribute values',
        () {
          final attr1 = {'region': 'us-east'}.toAttributes();
          final attr2 = {'region': 'eu-west'}.toAttributes();

          final counter = meter.createObservableCounter<int>(
            name: 'obs_counter_attrs',
            callback: (APIObservableResult<int> result) {
              result.observe(100, attr1);
              result.observe(200, attr2);
            },
          ) as ObservableCounter<int>;

          counter.collect();

          final metrics = counter.collectMetrics();
          expect(metrics, isNotEmpty);
          expect(metrics.first.points, hasLength(2));
        },
      );

      test('ObservableGauge with attributes reports per-attribute values', () {
        final attr1 = {'host': 'server1'}.toAttributes();
        final attr2 = {'host': 'server2'}.toAttributes();

        final gauge = meter.createObservableGauge<double>(
          name: 'obs_gauge_attrs',
          callback: (APIObservableResult<double> result) {
            result.observe(75.0, attr1);
            result.observe(82.3, attr2);
          },
        ) as ObservableGauge<double>;

        gauge.collect();

        final metrics = gauge.collectMetrics();
        expect(metrics, isNotEmpty);
        expect(metrics.first.points, hasLength(2));
      });

      test(
        'ObservableUpDownCounter with attributes reports per-attribute values',
        () {
          final attr1 = {'queue': 'high'}.toAttributes();
          final attr2 = {'queue': 'low'}.toAttributes();

          final counter = meter.createObservableUpDownCounter<int>(
            name: 'obs_updown_attrs',
            callback: (APIObservableResult<int> result) {
              result.observe(30, attr1);
              result.observe(-12, attr2);
            },
          ) as ObservableUpDownCounter<int>;

          counter.collect();

          final metrics = counter.collectMetrics();
          expect(metrics, isNotEmpty);
          expect(metrics.first.points, hasLength(2));
        },
      );
    });

    group('Collection returns metrics', () {
      test(
        'ObservableCounter collection returns metrics with correct properties',
        () {
          final counter = meter.createObservableCounter<int>(
            name: 'exported_counter',
            unit: 'requests',
            description: 'A counter for exported metrics',
            callback: (APIObservableResult<int> result) {
              result.observe(500);
            },
          ) as ObservableCounter<int>;

          counter.collect();

          final metrics = counter.collectMetrics();
          expect(metrics, isNotEmpty);

          final counterMetric = metrics.first;
          expect(counterMetric.type, equals(MetricType.sum));
          expect(counterMetric.name, equals('exported_counter'));
          expect(counterMetric.unit, equals('requests'));
          expect(
            counterMetric.description,
            equals('A counter for exported metrics'),
          );
          expect(counterMetric.points.isNotEmpty, isTrue);
          expect(counterMetric.points.first.value, equals(500));
        },
      );

      test(
        'ObservableGauge collection returns metrics with correct properties',
        () {
          final gauge = meter.createObservableGauge<double>(
            name: 'exported_gauge',
            unit: 'percent',
            description: 'A gauge for exported metrics',
            callback: (APIObservableResult<double> result) {
              result.observe(87.5);
            },
          ) as ObservableGauge<double>;

          gauge.collect();

          final metrics = gauge.collectMetrics();
          expect(metrics, isNotEmpty);

          final gaugeMetric = metrics.first;
          expect(gaugeMetric.type, equals(MetricType.gauge));
          expect(gaugeMetric.name, equals('exported_gauge'));
          expect(gaugeMetric.unit, equals('percent'));
          expect(
            gaugeMetric.description,
            equals('A gauge for exported metrics'),
          );
          expect(gaugeMetric.points.isNotEmpty, isTrue);
          expect(gaugeMetric.points.first.value, closeTo(87.5, 0.001));
        },
      );

      test(
        'ObservableUpDownCounter collection returns metrics with correct properties',
        () {
          final counter = meter.createObservableUpDownCounter<int>(
            name: 'exported_updown',
            unit: 'connections',
            description: 'An up-down counter for exported metrics',
            callback: (APIObservableResult<int> result) {
              result.observe(42);
            },
          ) as ObservableUpDownCounter<int>;

          counter.collect();

          final metrics = counter.collectMetrics();
          expect(metrics, isNotEmpty);

          final updownMetric = metrics.first;
          expect(updownMetric.type, equals(MetricType.sum));
          expect(updownMetric.name, equals('exported_updown'));
          expect(updownMetric.unit, equals('connections'));
          expect(
            updownMetric.description,
            equals('An up-down counter for exported metrics'),
          );
          expect(updownMetric.points.isNotEmpty, isTrue);
          expect(updownMetric.points.first.value, equals(42));
        },
      );
    });
  });
}
