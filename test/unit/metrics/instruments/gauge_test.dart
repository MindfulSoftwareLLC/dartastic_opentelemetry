// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('Gauge Instrument Tests', () {
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
        serviceName: 'gauge-test-service',
        metricReader: metricReader,
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
      final gauge = meter.createGauge<double>(name: 'test_gauge',
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
      await metricReader.forceFlush();

      // Get the collected metrics
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported");

      // Find our gauge
      final metric = metrics.firstWhere(
        (m) => m.name == 'test_gauge',
        orElse: () => throw StateError('Gauge metric not found: ${metrics.map((m) => m.name).join(', ')}'),
      );

      // Check properties
      expect(metric.description, equals('Test gauge for validation'));
      expect(metric.unit, equals('ms'));

      // We should have 3 data points (one for each attributes set)
      final points = metric.points;
      expect(points.length, equals(3), reason: "Expected 3 points, got ${points.length}");

      // Find each data point by attributes
      final apiPoints = points.where((p) => 
          p.attributes.getString('service') == 'api').toList();
      
      final dbPoints = points.where((p) => 
          p.attributes.getString('service') == 'database').toList();
      
      final noAttrPoints = points.where((p) => 
          p.attributes.toList().isEmpty).toList();

      // Verify we found the points
      expect(apiPoints.isNotEmpty, isTrue, reason: "No points with 'api' service attribute found");
      expect(dbPoints.isNotEmpty, isTrue, reason: "No points with 'database' service attribute found");
      expect(noAttrPoints.isNotEmpty, isTrue, reason: "No points without attributes found");

      // Verify each point's value
      expect(apiPoints.first.value, equals(60.0));  // Updated from 50.0 to 60.0
      expect(dbPoints.first.value, equals(100.0));
      expect(noAttrPoints.first.value, equals(75.0));
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
      await metricReader.forceFlush();

      // Get the collected metrics
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported");
      
      final metric = metrics.firstWhere(
          (m) => m.name == 'int_gauge',
          orElse: () => throw StateError('int_gauge metric not found: ${metrics.map((m) => m.name).join(', ')}'));

      // Verify we have 2 data points
      expect(metric.points.length, equals(2), reason: "Expected 2 points, got ${metric.points.length}");

      // Find each point
      final noAttrsPoints = metric.points.where((p) => 
          p.attributes.toList().isEmpty).toList();
          
      final withAttrsPoints = metric.points.where((p) => 
          p.attributes.getString('type') == 'request').toList();

      // Verify we found the points
      expect(noAttrsPoints.isNotEmpty, isTrue, reason: "No points without attributes found");
      expect(withAttrsPoints.isNotEmpty, isTrue, reason: "No points with 'request' type attribute found");

      // Verify values
      expect(noAttrsPoints.first.value, equals(10));
      expect(withAttrsPoints.first.value, equals(20));
    });

    test('Gauge overwrites old values', () async {
      // Create a gauge
      final gauge = meter.createGauge<double>(name: 'overwrite_gauge');

      final attrs = {'endpoint': '/api/users'}.toAttributes();

      // Set initial value
      gauge.record(50.0, attrs);

      // Force collection
      await metricReader.forceFlush();
      
      // Verify initial value was recorded
      var metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported in first collection");
      
      // Clear the exporter to make verification clearer
      memoryExporter.clear();

      // Set new value (should overwrite)
      gauge.record(75.0, attrs);

      // Force another collection
      await metricReader.forceFlush();

      // Get the collected metrics from the second collection
      metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported in second collection");
      
      final metric = metrics.firstWhere(
          (m) => m.name == 'overwrite_gauge',
          orElse: () => throw StateError('overwrite_gauge metric not found: ${metrics.map((m) => m.name).join(', ')}'));

      // Verify we have at least one point
      expect(metric.points.isNotEmpty, isTrue, reason: "No points found in metric");

      // Find the point with our attributes
      final matchingPoints = metric.points.where((p) => 
          p.attributes.getString('endpoint') == '/api/users').toList();
      
      expect(matchingPoints.isNotEmpty, isTrue, 
          reason: "No points with '/api/users' endpoint attribute found. Available points: ${metric.points.map((p) => p.attributes.toString()).join(', ')}");

      // Verify the value was overwritten
      expect(matchingPoints.first.value, equals(75.0));
    });

    test('Gauge with different types', () async {
      // Create gauges with different types
      final intGauge = meter.createGauge<int>(name: 'int_gauge_type');
      final doubleGauge = meter.createGauge<double>(name: 'double_gauge_type');

      // Set values
      intGauge.record(42);
      doubleGauge.record(42.5);

      // Force collection
      await metricReader.forceFlush();

      // Get metrics
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported");
      
      final intMetric = metrics.firstWhere(
          (m) => m.name == 'int_gauge_type',
          orElse: () => throw StateError('int_gauge_type metric not found: ${metrics.map((m) => m.name).join(', ')}'));
          
      final doubleMetric = metrics.firstWhere(
          (m) => m.name == 'double_gauge_type',
          orElse: () => throw StateError('double_gauge_type metric not found: ${metrics.map((m) => m.name).join(', ')}'));

      // Verify we have at least one point for each metric
      expect(intMetric.points.isNotEmpty, isTrue, reason: "No points found in int_gauge_type metric");
      expect(doubleMetric.points.isNotEmpty, isTrue, reason: "No points found in double_gauge_type metric");

      // Verify values and types
      expect(intMetric.points.first.value, equals(42));
      expect(doubleMetric.points.first.value, equals(42.5));
    });
  });
}
