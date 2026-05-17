// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('ObservableUpDownCounter Tests', () {
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

    test('Simple ObservableUpDownCounter with single callback', () {
      // Value that can go up and down
      var counterValue = 100;
      var shouldIncrease = true;

      // Create an ObservableUpDownCounter with int type
      final counter = meter.createObservableUpDownCounter<int>(
        name: 'test-observable-updown-counter',
        unit: 'items',
        description: 'A test observable up-down counter',
        callback: (APIObservableResult<int> result) {
          result.observe(counterValue);
          // Change the value for next observation
          if (shouldIncrease) {
            counterValue += 10;
          } else {
            counterValue -= 15;
          }
          shouldIncrease = !shouldIncrease; // Toggle for next time
        },
      ) as ObservableUpDownCounter<int>;

      // Verify instrument properties
      expect(counter.name, equals('test-observable-updown-counter'));
      expect(counter.unit, equals('items'));
      expect(counter.description, equals('A test observable up-down counter'));
      expect(counter.enabled, isTrue);
      expect(counter.meter, equals(meter));

      // Verify callbacks were registered
      expect(counter.callbacks.length, equals(1));

      // Collect measurements - first value
      final measurements1 = counter.collect();
      expect(measurements1.length, equals(1));
      expect(
        measurements1[0].value,
        equals(100),
      ); // First observation (collectPoints() is called first internally)

      // Collect again - should get the second value (increased)
      final measurements2 = counter.collect();
      expect(measurements2.length, equals(1));
      expect(measurements2[0].value, equals(110)); // Increased value

      // Collect again - should get the third value (decreased)
      final measurements3 = counter.collect();
      expect(measurements3.length, equals(1));
      expect(measurements3[0].value, equals(95)); // Decreased value

      // Collect metrics
      final metrics = counter.collectMetrics();
      expect(metrics.length, equals(1));

      // Verify this is a sum metric that's not monotonic
      expect(metrics[0].type, equals(MetricType.sum));
      expect(metrics[0].name, equals('test-observable-updown-counter'));

      // Verify the points. collectMetrics() drives one more callback
      // per the OTel spec, so the stored absolute value advances one
      // tick beyond the manual collects.
      expect(metrics[0].points.length, equals(1));
      expect(metrics[0].points[0].value, equals(105));
    });

    test('ObservableUpDownCounter with attributes', () {
      // Create sets of attributes
      final attributes1 = {'region': 'east'}.toAttributes();
      final attributes2 = {'region': 'west'}.toAttributes();

      // Create value maps to simulate values that can go up or down
      final regionValues = <String, int>{'east': 50, 'west': 75};

      // Create an ObservableUpDownCounter
      final counter = meter.createObservableUpDownCounter<int>(
        name: 'attr-observable-updown-counter',
        unit: 'connections',
        callback: (APIObservableResult<int> result) {
          // Report both values
          result.observe(regionValues['east']!, attributes1);
          result.observe(regionValues['west']!, attributes2);

          // Change values for next observation
          regionValues['east'] = regionValues['east']! + 5;
          regionValues['west'] = regionValues['west']! - 8;
        },
      ) as ObservableUpDownCounter<int>;

      // First collection
      final measurements1 = counter.collect();
      expect(measurements1.length, equals(2));

      // Values should match our initial values
      expect(
        measurements1.where((m) => m.attributes == attributes1).first.value,
        equals(50),
      );
      expect(
        measurements1.where((m) => m.attributes == attributes2).first.value,
        equals(75),
      );

      // Second collection
      final measurements2 = counter.collect();
      expect(measurements2.length, equals(2));

      // Values should reflect the changes
      expect(
        measurements2.where((m) => m.attributes == attributes1).first.value,
        equals(55),
      );
      expect(
        measurements2.where((m) => m.attributes == attributes2).first.value,
        equals(67),
      );

      // Get metric points
      final metrics = counter.collectMetrics();
      expect(metrics.length, equals(1));

      expect(metrics[0].type, equals(MetricType.sum));
      expect(metrics[0].points.length, equals(2));

      // Points should have the latest values. collectMetrics() drives
      // one more callback per the OTel spec, so values advance one tick.
      final point1 =
          metrics[0].points.where((p) => p.attributes == attributes1).first;
      final point2 =
          metrics[0].points.where((p) => p.attributes == attributes2).first;
      expect(point1.value, equals(60));  // east: 50 +5 +5 +5; observed 60 at fire #3
      expect(point2.value, equals(59));  // west: 75 −8 −8 −8; observed 59 at fire #3
    });

    test('ObservableUpDownCounter with multiple callbacks', () {
      // Create an ObservableUpDownCounter without initial callback
      final counter = meter.createObservableUpDownCounter<int>(
        name: 'multi-callback-updown-counter',
        unit: 'processes',
      ) as ObservableUpDownCounter<int>;

      // First callback
      var serverProcesses = 42;
      final attributes1 = {'server': 'app'}.toAttributes();
      final registration1 = counter.addCallback((
        APIObservableResult<int> result,
      ) {
        result.observe(serverProcesses, attributes1);
        // Increment by 1 for each observation
        serverProcesses++;
      });

      // Second callback
      var dbProcesses = 15;
      final attributes2 = {'server': 'db'}.toAttributes();
      final registration2 = counter.addCallback((
        APIObservableResult<int> result,
      ) {
        result.observe(dbProcesses, attributes2);
        // Sometimes goes up, sometimes down
        dbProcesses = (dbProcesses == 15) ? 17 : 15;
      });

      // Verify both callbacks are registered
      expect(counter.callbacks.length, equals(2));

      // First collection should have both values
      final measurements1 = counter.collect();
      expect(measurements1.length, equals(2));
      expect(
        measurements1.where((m) => m.attributes == attributes1).first.value,
        equals(42),
      );
      expect(
        measurements1.where((m) => m.attributes == attributes2).first.value,
        equals(15),
      );

      // Second collection should have updated values
      final measurements2 = counter.collect();
      expect(measurements2.length, equals(2));
      expect(
        measurements2.where((m) => m.attributes == attributes1).first.value,
        equals(43),
      );
      expect(
        measurements2.where((m) => m.attributes == attributes2).first.value,
        equals(17),
      );

      // Unregister first callback
      registration1.unregister();
      expect(counter.callbacks.length, equals(1));

      // Collection should now only have the second callback's value
      final measurements3 = counter.collect();
      expect(measurements3.length, equals(1));
      expect(measurements3[0].attributes, equals(attributes2));
      expect(measurements3[0].value, equals(15)); // Back to 15

      // Unregister second callback
      registration2.unregister();
      expect(counter.callbacks.length, equals(0));

      // Collection should now be empty
      final measurements4 = counter.collect();
      expect(measurements4.length, equals(0));
    });

    test('ObservableUpDownCounter collectMetrics', () {
      // Create a counter with value that oscillates
      var value = 1000;
      var goingUp = false;

      final counter = meter.createObservableUpDownCounter<int>(
        name: 'metrics-updown-counter',
        unit: 'connections',
        description: 'Test metrics collection',
        callback: (APIObservableResult<int> result) {
          result.observe(value);
          // Change direction every call
          if (goingUp) {
            value += 50;
          } else {
            value -= 30;
          }
          goingUp = !goingUp;
        },
      ) as ObservableUpDownCounter<int>;

      // Trigger collection
      counter.collect();

      // Get metrics
      final metrics = counter.collectMetrics();
      expect(metrics.length, equals(1));

      // Verify metric properties
      final metric = metrics[0];
      expect(metric.name, equals('metrics-updown-counter'));
      expect(metric.description, equals('Test metrics collection'));
      expect(metric.unit, equals('connections'));

      // Verify this is a sum metric
      expect(metric.type, equals(MetricType.sum));

      // Verify the points. Each collectMetrics() fires the callback
      // one more time per the OTel spec; the oscillating value moves
      // each fire by -30 / +50 alternating.
      expect(metric.points.length, equals(1));
      expect(metric.points[0].value, equals(970));  // fires 1, 2 → observe 970

      // Second pass: collect → fire 3 (observe 1020), collectMetrics
      // → fire 4 (observe 990).
      counter.collect();
      final metrics2 = counter.collectMetrics();
      expect(metrics2[0].points[0].value, equals(990));

      // Third pass: collect → fire 5 (observe 1040), collectMetrics
      // → fire 6 (observe 1010).
      counter.collect();
      final metrics3 = counter.collectMetrics();
      expect(metrics3[0].points[0].value, equals(1010));
    });

    test('ObservableUpDownCounter with disabled meter', () {
      // Create a counter
      var callCount = 0;

      final counter = meter.createObservableUpDownCounter<int>(
        name: 'disabled-updown-counter',
        callback: (APIObservableResult<int> result) {
          callCount++;
          result.observe(callCount * 100);
        },
      ) as ObservableUpDownCounter<int>;

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

    test('ObservableUpDownCounter with different numeric types', () {
      // Create an integer counter
      final intCounter = meter.createObservableUpDownCounter<int>(
        name: 'int-updown-counter',
        unit: 'bytes',
        callback: (APIObservableResult<int> result) {
          result.observe(1024);
        },
      ) as ObservableUpDownCounter<int>;

      // Create a double counter
      final doubleCounter = meter.createObservableUpDownCounter<double>(
        name: 'double-updown-counter',
        unit: 'seconds',
        callback: (APIObservableResult<double> result) {
          result.observe(12.345);
        },
      ) as ObservableUpDownCounter<double>;

      // Collect from both
      final intMeasurements = intCounter.collect();
      final doubleMeasurements = doubleCounter.collect();

      // Verify the values maintain their types
      expect(intMeasurements[0].value, equals(1024));
      expect(intMeasurements[0].value, isA<int>());
      expect(doubleMeasurements[0].value, equals(12.345));
      expect(doubleMeasurements[0].value, isA<double>());

      // Verify metrics collection
      final intMetrics = intCounter.collectMetrics();
      final doubleMetrics = doubleCounter.collectMetrics();

      expect(intMetrics[0].points[0].value, equals(1024));
      expect(doubleMetrics[0].points[0].value, equals(12.345));
    });

    test('ObservableUpDownCounter state clearing', () async {
      // Create a counter
      var value = 100;

      final counter = meter.createObservableUpDownCounter<int>(
        name: 'clear-updown-counter',
        callback: (APIObservableResult<int> result) {
          result.observe(value);
          value += 25;
        },
      ) as ObservableUpDownCounter<int>;

      // First collection. collectMetrics() drives one more callback per
      // the OTel spec; value advances +25 per fire after the observe.
      counter.collect();

      final metrics1 = counter.collectMetrics();
      expect(metrics1[0].points.length, equals(1));
      expect(metrics1[0].points[0].value, equals(125)); // fires 1, 2

      // Second pass: collect → fire 3 (observe 150), collectMetrics
      // → fire 4 (observe 175).
      counter.collect();
      final metrics2 = counter.collectMetrics();
      expect(metrics2[0].points[0].value, equals(175));

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
      final newCounter = meter.createObservableUpDownCounter<int>(
        name: 'clear-updown-counter',
        callback: (APIObservableResult<int> result) {
          result.observe(200);
        },
      ) as ObservableUpDownCounter<int>;

      // Collect again
      newCounter.collect();
      final metrics3 = newCounter.collectMetrics();
      expect(metrics3[0].points.length, equals(1));
      expect(
        metrics3[0].points[0].value,
        equals(200),
      ); // New value after shutdown/reset
    });

    test('ObservableUpDownCounter with exceptions in callbacks', () {
      // Create a counter with a callback that throws an exception
      var callbackThrows = true;

      final counter = meter.createObservableUpDownCounter<int>(
        name: 'exception-counter',
        callback: (APIObservableResult<int> result) {
          if (callbackThrows) {
            throw Exception('Simulated error in counter callback');
          }
          result.observe(500);
        },
      ) as ObservableUpDownCounter<int>;

      // First collection with exception
      // The SDK should handle exceptions gracefully and not crash
      final measurements1 = counter.collect();
      expect(
        measurements1.length,
        equals(0),
      ); // No measurements due to exception

      // Fix the callback and collect again
      callbackThrows = false;
      final measurements2 = counter.collect();
      expect(measurements2.length, equals(1));
      expect(measurements2[0].value, equals(500));
    });

    test('ObservableUpDownCounter with value changes', () {
      // Track how a counter behaves with different types of value changes
      // Set the same value multiple times
      var fixedValue = 42;
      var valueChanged = false;

      final counter = meter.createObservableUpDownCounter<int>(
        name: 'change-test-counter',
        callback: (APIObservableResult<int> result) {
          result.observe(fixedValue);

          // Only change after second collection
          if (valueChanged) {
            fixedValue = 37;
          }
          valueChanged = true;
        },
      ) as ObservableUpDownCounter<int>;

      // First collection. collectMetrics() drives one more callback per
      // the OTel spec — collect observes 42 (valueChanged was false),
      // collectMetrics observes 42 (and sets fixedValue=37 after).
      counter.collect();
      final metrics1 = counter.collectMetrics();
      expect(metrics1[0].points[0].value, equals(42));

      // Second pass: collect observes 37 (fixedValue already changed),
      // collectMetrics observes 37 (still 37). Pre-fix this test relied
      // on the bug to keep the second observation at 42; with the fix
      // the value has already flipped by the time we read here.
      counter.collect();
      final metrics2 = counter.collectMetrics();
      expect(metrics2[0].points[0].value, equals(37));

      // Third pass: fixedValue is permanently 37 from here on.
      counter.collect();
      final metrics3 = counter.collectMetrics();
      expect(metrics3[0].points[0].value, equals(37));
    });
  });
}
