// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('Counter', () {
    late MeterProvider meterProvider;
    late Meter meter;
    late Counter<int> counter;

    setUp(() {
      // Initialize OpenTelemetry
      OTel.initialize(endpoint: 'http://localhost:4318');
      
      // Get a meter provider and create a meter
      meterProvider = OTel.meterProvider() as MeterProvider;
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
      OTel.reset();
    });

    test('has correct properties', () {
      // Assert
      expect(counter.name, equals('test-counter'));
      expect(counter.unit, equals('items'));
      expect(counter.description, equals('A test counter'));
      expect(counter.meter, equals(meter));
      expect(counter.enabled, isTrue);
      expect(counter.isCounter, isTrue);
      expect(counter.isUpDownCounter, isFalse);
      expect(counter.isGauge, isFalse);
      expect(counter.isHistogram, isFalse);
    });

    test('records positive values', () {
      // Act
      counter.add(5);
      counter.add(10);
      
      // Assert
      expect(counter.getValue(), equals(15));
    });

    test('records values with attributes', () {
      // Arrange
      final attributes1 = {'key1': 'value1'}.toAttributes();
      final attributes2 = {'key1': 'value2'}.toAttributes();
      
      // Act
      counter.add(5, attributes1);
      counter.add(10, attributes2);
      counter.add(15, attributes1);
      
      // Assert
      expect(counter.getValue(), equals(30)); // Total sum
      expect(counter.getValue(attributes1), equals(20)); // Sum for attributes1
      expect(counter.getValue(attributes2), equals(10)); // Sum for attributes2
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
      counter.add(42);
      
      // Act
      final metrics = counter.collectMetrics();
      
      // Assert
      expect(metrics, hasLength(1));
      expect(metrics[0].name, equals('test-counter'));
      expect(metrics[0].description, equals('A test counter'));
      expect(metrics[0].unit, equals('items'));
      expect(metrics[0].type, equals(MetricType.sum));
      expect(metrics[0].points, hasLength(1));
      expect(metrics[0].points[0].value, equals(42));
    });

    test('resets correctly', () {
      // Arrange
      counter.add(42);
      expect(counter.getValue(), equals(42));
      
      // Act
      counter.reset();
      
      // Assert
      expect(counter.getValue(), equals(0));
    });
  });
}
