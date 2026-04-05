// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('Observable Instruments Full Coverage Tests', () {
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
      OTelLog.metricLogFunction = null;
      await OTel.shutdown();
      await OTel.reset();
    });

    group('ObservableCounter properties', () {
      test('name returns correct name', () {
        final counter = meter.createObservableCounter<int>(
          name: 'prop_counter',
          unit: 'items',
          description: 'A test counter',
        ) as ObservableCounter<int>;

        expect(counter.name, equals('prop_counter'));
        expect(counter.unit, equals('items'));
        expect(counter.description, equals('A test counter'));
        expect(counter.enabled, isTrue);
        expect(counter.meter, equals(meter));
      });

      test('callbacks list starts empty when no initial callback', () {
        final counter = meter.createObservableCounter<int>(
            name: 'empty_callbacks_counter') as ObservableCounter<int>;
        expect(counter.callbacks, isEmpty);
      });

      test('collect returns empty when disabled', () {
        final counter = meter.createObservableCounter<int>(
          name: 'disabled_counter',
          callback: (result) => result.observe(10),
        ) as ObservableCounter<int>;

        meterProvider.enabled = false;

        final measurements = counter.collect();
        expect(measurements, isEmpty);

        meterProvider.enabled = true;
      });

      test('collectMetrics returns empty when disabled', () {
        final counter = meter.createObservableCounter<int>(
          name: 'disabled_metrics_counter',
          callback: (result) => result.observe(10),
        ) as ObservableCounter<int>;

        counter.collect();
        meterProvider.enabled = false;

        final metrics = counter.collectMetrics();
        expect(metrics, isEmpty);

        meterProvider.enabled = true;
      });

      test('collectPoints returns empty when disabled', () {
        final counter = meter.createObservableCounter<int>(
          name: 'disabled_points_counter',
          callback: (result) => result.observe(10),
        ) as ObservableCounter<int>;

        meterProvider.enabled = false;

        final points = counter.collectPoints();
        expect(points, isEmpty);

        meterProvider.enabled = true;
      });

      test('collectMetrics returns empty when no data collected', () {
        final counter = meter.createObservableCounter<int>(
            name: 'no_data_counter') as ObservableCounter<int>;

        final metrics = counter.collectMetrics();
        expect(metrics, isEmpty);
      });
    });

    group('ObservableCounter callback management', () {
      test('addCallback and unregister', () {
        final counter = meter.createObservableCounter<int>(
            name: 'unreg_counter') as ObservableCounter<int>;

        final registration = counter.addCallback((result) {
          result.observe(100);
        });

        expect(counter.callbacks, hasLength(1));

        registration.unregister();

        expect(counter.callbacks, isEmpty);
      });

      test('multiple registrations and selective unregister', () {
        final counter = meter.createObservableCounter<int>(
            name: 'multi_reg_counter') as ObservableCounter<int>;

        final reg1 = counter.addCallback((result) {
          result.observe(10);
        });
        counter.addCallback((result) {
          result.observe(20);
        });

        expect(counter.callbacks, hasLength(2));

        reg1.unregister();

        expect(counter.callbacks, hasLength(1));

        // Collect should only get the second callback
        final measurements = counter.collect();
        expect(measurements, hasLength(1));
        expect(measurements.first.value, equals(20));
      });

      test('removeCallback removes callback directly', () {
        final counter = meter.createObservableCounter<int>(
            name: 'remove_cb_counter') as ObservableCounter<int>;

        void myCallback(APIObservableResult<int> result) {
          result.observe(42);
        }

        counter.addCallback(myCallback);
        expect(counter.callbacks, hasLength(1));

        counter.removeCallback(myCallback);
        expect(counter.callbacks, isEmpty);
      });
    });

    group('ObservableCounter error handling', () {
      test('error in callback does not prevent other callbacks', () {
        final counter = meter.createObservableCounter<int>(
            name: 'error_cb_counter') as ObservableCounter<int>;

        counter.addCallback((result) {
          throw Exception('Callback error');
        });
        counter.addCallback((result) {
          result.observe(42);
        });

        final measurements = counter.collect();
        expect(measurements, hasLength(1));
        expect(measurements.first.value, equals(42));
      });

      test('collect returns empty when no callbacks', () {
        final counter = meter.createObservableCounter<int>(
            name: 'no_cb_counter') as ObservableCounter<int>;

        final measurements = counter.collect();
        expect(measurements, isEmpty);
      });
    });

    group('ObservableCounter monotonicity', () {
      test('counter reset detection - value decreased', () {
        int callCount = 0;

        final counter = meter.createObservableCounter<int>(
          name: 'reset_counter',
          callback: (result) {
            callCount++;
            if (callCount == 1) {
              result.observe(100);
            } else {
              // Simulate reset - value drops
              result.observe(10);
            }
          },
        ) as ObservableCounter<int>;

        // First collection
        var measurements = counter.collect();
        expect(measurements, hasLength(1));
        expect(measurements.first.value, equals(100));

        // Second collection - reset detected
        measurements = counter.collect();
        expect(measurements, hasLength(1));
        expect(measurements.first.value, equals(10));
      });

      test('zero delta not included in measurements', () {
        final counter = meter.createObservableCounter<int>(
          name: 'zero_delta_counter',
          callback: (result) {
            result.observe(50); // Always same value
          },
        ) as ObservableCounter<int>;

        // First collection - new value
        var measurements = counter.collect();
        expect(measurements, hasLength(1));
        expect(measurements.first.value, equals(50));

        // Second collection - same value, zero delta
        measurements = counter.collect();
        expect(measurements, isEmpty);

        // Still in storage though
        final points = counter.collectPoints();
        expect(points, isNotEmpty);
      });

      test('getValue with no attributes sums all points', () {
        final counter = meter.createObservableCounter<int>(
          name: 'sum_all_counter',
          callback: (result) {
            result.observe(10, {'region': 'us'}.toAttributes());
            result.observe(20, {'region': 'eu'}.toAttributes());
          },
        ) as ObservableCounter<int>;

        counter.collect();
        final total = counter.getValue();
        expect(total, equals(30));
      });

      test('getValue with specific attributes', () {
        final attrs = {'region': 'us'}.toAttributes();

        final counter = meter.createObservableCounter<int>(
          name: 'specific_attr_counter',
          callback: (result) {
            result.observe(10, attrs);
            result.observe(20, {'region': 'eu'}.toAttributes());
          },
        ) as ObservableCounter<int>;

        counter.collect();
        final value = counter.getValue(attrs);
        expect(value, equals(10));
      });

      test('reset clears all state', () {
        final counter = meter.createObservableCounter<int>(
          name: 'reset_state_counter',
          callback: (result) => result.observe(100),
        ) as ObservableCounter<int>;

        counter.collect();
        expect(counter.collectPoints(), isNotEmpty);

        counter.reset();
        expect(counter.collectPoints(), isEmpty);
      });
    });

    group('ObservableCounter with double type', () {
      test('double counter records and collects', () {
        final counter = meter.createObservableCounter<double>(
          name: 'double_counter',
          callback: (result) {
            result.observe(1.5);
          },
        ) as ObservableCounter<double>;

        final measurements = counter.collect();
        expect(measurements, hasLength(1));
        expect(measurements.first.value, equals(1.5));

        final metrics = counter.collectMetrics();
        expect(metrics, isNotEmpty);
        expect(metrics.first.type, equals(MetricType.sum));
        expect(metrics.first.isMonotonic, isTrue);
      });

      test('double getValue with attributes', () {
        final attrs = {'key': 'val'}.toAttributes();
        final counter = meter.createObservableCounter<double>(
          name: 'double_attr_counter',
          callback: (result) {
            result.observe(3.14, attrs);
          },
        ) as ObservableCounter<double>;

        counter.collect();
        final value = counter.getValue(attrs);
        expect(value, closeTo(3.14, 0.001));
      });
    });

    group('ObservableUpDownCounter properties', () {
      test('name, unit, description, enabled, meter', () {
        final counter = meter.createObservableUpDownCounter<int>(
          name: 'prop_updown',
          unit: 'connections',
          description: 'Active connections',
        ) as ObservableUpDownCounter<int>;

        expect(counter.name, equals('prop_updown'));
        expect(counter.unit, equals('connections'));
        expect(counter.description, equals('Active connections'));
        expect(counter.enabled, isTrue);
        expect(counter.meter, equals(meter));
      });

      test('collect returns empty when disabled', () {
        final counter = meter.createObservableUpDownCounter<int>(
          name: 'disabled_updown',
          callback: (result) => result.observe(5),
        ) as ObservableUpDownCounter<int>;

        meterProvider.enabled = false;

        final measurements = counter.collect();
        expect(measurements, isEmpty);

        meterProvider.enabled = true;
      });

      test('collectMetrics returns empty when disabled', () {
        final counter = meter.createObservableUpDownCounter<int>(
          name: 'disabled_updown_metrics',
          callback: (result) => result.observe(5),
        ) as ObservableUpDownCounter<int>;

        counter.collect();
        meterProvider.enabled = false;

        final metrics = counter.collectMetrics();
        expect(metrics, isEmpty);

        meterProvider.enabled = true;
      });

      test('collectPoints returns empty when disabled', () {
        final counter = meter.createObservableUpDownCounter<int>(
          name: 'disabled_updown_points',
          callback: (result) => result.observe(5),
        ) as ObservableUpDownCounter<int>;

        meterProvider.enabled = false;

        final points = counter.collectPoints();
        expect(points, isEmpty);

        meterProvider.enabled = true;
      });

      test('collectMetrics returns empty when no data', () {
        final counter = meter.createObservableUpDownCounter<int>(
            name: 'no_data_updown') as ObservableUpDownCounter<int>;

        final metrics = counter.collectMetrics();
        expect(metrics, isEmpty);
      });
    });

    group('ObservableUpDownCounter callback management', () {
      test('addCallback and unregister', () {
        final counter = meter.createObservableUpDownCounter<int>(
            name: 'unreg_updown') as ObservableUpDownCounter<int>;

        final registration = counter.addCallback((result) {
          result.observe(10);
        });

        expect(counter.callbacks, hasLength(1));

        registration.unregister();

        expect(counter.callbacks, isEmpty);
      });

      test('removeCallback directly', () {
        final counter = meter.createObservableUpDownCounter<int>(
            name: 'remove_cb_updown') as ObservableUpDownCounter<int>;

        void myCallback(APIObservableResult<int> result) {
          result.observe(7);
        }

        counter.addCallback(myCallback);
        expect(counter.callbacks, hasLength(1));

        counter.removeCallback(myCallback);
        expect(counter.callbacks, isEmpty);
      });
    });

    group('ObservableUpDownCounter error handling', () {
      test('error in callback does not prevent other callbacks', () {
        final counter = meter.createObservableUpDownCounter<int>(
            name: 'error_updown') as ObservableUpDownCounter<int>;

        counter.addCallback((result) {
          throw Exception('Callback error');
        });
        counter.addCallback((result) {
          result.observe(42);
        });

        final measurements = counter.collect();
        expect(measurements, hasLength(1));
        expect(measurements.first.value, equals(42));
      });

      test('collect returns empty when no callbacks', () {
        final counter = meter.createObservableUpDownCounter<int>(
            name: 'no_cb_updown') as ObservableUpDownCounter<int>;

        final measurements = counter.collect();
        expect(measurements, isEmpty);
      });
    });

    group('ObservableUpDownCounter value tracking', () {
      test('getValue with no attributes sums all points', () {
        final counter = meter.createObservableUpDownCounter<int>(
          name: 'sum_all_updown',
          callback: (result) {
            result.observe(10, {'pool': 'a'}.toAttributes());
            result.observe(-5, {'pool': 'b'}.toAttributes());
          },
        ) as ObservableUpDownCounter<int>;

        counter.collect();
        final total = counter.getValue();
        expect(total, equals(5));
      });

      test('getValue with specific attributes', () {
        final attrs = {'pool': 'workers'}.toAttributes();

        final counter = meter.createObservableUpDownCounter<int>(
          name: 'specific_updown',
          callback: (result) {
            result.observe(15, attrs);
          },
        ) as ObservableUpDownCounter<int>;

        counter.collect();
        final value = counter.getValue(attrs);
        expect(value, equals(15));
      });

      test('reset clears all state', () {
        final counter = meter.createObservableUpDownCounter<int>(
          name: 'reset_updown',
          callback: (result) => result.observe(50),
        ) as ObservableUpDownCounter<int>;

        counter.collect();
        expect(counter.collectPoints(), isNotEmpty);

        counter.reset();
        expect(counter.collectPoints(), isEmpty);
      });

      test('collectMetrics has correct properties', () {
        final counter = meter.createObservableUpDownCounter<int>(
          name: 'metrics_updown',
          unit: 'connections',
          description: 'Pool connections',
          callback: (result) => result.observe(25),
        ) as ObservableUpDownCounter<int>;

        counter.collect();
        final metrics = counter.collectMetrics();
        expect(metrics, hasLength(1));

        final m = metrics.first;
        expect(m.type, equals(MetricType.sum));
        expect(m.name, equals('metrics_updown'));
        expect(m.isMonotonic, isFalse);
        expect(m.temporality, equals(AggregationTemporality.cumulative));
      });
    });

    group('ObservableUpDownCounter with double type', () {
      test('double updown counter records and collects', () {
        final counter = meter.createObservableUpDownCounter<double>(
          name: 'double_updown',
          callback: (result) {
            result.observe(-3.5);
          },
        ) as ObservableUpDownCounter<double>;

        final measurements = counter.collect();
        expect(measurements, hasLength(1));
        expect(measurements.first.value, equals(-3.5));
      });

      test('double getValue', () {
        final attrs = {'key': 'val'}.toAttributes();
        final counter = meter.createObservableUpDownCounter<double>(
          name: 'double_val_updown',
          callback: (result) {
            result.observe(2.718, attrs);
          },
        ) as ObservableUpDownCounter<double>;

        counter.collect();
        final value = counter.getValue(attrs);
        expect(value, closeTo(2.718, 0.001));
      });
    });

    group('ObservableGauge properties', () {
      test('name, unit, description, enabled, meter', () {
        final gauge = meter.createObservableGauge<double>(
          name: 'prop_gauge',
          unit: 'celsius',
          description: 'Temperature reading',
        ) as ObservableGauge<double>;

        expect(gauge.name, equals('prop_gauge'));
        expect(gauge.unit, equals('celsius'));
        expect(gauge.description, equals('Temperature reading'));
        expect(gauge.enabled, isTrue);
        expect(gauge.meter, equals(meter));
      });

      test('collect returns empty when disabled', () {
        final gauge = meter.createObservableGauge<double>(
          name: 'disabled_gauge',
          callback: (result) => result.observe(10.0),
        ) as ObservableGauge<double>;

        meterProvider.enabled = false;

        final measurements = gauge.collect();
        expect(measurements, isEmpty);

        meterProvider.enabled = true;
      });

      test('collectMetrics returns empty when disabled', () {
        final gauge = meter.createObservableGauge<double>(
          name: 'disabled_gauge_metrics',
          callback: (result) => result.observe(10.0),
        ) as ObservableGauge<double>;

        gauge.collect();
        meterProvider.enabled = false;

        final metrics = gauge.collectMetrics();
        expect(metrics, isEmpty);

        meterProvider.enabled = true;
      });

      test('collectPoints returns empty when disabled', () {
        final gauge = meter.createObservableGauge<double>(
          name: 'disabled_gauge_points',
          callback: (result) => result.observe(10.0),
        ) as ObservableGauge<double>;

        meterProvider.enabled = false;

        final points = gauge.collectPoints();
        expect(points, isEmpty);

        meterProvider.enabled = true;
      });

      test('collectMetrics returns empty when no data', () {
        final gauge = meter.createObservableGauge<double>(name: 'no_data_gauge')
            as ObservableGauge<double>;

        final metrics = gauge.collectMetrics();
        expect(metrics, isEmpty);
      });
    });

    group('ObservableGauge callback management', () {
      test('addCallback and unregister', () {
        final gauge = meter.createObservableGauge<double>(name: 'unreg_gauge')
            as ObservableGauge<double>;

        final registration = gauge.addCallback((result) {
          result.observe(99.9);
        });

        expect(gauge.callbacks, hasLength(1));

        registration.unregister();

        expect(gauge.callbacks, isEmpty);
      });

      test('removeCallback directly', () {
        final gauge = meter.createObservableGauge<double>(
            name: 'remove_cb_gauge') as ObservableGauge<double>;

        void myCallback(APIObservableResult<double> result) {
          result.observe(55.5);
        }

        gauge.addCallback(myCallback);
        expect(gauge.callbacks, hasLength(1));

        gauge.removeCallback(myCallback);
        expect(gauge.callbacks, isEmpty);
      });
    });

    group('ObservableGauge error handling', () {
      test('error in callback does not prevent other callbacks', () {
        final gauge = meter.createObservableGauge<double>(name: 'error_gauge')
            as ObservableGauge<double>;

        gauge.addCallback((result) {
          throw Exception('Callback error');
        });
        gauge.addCallback((result) {
          result.observe(77.7);
        });

        final measurements = gauge.collect();
        expect(measurements, hasLength(1));
        expect(measurements.first.value, closeTo(77.7, 0.001));
      });

      test('collect returns empty list when no callbacks', () {
        final gauge = meter.createObservableGauge<double>(name: 'no_cb_gauge')
            as ObservableGauge<double>;

        final measurements = gauge.collect();
        expect(measurements, isEmpty);
      });
    });

    group('ObservableGauge value tracking', () {
      test('getValue with no attributes averages all points', () {
        final gauge = meter.createObservableGauge<double>(
          name: 'avg_gauge',
          callback: (result) {
            result.observe(10.0, {'host': 'a'}.toAttributes());
            result.observe(20.0, {'host': 'b'}.toAttributes());
          },
        ) as ObservableGauge<double>;

        gauge.collect();
        final avg = gauge.getValue();
        expect(avg, closeTo(15.0, 0.001));
      });

      test('getValue with no points returns 0', () {
        final gauge = meter.createObservableGauge<double>(name: 'empty_gauge')
            as ObservableGauge<double>;

        final value = gauge.getValue();
        expect(value, equals(0.0));
      });

      test('getValue with specific attributes', () {
        final attrs = {'host': 'server1'}.toAttributes();

        final gauge = meter.createObservableGauge<double>(
          name: 'specific_gauge',
          callback: (result) {
            result.observe(42.0, attrs);
          },
        ) as ObservableGauge<double>;

        gauge.collect();
        final value = gauge.getValue(attrs);
        expect(value, equals(42.0));
      });

      test('collectMetrics has correct properties', () {
        final gauge = meter.createObservableGauge<double>(
          name: 'metrics_gauge',
          unit: 'percent',
          description: 'CPU usage',
          callback: (result) => result.observe(65.0),
        ) as ObservableGauge<double>;

        gauge.collect();
        final metrics = gauge.collectMetrics();
        expect(metrics, hasLength(1));

        final m = metrics.first;
        expect(m.type, equals(MetricType.gauge));
        expect(m.name, equals('metrics_gauge'));
        expect(m.unit, equals('percent'));
        expect(m.description, equals('CPU usage'));
      });
    });

    group('ObservableGauge with int type', () {
      test('int gauge records and collects', () {
        final gauge = meter.createObservableGauge<int>(
          name: 'int_gauge',
          callback: (result) {
            result.observe(42);
          },
        ) as ObservableGauge<int>;

        final measurements = gauge.collect();
        expect(measurements, hasLength(1));
        expect(measurements.first.value, equals(42));
      });

      test('int getValue with no attributes', () {
        final gauge = meter.createObservableGauge<int>(
          name: 'int_avg_gauge',
          callback: (result) {
            result.observe(10, {'k': 'a'}.toAttributes());
            result.observe(20, {'k': 'b'}.toAttributes());
          },
        ) as ObservableGauge<int>;

        gauge.collect();
        final avg = gauge.getValue();
        // int average of 10 and 20 = 15
        expect(avg, equals(15));
      });

      test('int getValue with specific attributes', () {
        final attrs = {'sensor': 'temp'}.toAttributes();
        final gauge = meter.createObservableGauge<int>(
          name: 'int_specific_gauge',
          callback: (result) {
            result.observe(99, attrs);
          },
        ) as ObservableGauge<int>;

        gauge.collect();
        final value = gauge.getValue(attrs);
        expect(value, equals(99));
      });
    });
  });
}
