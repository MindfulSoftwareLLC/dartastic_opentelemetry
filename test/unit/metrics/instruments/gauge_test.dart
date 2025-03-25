// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('Gauge Instrument Tests', () {
    late Meter meter;
    late MemoryMetricExporter memoryExporter;

    setUp(() async {
      await OTel.reset();

      // Create a memory exporter for verification
      memoryExporter = MemoryMetricExporter();

      // Initialize OTel with our memory exporter
      await OTel.initialize(
        serviceName: 'gauge-test-service',
        metricExporter: memoryExporter,
        detectPlatformResources: false,
      );

      // Get a meter for our tests
      meter = OTel.meter('gauge-tests');
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('Gauge sets current values correctly', () async {
      // Create a gauge instrument
      final gauge = meter.createGauge(name: 'test_gauge',
        description: 'Test gauge for validation',
        unit: 'ms',
      );

      // Set initial gauge values with different attributes
      final attrs1 = {'service': 'api'}.toAttributes();
      final attrs2 = {'service': 'database'}.toAttributes();

      gauge.record(50.0, attrs1);
      gauge.record(100.0, attrs2);
      gauge.record(75.0); // No attributes

      // Update a value
      gauge.record(60.0, attrs1);

      // Force a collection
      await memoryExporter.forceFlush();

      // Get the collected metrics
      final metrics = memoryExporter.exportedMetrics;

      // We should have one metric (our gauge)
      expect(metrics.length, equals(1));

      // Find our gauge
      final metric = metrics.firstWhere(
        (m) => m.name == 'test_gauge',
        orElse: () => throw StateError('Gauge metric not found'),
      );

      // Check properties
      expect(metric.description, equals('Test gauge for validation'));
      expect(metric.unit, equals('ms'));

      // We should have 3 data points (one for each attributes set)
      final points = metric.points;
      expect(points.length, equals(3));

      // Find each data point by attributes
      final point1 = points.firstWhere(
        (p) => p.attributes.getString('service') == 'api',
        orElse: () => throw StateError('Point with api attributes not found'),
      );
      final point2 = points.firstWhere(
        (p) => p.attributes.getString('service') == 'database',
        orElse: () => throw StateError('Point with database attributes not found'),
      );
      final point3 = points.firstWhere(
        (p) => p.attributes.isEmpty,
        orElse: () => throw StateError('Point with no attributes not found'),
      );

      // Verify each point's value
      expect(point1.value, equals(60.0));  // Updated from 50.0 to 60.0
      expect(point2.value, equals(100.0));
      expect(point3.value, equals(75.0));
    });

    test('Gauge with int values', () async {
      // Create an integer gauge
      final gauge = meter.createGauge<int>(
        name: 'int_gauge',
        description: 'Integer gauge',
      );

      // Set values
      gauge.record(10);
      gauge.record(20, {'type': 'request'}.toAttributes());

      // Force collection
      await memoryExporter.forceFlush();

      // Get the collected metrics
      final metrics = memoryExporter.exportedMetrics;
      final metric = metrics.firstWhere((m) => m.name == 'int_gauge');

      // Verify we have 2 data points
      expect(metric.points.length, equals(2));

      // Find each point
      final noAttrsPoint = metric.points.firstWhere((p) => p.attributes.isEmpty);
      final withAttrsPoint = metric.points.firstWhere((p) => !p.attributes.isEmpty);

      // Verify values
      expect(noAttrsPoint.value, equals(10));
      expect(withAttrsPoint.value, equals(20));
    });

    test('Gauge overwrites old values', () async {
      // Create a gauge
      final gauge = meter.createGauge<double>(name: 'overwrite_gauge',);

      final attrs = {'endpoint': '/api/users'}.toAttributes();

      // Set initial value
      gauge.record(50.0, attrs);

      // Force collection
      await memoryExporter.forceFlush();

      // Set new value (should overwrite)
      gauge.record(75.0, attrs);

      // Force another collection
      await memoryExporter.forceFlush();

      // Get the collected metrics from the second collection
      final metrics = memoryExporter.exportedMetrics;
      final metric = metrics.firstWhere((m) => m.name == 'overwrite_gauge');

      // Find the point with our attributes
      final point = metric.points.firstWhere(
        (p) => p.attributes.getString('endpoint') == '/api/users',
      );

      // Verify the value was overwritten
      expect(point.value, equals(75.0));
    });

    test('Gauge with different types', () async {
      // Create gauges with different types
      final intGauge = meter.createGauge<int>(name: 'int_gauge_type');
      final doubleGauge = meter.createGauge<double>(name: 'double_gauge_type');

      // Set values
      intGauge.record(42);
      doubleGauge.record(42.5);

      // Force collection
      await memoryExporter.forceFlush();

      // Get metrics
      final metrics = memoryExporter.exportedMetrics;
      final intMetric = metrics.firstWhere((m) => m.name == 'int_gauge_type');
      final doubleMetric = metrics.firstWhere((m) => m.name == 'double_gauge_type');

      // Verify values and types
      expect(intMetric.points.first.value, equals(42));
      expect(doubleMetric.points.first.value, equals(42.5));

      // Verify we can't set wrong types
      expect(() => intGauge.record(42.5 as dynamic), throwsA(isA<TypeError>()));
    });
  });
}
