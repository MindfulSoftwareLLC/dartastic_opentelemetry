// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('ObservableGauge Tests', () {
    late MeterProvider meterProvider;
    late Meter meter;

    setUp(() async {
      // Initialize OpenTelemetry with test endpoint to avoid network issues
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        endpoint: 'http://localhost:4317',
        detectPlatformResources: false, // Disable for testing
      );

      // Get a meter provider and create a meter
      meterProvider = OTel.meterProvider();
      meter = meterProvider.getMeter(name: 'test-meter') as Meter;
    });

    tearDown(() async {
      // Clean up
      await meterProvider.shutdown();
      await OTel.reset();
    });

    test('Simple ObservableGauge with single callback', () {
      // Variable to simulate a gauge value that changes over time
      double gaugeValue = 25.5;

      // Create an ObservableGauge with double type
      final gauge = meter.createObservableGauge<double>(
        name: 'test-observable-gauge',
        unit: 'celsius',
        description: 'A test observable gauge',
        callback: (APIObservableResult<double> result) {
          result.observe(gaugeValue);
          gaugeValue += 1.5; // Change value for next observation
        },
      ) as ObservableGauge<double>;

      // Verify instrument properties
      expect(gauge.name, equals('test-observable-gauge'));
      expect(gauge.unit, equals('celsius'));
      expect(gauge.description, equals('A test observable gauge'));
      expect(gauge.enabled, isTrue);
      expect(gauge.meter, equals(meter));

      // Verify callbacks were registered
      expect(gauge.callbacks.length, equals(1));

      // Collect measurements
      final measurements = gauge.collect();
      expect(measurements.length, equals(1));
      expect(measurements[0].value, equals(25.5)); // First observation

      // Collect again
      final measurements2 = gauge.collect();
      expect(measurements2.length, equals(1));
      expect(measurements2[0].value, equals(27.0)); // New value

      // Collect metrics
      final metrics = gauge.collectMetrics();
      expect(metrics.length, equals(1));

      // Verify this is a gauge metric with the correct properties
      expect(metrics[0].type, equals(MetricType.gauge));

      // Verify the points
      expect(metrics[0].points.length, equals(1));
      expect(metrics[0].points[0].value, equals(27.0)); // Latest value
    });

    test('ObservableGauge with attributes', () {
      // Create sets of attributes
      final attributes1 = {'location': 'outside'}.toAttributes();
      final attributes2 = {'location': 'inside'}.toAttributes();

      // Create value maps to simulate changing gauge values
      final Map<String, double> temperatures = {
        'outside': 22.5,
        'inside': 24.8,
      };

      // Create an ObservableGauge
      final gauge = meter.createObservableGauge<double>(
        name: 'attr-observable-gauge',
        unit: 'celsius',
        callback: (APIObservableResult<double> result) {
          // Report both values
          result.observe(temperatures['outside']!, attributes1);
          result.observe(temperatures['inside']!, attributes2);

          // Change values for next observation
          temperatures['outside'] = temperatures['outside']! + 0.5;
          temperatures['inside'] = temperatures['inside']! - 0.2;
        },
      ) as ObservableGauge<double>;

      // First collection
      final measurements1 = gauge.collect();
      expect(measurements1.length, equals(2));

      // Values should match our initial values
      expect(
          measurements1.where((m) => m.attributes == attributes1).first.value,
          closeTo(22.5, 0.001));
      expect(
          measurements1.where((m) => m.attributes == attributes2).first.value,
          closeTo(24.8, 0.001));

      // Second collection
      final measurements2 = gauge.collect();
      expect(measurements2.length, equals(2));

      // Values should reflect the changes
      expect(
          measurements2.where((m) => m.attributes == attributes1).first.value,
          closeTo(23.0, 0.001));
      expect(
          measurements2.where((m) => m.attributes == attributes2).first.value,
          closeTo(24.6, 0.001));

      // Get metric points
      final metrics = gauge.collectMetrics();
      expect(metrics.length, equals(1));

      expect(metrics[0].type, equals(MetricType.gauge));
      expect(metrics[0].points.length, equals(2));

      // Points should have the latest values
      final point1 =
          metrics[0].points.where((p) => p.attributes == attributes1).first;
      final point2 =
          metrics[0].points.where((p) => p.attributes == attributes2).first;
      expect(point1.value, closeTo(23.0, 0.001));
      expect(point2.value, closeTo(24.6, 0.001));

      // third collection
      final measurements3 = gauge.collect();
      expect(measurements3.length, equals(2));

      // Values should reflect the changes
      expect(
          measurements3.where((m) => m.attributes == attributes1).first.value,
          closeTo(23.5, 0.001));
      expect(
          measurements3.where((m) => m.attributes == attributes2).first.value,
          closeTo(24.4, 0.001));
    });

    test('ObservableGauge with multiple callbacks', () {
      // Create an ObservableGauge without initial callback
      final gauge = meter.createObservableGauge<double>(
        name: 'multi-callback-gauge',
        unit: 'percent',
      ) as ObservableGauge<double>;

      // First callback
      double cpu1Usage = 45.2;
      final attributes1 = {'cpu': 'cpu0'}.toAttributes();
      final registration1 =
          gauge.addCallback((APIObservableResult<double> result) {
        result.observe(cpu1Usage, attributes1);
        cpu1Usage = (cpu1Usage + 5.5) % 100; // Cycle between 0-100%
      });

      // Second callback
      double cpu2Usage = 67.8;
      final attributes2 = {'cpu': 'cpu1'}.toAttributes();
      final registration2 =
          gauge.addCallback((APIObservableResult<double> result) {
        result.observe(cpu2Usage, attributes2);
        cpu2Usage = (cpu2Usage - 3.2) % 100; // Cycle between 0-100%
      });

      // Verify both callbacks are registered
      expect(gauge.callbacks.length, equals(2));

      // First collection should have both values
      final measurements1 = gauge.collect();
      expect(measurements1.length, equals(2));
      expect(
          measurements1.where((m) => m.attributes == attributes1).first.value,
          closeTo(45.2, 0.001));
      expect(
          measurements1.where((m) => m.attributes == attributes2).first.value,
          closeTo(67.8, 0.001));

      // Second collection should have updated values
      final measurements2 = gauge.collect();
      expect(measurements2.length, equals(2));
      expect(
          measurements2.where((m) => m.attributes == attributes1).first.value,
          closeTo(50.7, 0.001));
      expect(
          measurements2.where((m) => m.attributes == attributes2).first.value,
          closeTo(64.6, 0.001));

      // Unregister first callback
      registration1.unregister();
      expect(gauge.callbacks.length, equals(1));

      // Collection should now only have the second callback's value
      final measurements3 = gauge.collect();
      expect(measurements3.length, equals(1));
      expect(measurements3[0].attributes, equals(attributes2));
      expect(measurements3[0].value, closeTo(61.4, 0.001));

      // Unregister second callback
      registration2.unregister();
      expect(gauge.callbacks.length, equals(0));

      // Collection should now be empty
      final measurements4 = gauge.collect();
      expect(measurements4.length, equals(0));
    });

    test('ObservableGauge collectMetrics', () {
      // Create a gauge
      double value = 98.6;
      bool decreasing = false;

      final gauge = meter.createObservableGauge<double>(
        name: 'metrics-gauge',
        unit: 'fahrenheit',
        description: 'Test metrics collection',
        callback: (APIObservableResult<double> result) {
          result.observe(value);
          // Oscillate the value
          if (decreasing) {
            value -= 0.3;
            if (value < 97.5) decreasing = false;
          } else {
            value += 0.3;
            if (value > 99.5) decreasing = true;
          }
        },
      ) as ObservableGauge<double>;

      // Trigger collection
      gauge.collect();

      // Get metrics
      final metrics = gauge.collectMetrics();
      expect(metrics.length, equals(1));

      // Verify metric properties
      final metric = metrics[0];
      expect(metric.name, equals('metrics-gauge'));
      expect(metric.description, equals('Test metrics collection'));
      expect(metric.unit, equals('fahrenheit'));

      // Verify this is a gauge metric
      expect(metric.type, equals(MetricType.gauge));

      // Verify the points
      expect(metric.points.length, equals(1));
      expect(metric.points[0].value, closeTo(98.6, 0.001));

      // Second collection - check the new value
      gauge.collect();
      final metrics2 = gauge.collectMetrics();
      expect(metrics2[0].points[0].value,
          closeTo(98.9, 0.001));
    });

    test('ObservableGauge with disabled meter', () {
      // Create a gauge
      int callCount = 0;
      final double value = 42.0;

      final gauge = meter.createObservableGauge<double>(
        name: 'disabled-gauge',
        callback: (APIObservableResult<double> result) {
          callCount++;
          result.observe(value);
        },
      ) as ObservableGauge<double>;

      // Verify it's enabled initially
      expect(gauge.enabled, isTrue);

      // Collect while enabled
      final measurements = gauge.collect();
      expect(measurements.length, equals(1));
      expect(callCount, equals(1));

      // Disable the meter provider
      meterProvider.enabled = false;
      expect(gauge.enabled, isFalse);

      // Collect while disabled - callback shouldn't be called
      final measurements2 = gauge.collect();
      expect(measurements2.length, equals(0)); // No measurements when disabled
      expect(callCount, equals(1)); // Counter wasn't incremented

      // Metrics collection should also respect disabled state
      final metrics = gauge.collectMetrics();
      expect(metrics.length, equals(0));
    });

    test('ObservableGauge with different numeric types', () {
      // Create an integer gauge
      final intGauge = meter.createObservableGauge<int>(
        name: 'int-gauge',
        unit: 'count',
        callback: (APIObservableResult<int> result) {
          result.observe(42);
        },
      ) as ObservableGauge<int>;

      // Create a double gauge
      final doubleGauge = meter.createObservableGauge<double>(
        name: 'double-gauge',
        unit: 'percentage',
        callback: (APIObservableResult<double> result) {
          result.observe(99.9);
        },
      ) as ObservableGauge<double>;

      // Collect from both
      final intMeasurements = intGauge.collect();
      final doubleMeasurements = doubleGauge.collect();

      // Verify the values maintain their types
      expect(intMeasurements[0].value, equals(42));
      expect(intMeasurements[0].value, isA<int>());
      expect(doubleMeasurements[0].value, equals(99.9));
      expect(doubleMeasurements[0].value, isA<double>());

      // Verify metrics collection
      final intMetrics = intGauge.collectMetrics();
      final doubleMetrics = doubleGauge.collectMetrics();

      expect(intMetrics[0].points[0].value, equals(42));
      expect(doubleMetrics[0].points[0].value, equals(99.9));
    });

    test('ObservableGauge with exceptions in callbacks', () {
      // Create a gauge with a callback that throws an exception
      bool callbackThrows = true;

      final gauge = meter.createObservableGauge<double>(
        name: 'exception-gauge',
        callback: (APIObservableResult<double> result) {
          if (callbackThrows) {
            throw Exception('Simulated error in gauge callback');
          }
          result.observe(123.45);
        },
      ) as ObservableGauge<double>;

      // First collection with exception
      // The SDK should handle exceptions gracefully and not crash
      final measurements1 = gauge.collect();
      expect(
          measurements1.length, equals(0)); // No measurements due to exception

      // Fix the callback and collect again
      callbackThrows = false;
      final measurements2 = gauge.collect();
      expect(measurements2.length, equals(1));
      expect(measurements2[0].value, equals(123.45));
    });

    test('ObservableGauge state clearing', () async {
      // Create a gauge
      double value = 50.0;

      final gauge = meter.createObservableGauge<double>(
        name: 'clear-gauge',
        callback: (APIObservableResult<double> result) {
          result.observe(value);
          value += 10.0;
        },
      ) as ObservableGauge<double>;

      // First collection
      gauge.collect();

      // Verify point exists
      final metrics1 = gauge.collectMetrics();
      expect(metrics1[0].points.length, equals(1));
      expect(metrics1[0].points[0].value, equals(50.0));

      // Second collection - should get the new value
      gauge.collect();
      final metrics2 = gauge.collectMetrics();
      expect(metrics2[0].points.length, equals(1));
      expect(metrics2[0].points[0].value, equals(60.0)); // 50.0 + 10.0 = 60.0

      // Shutdown the meter provider (should clear internal state)
      await meterProvider.shutdown();

      // Recreate environment
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        endpoint: 'http://localhost:4317',
        detectPlatformResources: false,
      );
      meterProvider = OTel.meterProvider();
      meter = meterProvider.getMeter(name: 'test-meter') as Meter;

      // Create a new gauge
      final newGauge = meter.createObservableGauge<double>(
        name: 'clear-gauge',
        callback: (APIObservableResult<double> result) {
          result.observe(100.0);
        },
      ) as ObservableGauge<double>;

      // Collect
      newGauge.collect();
      final metrics3 = newGauge.collectMetrics();
      expect(metrics3[0].points.length, equals(1));
      expect(metrics3[0].points[0].value, equals(100.0));
    });
  });
}
