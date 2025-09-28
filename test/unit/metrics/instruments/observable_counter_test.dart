// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('ObservableCounter Tests', () {
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
      await OTel.shutdown();
    });

    test('Simple ObservableCounter with single callback', () {
      // Initial value
      int observedValue = 0;

      // Create an ObservableCounter with int type
      final counter = meter.createObservableCounter<int>(
        name: 'test-observable-counter',
        unit: 'items',
        description: 'A test observable counter',
        callback: (APIObservableResult<int> result) {
          observedValue += 10; // Simulate increasing value
          result.observe(observedValue);
        },
      ) as ObservableCounter<int>;

      // Verify instrument properties
      expect(counter.name, equals('test-observable-counter'));
      expect(counter.unit, equals('items'));
      expect(counter.description, equals('A test observable counter'));
      expect(counter.enabled, isTrue);
      expect(counter.meter, equals(meter));

      // Verify callbacks were registered
      expect(counter.callbacks.length, equals(1));

      // Collect measurements
      final measurements = counter.collect();
      expect(measurements.length, equals(1));
      expect(measurements[0].value, equals(10)); // First observation

      // Collect again to verify delta calculation
      final measurements2 = counter.collect();
      expect(measurements2.length, equals(1));
      expect(measurements2[0].value, equals(20)); // +10

      // Collect metrics points
      final points = counter.collectPoints();
      expect(points.length, equals(1));
      expect(points[0].value, equals(20)); // Same, 20

      // Reset counter
      counter.reset();

      // Collect after reset
      final measurements3 = counter.collect();
      expect(measurements3.length, equals(1));
      expect(measurements3[0].value, equals(30)); // New absolute value
    });

    test('ObservableCounter with attributes', () {
      // Create sets of attributes
      final attributes1 = {'service': 'api'}.toAttributes();
      final attributes2 = {'service': 'db'}.toAttributes();

      // Create value maps to simulate increasing values
      final Map<Attributes, int> observedValues = {};

      // Create an ObservableCounter
      final counter = meter.createObservableCounter<int>(
        name: 'attr-observable-counter',
        unit: 'items',
        callback: (APIObservableResult<int> result) {
          // Initialize or increment values
          observedValues[attributes1] = (observedValues[attributes1] ?? 0) + 5;
          observedValues[attributes2] = (observedValues[attributes2] ?? 0) + 3;

          // Report both values
          result.observe(observedValues[attributes1]!, attributes1);
          result.observe(observedValues[attributes2]!, attributes2);
        },
      ) as ObservableCounter<int>;

      // First collection
      final measurements1 = counter.collect();
      expect(measurements1.length, equals(2));

      // Values should match our initial increments (delta calculation doesn't apply to first observation)
      expect(
          measurements1.where((m) => m.attributes == attributes1).first.value,
          equals(5));
      expect(
          measurements1.where((m) => m.attributes == attributes2).first.value,
          equals(3));

      // Second collection
      final measurements2 = counter.collect();
      expect(measurements2.length, equals(2));

      // Values should be the deltas of the second observation
      expect(
          measurements2.where((m) => m.attributes == attributes1).first.value,
          equals(10));
      expect(
          measurements2.where((m) => m.attributes == attributes2).first.value,
          equals(6));

      // Get metric points (cumulative)
      final points = counter.collectPoints();
      expect(points.length, equals(2));

      // Points should still have cumulative values
      expect(points.where((p) => p.attributes == attributes1).first.value,
          equals(10));
      expect(points.where((p) => p.attributes == attributes2).first.value,
          equals(6));
    });

    test('ObservableCounter with multiple callbacks', () {
      // Create an ObservableCounter without initial callback
      final counter = meter.createObservableCounter<int>(
        name: 'multi-callback-counter',
        unit: 'calls',
      ) as ObservableCounter<int>;

      // First callback
      int callback1Value = 100;
      final attributes1 = {'source': 'callback1'}.toAttributes();
      final registration1 =
          counter.addCallback((APIObservableResult<int> result) {
        result.observe(callback1Value, attributes1);
        callback1Value += 50; // Increment for next call
      });

      // Second callback
      int callback2Value = 200;
      final attributes2 = {'source': 'callback2'}.toAttributes();
      final registration2 =
          counter.addCallback((APIObservableResult<int> result) {
        result.observe(callback2Value, attributes2);
        callback2Value += 100; // Increment for next call
      });

      // Verify both callbacks are registered
      expect(counter.callbacks.length, equals(2));

      // First collection should have both values
      final measurements1 = counter.collect();
      expect(measurements1.length, equals(2));
      expect(
          measurements1.where((m) => m.attributes == attributes1).first.value,
          equals(100));
      expect(
          measurements1.where((m) => m.attributes == attributes2).first.value,
          equals(200));

      // Second collection should have deltas
      final measurements2 = counter.collect();
      expect(measurements2.length, equals(2));
      expect(
          measurements2.where((m) => m.attributes == attributes1).first.value,
          equals(150));
      expect(
          measurements2.where((m) => m.attributes == attributes2).first.value,
          equals(300));

      // Unregister first callback
      registration1.unregister();
      expect(counter.callbacks.length, equals(1));

      // Collection should now only have the second callback's value
      final measurements3 = counter.collect();
      expect(measurements3.length, equals(1));
      expect(measurements3[0].attributes, equals(attributes2));
      expect(measurements3[0].value, equals(400));

      // Unregister second callback
      registration2.unregister();
      expect(counter.callbacks.length, equals(0));

      // Collection should now be empty
      final measurements4 = counter.collect();
      expect(measurements4.length, equals(0));
    });

    test('ObservableCounter with monotonicity', () {
      // Create a counter with a decreasing value to test monotonicity handling
      int counterValue = 100;
      bool decreaseValue = false;

      final counter = meter.createObservableCounter<int>(
        name: 'monotonic-test-counter',
        callback: (APIObservableResult<int> result) {
          if (decreaseValue) {
            counterValue -= 20; // Simulate a counter reset or restart
          } else {
            counterValue += 10;
          }
          result.observe(counterValue);
        },
      ) as ObservableCounter<int>;

      // First collection (increasing)
      final measurements1 = counter.collect();
      expect(measurements1.length, equals(1));
      expect(measurements1[0].value, equals(110)); // First absolute value

      // Second collection (increasing)
      final measurements2 = counter.collect();
      expect(measurements2.length, equals(1));
      expect(measurements2[0].value, equals(120)); // Delta: 120-10=110

      // Now decrease the value
      decreaseValue = true;

      // Third collection (decreasing)
      final measurements3 = counter.collect();
      expect(measurements3.length, equals(1));
      expect(measurements3[0].value, equals(100)); // Value after decrease

      // Verify the counter handles non-monotonic changes appropriately
      // When a counter resets or decreases, the SDK should treat this as a new starting point
      final points = counter.collectPoints();
      expect(points.length, equals(1));
      expect(points[0].value, equals(100)); // Same cumulative value
    });

    test('ObservableCounter with zero/negative delta', () {
      // Set up a counter with fixed value (no change)
      final fixedValue = 50;

      final counter = meter.createObservableCounter<int>(
        name: 'zero-delta-counter',
        callback: (APIObservableResult<int> result) {
          result.observe(fixedValue);
        },
      ) as ObservableCounter<int>;

      // First collection
      final measurements1 = counter.collect();
      expect(measurements1.length, equals(1));
      expect(measurements1[0].value, equals(50)); // Initial value

      // Second collection should have zero delta, which shouldn't be reported
      final measurements2 = counter.collect();
      expect(measurements2.length, equals(0)); // No measurement for zero delta

      // But the point is still there with the cumulative value
      final points = counter.collectPoints();
      expect(points.length, equals(1));
      expect(points[0].value, equals(50)); // Cumulative value unchanged
    });

    test('ObservableCounter collectMetrics', () {
      // Create a counter
      int value = 0;

      final counter = meter.createObservableCounter<int>(
        name: 'metrics-counter',
        unit: 'requests',
        description: 'Test metrics collection',
        callback: (APIObservableResult<int> result) {
          value += 5;
          result.observe(value);
        },
      ) as ObservableCounter<int>;

      // Trigger collection
      counter.collect();

      // Get metrics
      final metrics = counter.collectMetrics();
      expect(metrics.length, equals(1));

      // Verify metric properties
      final metric = metrics[0];
      expect(metric.name, equals('metrics-counter'));
      expect(metric.description, equals('Test metrics collection'));
      expect(metric.unit, equals('requests'));

      // Verify this is a sum metric with the correct properties
      expect(metric.type, equals(MetricType.sum));
      expect(metric.name, equals('metrics-counter'));
      // Sum metrics from ObservableCounter are monotonic
      expect(metric.points.isNotEmpty, isTrue);

      // Verify the points
      expect(metric.points.length, equals(1));
      expect(metric.points[0].value, equals(5));

      // Second collection - check the cumulative value
      counter.collect();
      final metrics2 = counter.collectMetrics();
      expect(metrics2[0].points[0].value, equals(10)); // 5 + 5
    });

    test('ObservableCounter with disabled meter', () {
      // Create a counter
      int callCount = 0;

      final counter = meter.createObservableCounter<int>(
        name: 'disabled-counter',
        callback: (APIObservableResult<int> result) {
          callCount++;
          result.observe(callCount * 10);
        },
      ) as ObservableCounter<int>;

      // Verify it's enabled initially
      expect(counter.enabled, isTrue);

      // Collect while enabled
      final measurements = counter.collect();
      expect(measurements.length, equals(1));
      expect(callCount, equals(1));

      // Disable the meter provider
      meterProvider.enabled = false;
      expect(counter.enabled, isFalse);

      // Collect while disabled - callback shouldn't be called
      final measurements2 = counter.collect();
      expect(measurements2.length, equals(0)); // No measurements when disabled
      expect(callCount, equals(1)); // Counter wasn't incremented

      // Metrics collection should also respect disabled state
      final metrics = counter.collectMetrics();
      expect(metrics.length, equals(0));
    });

    test('ObservableCounter state clearing', () async {
      // Create a counter
      int value = 100;

      final counter = meter.createObservableCounter<int>(
        name: 'clear-counter',
        callback: (APIObservableResult<int> result) {
          result.observe(value);
          value += 25;
        },
      ) as ObservableCounter<int>;

      // First collection
      counter.collect();

      // Verify point exists
      final metrics1 = counter.collectMetrics();
      expect(metrics1[0].points.length, equals(1));
      expect(metrics1[0].points[0].value, equals(100));

      // Second collection
      counter.collect();
      final metrics2 = counter.collectMetrics();
      expect(metrics2[0].points[0].value, equals(125));

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

      // Create a new counter
      final newCounter = meter.createObservableCounter<int>(
        name: 'clear-counter',
        callback: (APIObservableResult<int> result) {
          result.observe(200);
        },
      ) as ObservableCounter<int>;

      // Collect again
      newCounter.collect();
      final metrics3 = newCounter.collectMetrics();
      expect(metrics3[0].points.length, equals(1));
      expect(metrics3[0].points[0].value,
          equals(200)); // New value after shutdown/reset
    });
  });
}
