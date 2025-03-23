// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// Tests for generic type handling in metric instruments
void main() {
  group('Metrics Generic Types', () {
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

    test('Counter handles int generic type', () {
      // Create a Counter with int type
      final counter = meter.createCounter<int>(
        name: 'int-counter',
        unit: 'items',
        description: 'An integer counter',
      ) as Counter<int>;

      // Ensure the counter properties are set correctly
      expect(counter.name, equals('int-counter'));
      expect(counter.unit, equals('items'));
      expect(counter.description, equals('An integer counter'));

      // Test adding values
      counter.reset();
      counter.add(5);
      counter.add(10);

      // Verify the value is retrieved as an int
      final value = counter.getValue();
      expect(value, equals(15));
      expect(value, isA<int>());
    });

    test('Counter handles double generic type', () {
      // Create a Counter with double type
      final counter = meter.createCounter<double>(
        name: 'double-counter',
        unit: 'seconds',
        description: 'A double counter',
      ) as Counter<double>;

      // Ensure the counter properties are set correctly
      expect(counter.name, equals('double-counter'));
      expect(counter.unit, equals('seconds'));
      expect(counter.description, equals('A double counter'));

      // Test adding values
      counter.reset();
      counter.add(5.5);
      counter.add(10.25);

      // Verify the value is retrieved as a double
      final value = counter.getValue();
      expect(value, equals(15.75));
      expect(value, isA<double>());
    });

    test('UpDownCounter handles int generic type', () {
      // Create an UpDownCounter with int type
      final counter = meter.createUpDownCounter<int>(
        name: 'int-up-down-counter',
        unit: 'connections',
        description: 'An integer up-down counter',
      ) as UpDownCounter<int>;

      // Ensure the counter properties are set correctly
      expect(counter.name, equals('int-up-down-counter'));
      expect(counter.unit, equals('connections'));
      expect(counter.description, equals('An integer up-down counter'));

      // Test adding and subtracting values
      counter.reset();
      counter.add(10);
      counter.add(-4);

      // Verify the value is retrieved as an int
      final value = counter.getValue();
      expect(value, equals(6));
      expect(value, isA<int>());
    });

    test('UpDownCounter handles double generic type', () {
      // Create an UpDownCounter with double type
      final counter = meter.createUpDownCounter<double>(
        name: 'double-up-down-counter',
        unit: 'seconds',
        description: 'A double up-down counter',
      ) as UpDownCounter<double>;

      // Ensure the counter properties are set correctly
      expect(counter.name, equals('double-up-down-counter'));
      expect(counter.unit, equals('seconds'));
      expect(counter.description, equals('A double up-down counter'));

      // Test adding and subtracting values
      counter.reset();
      counter.add(10.5);
      counter.add(-4.25);

      // Verify the value is retrieved as a double
      final value = counter.getValue();
      expect(value, equals(6.25));
      expect(value, isA<double>());
    });

    test('ObservableCounter handles int generic type', () {
      // Create an ObservableCounter with int type
      final counter = meter.createObservableCounter<int>(
        name: 'observable-int-counter',
        unit: 'bytes',
        description: 'An observable integer counter',
      ) as ObservableCounter<int>;

      bool callbackExecuted = false;
      int capturedValue = 0;

      // Add a callback
      counter.addCallback((result) {
        callbackExecuted = true;
        // Observe a value
        result.observe(42);
        capturedValue = 42;
      });

      // Collect measurements to trigger callbacks
      final measurements = counter.collect();

      // Verify callback was executed
      expect(callbackExecuted, isTrue);
      
      // Verify measurements were recorded
      expect(measurements.isNotEmpty, isTrue);
      if (measurements.isNotEmpty) {
        expect(measurements.first.value, equals(capturedValue));
        expect(measurements.first.value, isA<int>());
      }
      
      // Reset the counter
      counter.reset();
    });

    test('ObservableCounter handles double generic type', () {
      // Create an ObservableCounter with double type
      final counter = meter.createObservableCounter<double>(
        name: 'observable-double-counter',
        unit: 'seconds',
        description: 'An observable double counter',
      ) as ObservableCounter<double>;

      bool callbackExecuted = false;
      double capturedValue = 0.0;

      // Add a callback
      counter.addCallback((result) {
        callbackExecuted = true;
        // Observe a value
        result.observe(42.5);
        capturedValue = 42.5;
      });

      // Collect measurements to trigger callbacks
      final measurements = counter.collect();

      // Verify callback was executed
      expect(callbackExecuted, isTrue);
      
      // Verify measurements were recorded
      expect(measurements.isNotEmpty, isTrue);
      if (measurements.isNotEmpty) {
        expect(measurements.first.value, equals(capturedValue));
        expect(measurements.first.value, isA<double>());
      }
      
      // Reset the counter
      counter.reset();
    });

    test('Metrics with attributes have correct generic types', () {
      // Create counters with different generic types
      final intCounter = meter.createCounter<int>(
        name: 'attr-int-counter',
        unit: 'items',
      ) as Counter<int>;
      
      final doubleCounter = meter.createCounter<double>(
        name: 'attr-double-counter',
        unit: 'seconds',
      ) as Counter<double>;

      // Create attributes
      final attributes1 = {'service': 'api'}.toAttributes();
      final attributes2 = {'service': 'db'}.toAttributes();

      // Reset counters
      intCounter.reset();
      doubleCounter.reset();

      // Add values with attributes
      intCounter.add(5, attributes1);
      intCounter.add(10, attributes2);

      doubleCounter.add(5.5, attributes1);
      doubleCounter.add(10.25, attributes2);

      // Verify values with attributes maintain their types
      expect(intCounter.getValue(attributes1), equals(5));
      expect(intCounter.getValue(attributes1), isA<int>());
      
      expect(intCounter.getValue(attributes2), equals(10));
      expect(intCounter.getValue(attributes2), isA<int>());

      expect(doubleCounter.getValue(attributes1), equals(5.5));
      expect(doubleCounter.getValue(attributes1), isA<double>());
      
      expect(doubleCounter.getValue(attributes2), equals(10.25));
      expect(doubleCounter.getValue(attributes2), isA<double>());
    });
  });
}
