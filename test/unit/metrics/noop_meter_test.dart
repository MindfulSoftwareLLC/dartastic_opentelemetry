// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('NoOp Meter Implementation Tests', () {
    late NoopMeter noopMeter;

    setUp(() {
      noopMeter = NoopMeter(
        name: 'test-noop-meter',
      );
    });

    test('NoopMeter properties are set correctly', () {
      expect(noopMeter.name, equals('test-noop-meter'));
      expect(noopMeter.version, isNull);
      expect(noopMeter.schemaUrl, isNull);
      expect(noopMeter.attributes, isNull);
      expect(noopMeter.enabled, isFalse);
    });

    test('NoopMeter creates NoopCounter', () {
      final counter = noopMeter.createCounter<int>(
          name: 'test_counter', unit: 'ms', description: 'Test counter');

      expect(counter, isA<NoopCounter<int>>());
      expect(counter.name, equals('test_counter'));
      expect(counter.unit, equals('ms'));
      expect(counter.description, equals('Test counter'));
      expect(counter.enabled, isFalse);
      expect(counter.meter, isNotNull);

      // Verify type checks
      expect(counter.isCounter, isTrue);
      expect(counter.isGauge, isFalse);
      expect(counter.isHistogram, isFalse);
      expect(counter.isUpDownCounter, isFalse);

      // Test operations don't throw
      counter.add(10);
      counter.addWithMap(20, {'key': 'value'});
    });

    test('NoopMeter creates NoopUpDownCounter', () {
      final counter = noopMeter.createUpDownCounter<int>(
          name: 'test_up_down',
          unit: 'bytes',
          description: 'Test up-down counter');

      expect(counter, isA<NoopUpDownCounter<int>>());
      expect(counter.name, equals('test_up_down'));
      expect(counter.unit, equals('bytes'));
      expect(counter.description, equals('Test up-down counter'));
      expect(counter.enabled, isFalse);
      expect(counter.meter, isNotNull);

      // Verify type checks
      expect(counter.isCounter, isFalse);
      expect(counter.isGauge, isFalse);
      expect(counter.isHistogram, isFalse);
      expect(counter.isUpDownCounter, isTrue);

      // Test operations don't throw
      counter.add(10);
      counter.add(-5);
      counter.addWithMap(20, {'key': 'value'});
    });

    test('NoopMeter creates NoopHistogram', () {
      final histogram = noopMeter.createHistogram<double>(
        name: 'test_histogram',
        unit: 'ms',
        description: 'Test histogram',
        boundaries: [1, 5, 10, 50, 100],
      );

      expect(histogram, isA<NoopHistogram<double>>());
      expect(histogram.name, equals('test_histogram'));
      expect(histogram.unit, equals('ms'));
      expect(histogram.description, equals('Test histogram'));
      expect(histogram.boundaries, equals([1, 5, 10, 50, 100]));
      expect(histogram.enabled, isFalse);
      expect(histogram.meter, isNotNull);

      // Verify type checks
      expect(histogram.isCounter, isFalse);
      expect(histogram.isGauge, isFalse);
      expect(histogram.isHistogram, isTrue);
      expect(histogram.isUpDownCounter, isFalse);

      // Test operations don't throw
      histogram.record(10.5);
      histogram.recordWithMap(20.5, {'key': 'value'});
    });

    test('NoopMeter creates NoopGauge', () {
      final gauge = noopMeter.createGauge<double>(
          name: 'test_gauge', unit: 'celsius', description: 'Test gauge');

      expect(gauge, isA<NoopGauge<double>>());
      expect(gauge.name, equals('test_gauge'));
      expect(gauge.unit, equals('celsius'));
      expect(gauge.description, equals('Test gauge'));
      expect(gauge.enabled, isFalse);
      expect(gauge.meter, isNotNull);

      // Verify type checks
      expect(gauge.isCounter, isFalse);
      expect(gauge.isGauge, isTrue);
      expect(gauge.isHistogram, isFalse);
      expect(gauge.isUpDownCounter, isFalse);

      // Test operations don't throw
      gauge.record(10.5);
      gauge.recordWithMap(20.5, {'key': 'value'});
    });

    test('NoopMeter creates NoopObservableCounter', () {
      final counter = noopMeter.createObservableCounter<int>(
        name: 'test_obs_counter',
        unit: 'requests',
        description: 'Test observable counter',
      );

      expect(counter, isA<NoopObservableCounter<int>>());
      expect(counter.name, equals('test_obs_counter'));
      expect(counter.unit, equals('requests'));
      expect(counter.description, equals('Test observable counter'));
      expect(counter.enabled, isFalse);
      expect(counter.meter, isNotNull);

      // Initially empty callbacks
      expect(counter.callbacks, isEmpty);

      // Add a callback and verify
      // ignore: unused_local_variable
      final callbackRegister = counter.addCallback((result) {
        result.observe(42);
      });

      expect(counter.callbacks.length, equals(1));

      // Add another callback and verify
      final reg2 = counter.addCallback((result) => result.observe(123));
      expect(counter.callbacks.length, equals(2));

      // Remove the second callback
      reg2.unregister();
      expect(counter.callbacks.length, equals(1));

      // Collect should return empty list
      final measurements = counter.collect();
      expect(measurements, isEmpty);
    });

    test('NoopMeter creates NoopObservableUpDownCounter', () {
      final counter = noopMeter.createObservableUpDownCounter<int>(
        name: 'test_obs_up_down',
        unit: 'bytes',
        description: 'Test observable up-down counter',
      );

      expect(counter, isA<NoopObservableUpDownCounter<int>>());
      expect(counter.name, equals('test_obs_up_down'));
      expect(counter.unit, equals('bytes'));
      expect(counter.description, equals('Test observable up-down counter'));
      expect(counter.enabled, isFalse);
      expect(counter.meter, isNotNull);

      // Initially empty callbacks
      expect(counter.callbacks, isEmpty);

      // Add a callback and verify
      // ignore: unused_local_variable
      final callbackRegister = counter.addCallback((result) {
        result.observe(-42);
      });

      expect(counter.callbacks.length, equals(1));

      // Add another callback and verify
      final reg2 = counter.addCallback((result) => result.observe(-123));
      expect(counter.callbacks.length, equals(2));

      // Remove the second callback
      reg2.unregister();
      expect(counter.callbacks.length, equals(1));

      // Collect should return empty list
      final measurements = counter.collect();
      expect(measurements, isEmpty);
    });

    test('NoopMeter creates NoopObservableGauge', () {
      final gauge = noopMeter.createObservableGauge<double>(
        name: 'test_obs_gauge',
        unit: 'celsius',
        description: 'Test observable gauge',
      );

      expect(gauge, isA<NoopObservableGauge<double>>());
      expect(gauge.name, equals('test_obs_gauge'));
      expect(gauge.unit, equals('celsius'));
      expect(gauge.description, equals('Test observable gauge'));
      expect(gauge.enabled, isFalse);
      expect(gauge.meter, isNotNull);

      // Initially empty callbacks
      expect(gauge.callbacks, isEmpty);

      // Add a callback and verify
      // ignore: unused_local_variable
      final callbackRegister = gauge.addCallback((result) {
        result.observe(37.5);
      });

      expect(gauge.callbacks.length, equals(1));

      // Add another callback and verify
      final reg2 = gauge.addCallback((result) => result.observe(22.5));
      expect(gauge.callbacks.length, equals(2));

      // Remove the second callback
      reg2.unregister();
      expect(gauge.callbacks.length, equals(1));

      // Collect should return empty list
      final measurements = gauge.collect();
      expect(measurements, isEmpty);
    });

    test(
        '_NoopCallbackRegistration correctly unregisters from different instrument types',
        () {
      final obsCounter =
          noopMeter.createObservableCounter<int>(name: 'test_counter');
      final obsUpDown =
          noopMeter.createObservableUpDownCounter<int>(name: 'test_up_down');
      final obsGauge =
          noopMeter.createObservableGauge<double>(name: 'test_gauge');

      // Add and verify callbacks
      final reg1 = obsCounter.addCallback((result) => result.observe(1));
      final reg2 = obsUpDown.addCallback((result) => result.observe(2));
      final reg3 = obsGauge.addCallback((result) => result.observe(3.0));

      expect(obsCounter.callbacks.length, equals(1));
      expect(obsUpDown.callbacks.length, equals(1));
      expect(obsGauge.callbacks.length, equals(1));

      // Unregister
      reg1.unregister();
      reg2.unregister();
      reg3.unregister();

      // Verify callbacks were removed
      expect(obsCounter.callbacks, isEmpty);
      expect(obsUpDown.callbacks, isEmpty);
      expect(obsGauge.callbacks, isEmpty);
    });
  });
}
