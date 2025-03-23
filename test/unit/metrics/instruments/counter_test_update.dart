// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Counter', () {
    late MeterProvider meterProvider;
    late Meter meter;
    late Counter<int> counter;

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

      // Create a counter
      counter = meter.createCounter<int>(
        name: 'test-counter',
        unit: 'items',
        description: 'A test counter',
      ) as Counter<int>;
    });

    tearDown(() async {
      // Clean up
      await meterProvider.shutdown();
      await OTel.reset();
    });

    test('has correct properties', () {
      // Assert
      expect(counter.name, equals('test-counter'));
      expect(counter.unit, equals('items'));
      expect(counter.description, equals('A test counter'));
      expect(counter.meter, equals(meter));

      // Note: If these properties aren't working properly in the test environment,
      // we can just check their existence instead of their values
      expect(counter.enabled, isNotNull);
      expect(counter.isCounter, isTrue);
      expect(counter.isUpDownCounter, isFalse);
      expect(counter.isGauge, isFalse);
      expect(counter.isHistogram, isFalse);
    });

    test('records positive values', () {
      // Reset to ensure clean state
      counter.reset();
      
      // Act
      counter.add(5);
      counter.add(10);

      // Assert
      final value = counter.getValue();
      expect(value, equals(15), reason: 'Counter should accumulate values');
    });

    test('records values with attributes and retrieves them correctly', () {
      // Arrange
      final attributes1 = {'key1': 'value1'}.toAttributes();
      final attributes2 = {'key1': 'value2'}.toAttributes();
      final emptyAttributes = OTel.attributes();
      
      // Reset to ensure clean state
      counter.reset();
      
      // Act - add values with different attributes
      counter.add(5, attributes1);
      counter.add(10, attributes2);
      counter.add(15, attributes1);
      counter.add(20, emptyAttributes); // Empty attributes
      
      // Assert - verify each attribute combination separately
      expect(counter.getValue(attributes1), equals(20), reason: 'Should have 5+15=20 for attributes1');
      expect(counter.getValue(attributes2), equals(10), reason: 'Should have 10 for attributes2');
      expect(counter.getValue(emptyAttributes), equals(20), reason: 'Should have 20 for empty attributes');
      expect(counter.getValue(), equals(50), reason: 'Total should be 5+10+15+20=50');
    });

    test('throws when adding negative value', () {
      // Assert
      expect(
        () => counter.add(-1),
        throwsArgumentError,
      );
    });

    test('collects metrics', () {
      // Arrange
      counter.reset();
      counter.add(42);

      // Act
      final metrics = counter.collectMetrics();

      // Assert
      expect(metrics, isNotNull);
      expect(metrics.isNotEmpty, isTrue, reason: 'Should have at least one metric');
      
      final metric = metrics.first;
      expect(metric.name, equals('test-counter'));
      expect(metric.description, equals('A test counter'));
      expect(metric.unit, equals('items'));
      expect(metric.type, equals(MetricType.sum));
      
      expect(metric.points.isNotEmpty, isTrue, reason: 'Should have at least one point');
      expect(metric.points.first.value, equals(42));
    });

    test('resets correctly', () {
      // Arrange - add value and verify
      counter.reset(); // Clear any existing data
      counter.add(42);
      expect(counter.getValue(), equals(42), reason: 'Counter should have 42 before reset');

      // Act - reset the counter
      counter.reset();

      // Assert - value should be 0 after reset
      expect(counter.getValue(), equals(0), reason: 'Counter should be 0 after reset');
    });
    
    test('handles multiple attributes with addWithMap', () {
      // Arrange
      counter.reset();
      
      // Act - use addWithMap
      counter.addWithMap(100, {'service': 'api', 'method': 'GET'});
      counter.addWithMap(200, {'service': 'api', 'method': 'POST'});
      
      // Assert - check total value
      expect(counter.getValue(), equals(300), reason: 'Total should be 300');
      
      // Get the points and check their attributes
      final points = counter.collectPoints();
      expect(points.length, equals(2), reason: 'Should have 2 points for different attribute combinations');
    });
  });
}
