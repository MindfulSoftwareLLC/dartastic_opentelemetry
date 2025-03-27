// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('UpDownCounter Extended Tests', () {
    late Meter meter;
    late MemoryMetricExporter memoryExporter;
    late MemoryMetricReader metricReader;

    setUp(() async {
      await OTel.reset();

      // Create a memory exporter for verification
      memoryExporter = MemoryMetricExporter();
      
      // Create a metric reader connected to the exporter
      metricReader = MemoryMetricReader(exporter: memoryExporter);

      // Initialize OTel with our memory metric reader
      await OTel.initialize(
        serviceName: 'updowncounter-test-service',
        metricReader: metricReader,
        detectPlatformResources: false,
      );

      // Get a meter for our tests
      meter = OTel.meter('updowncounter-tests');
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('UpDownCounter reports correct type properties', () {
      final counter = meter.createUpDownCounter<int>(
        name: 'test-up-down-counter',
        description: 'Test up-down counter',
        unit: 'items',
      );
      
      // Check instrument properties
      expect(counter.isCounter, isFalse);
      expect(counter.isUpDownCounter, isTrue);
      expect(counter.isGauge, isFalse);
      expect(counter.isHistogram, isFalse);
    });

    test('UpDownCounter with disabled provider', () async {
      final counter = meter.createUpDownCounter<int>(
        name: 'disabled-counter',
        description: 'Test disabled counter',
      );
      
      // Record initial value
      counter.add(10);
      
      // Force a collection
      await metricReader.forceFlush();
      
      // Get the metrics
      var metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue);
      
      // Disable the meter provider
      OTel.meterProvider().enabled = false;
      
      // Record more measurements
      counter.add(20);
      
      // Clear exporter
      memoryExporter.clear();
      
      // Force another collection
      await metricReader.forceFlush();
      
      // Verify no new metrics were exported
      metrics = memoryExporter.exportedMetrics;
      expect(metrics.isEmpty, isTrue);
      
      // Re-enable the meter provider
      OTel.meterProvider().enabled = true;
      
      // Record more measurements
      counter.add(30);
      
      // Force another collection
      await metricReader.forceFlush();
      
      // Verify metrics are now exported
      metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue);
    });

    test('UpDownCounter supports different number types', () async {
      // Integer counter
      final intCounter = meter.createUpDownCounter<int>(
        name: 'int-up-down-counter',
        unit: 'count',
      );
      
      // Double counter
      final doubleCounter = meter.createUpDownCounter<double>(
        name: 'double-up-down-counter',
        unit: 'percentage',
      );
      
      // Record values
      intCounter.add(42);
      doubleCounter.add(3.14);
      
      // Force collection
      await metricReader.forceFlush();
      
      // Get metrics
      final metrics = memoryExporter.exportedMetrics;
      
      // Find our counters
      final intMetric = metrics.firstWhere((m) => m.name == 'int-up-down-counter');
      final doubleMetric = metrics.firstWhere((m) => m.name == 'double-up-down-counter');
      
      // Verify values
      expect(intMetric.points.first.value, equals(42));
      expect(doubleMetric.points.first.value, equals(3.14));
    });

    test('UpDownCounter supports negative increments', () async {
      final counter = meter.createUpDownCounter<int>(
        name: 'bidirectional-counter',
        unit: 'tasks',
      );
      
      // Record positive and negative values
      counter.add(10);
      counter.add(-3);
      counter.add(5);
      counter.add(-7);
      
      // Force collection
      await metricReader.forceFlush();
      
      // Get metric
      final metric = memoryExporter.exportedMetrics
          .firstWhere((m) => m.name == 'bidirectional-counter');
      
      // Verify final value (10 - 3 + 5 - 7 = 5)
      expect(metric.points.first.value, equals(5));
    });

    test('UpDownCounter with addWithMap', () async {
      final counter = meter.createUpDownCounter<int>(
        name: 'map-attributes-counter',
        unit: 'bytes',
      ) as UpDownCounter<int>; // Cast to implementation class to access addWithMap
      
      // Record using addWithMap
      counter.addWithMap(100, {
        'direction': 'up',
        'operation': 'test',
      });
      
      counter.addWithMap(-25, {
        'direction': 'down',
        'operation': 'test',
      });
      
      // Force collection
      await metricReader.forceFlush();
      
      // Get metric
      final metric = memoryExporter.exportedMetrics
          .firstWhere((m) => m.name == 'map-attributes-counter');
      
      // Verify we get two separate points with different values
      expect(metric.points.length, equals(2));
      // Find points for each direction
      final upPoint = metric.points.firstWhere((p) => p.attributes.getString('direction') == 'up');
      final downPoint = metric.points.firstWhere((p) => p.attributes.getString('direction') == 'down');
      
      // Verify values for each point
      expect(upPoint.value, equals(100));
      expect(downPoint.value, equals(-25));
      
      // Verify all attributes are preserved
      expect(upPoint.attributes.getString('operation'), equals('test'));
      expect(downPoint.attributes.getString('operation'), equals('test'));
    });

    test('UpDownCounter.getValue returns correct value', () {
      final counter = meter.createUpDownCounter<int>(
        name: 'get-value-counter',
      ) as UpDownCounter<int>; // Cast to implementation class to access getValue
      
      // Record values with different attributes
      final attrs1 = {'region': 'us-west'}.toAttributes();
      final attrs2 = {'region': 'us-east'}.toAttributes();
      
      counter.add(50, attrs1);
      counter.add(30, attrs2);
      counter.add(-20, attrs1);
      
      // Get values using getValue
      expect(counter.getValue(attrs1), equals(30)); // 50 - 20
      expect(counter.getValue(attrs2), equals(30));
      expect(counter.getValue(), equals(60)); // 50 - 20 + 30
    });

    test('UpDownCounter collectMetrics respects enabled state', () {
      final counter = meter.createUpDownCounter<int>(
        name: 'collect-metrics-counter',
      ) as UpDownCounter<int>;
      
      // Record a value
      counter.add(42);
      
      // Verify metric collection works when enabled
      var metrics = counter.collectMetrics();
      expect(metrics.length, equals(1));
      
      // Disable the meter provider
      OTel.meterProvider().enabled = false;
      
      // Verify no metrics are collected when disabled
      metrics = counter.collectMetrics();
      expect(metrics.isEmpty, isTrue);
    });
  });
}
