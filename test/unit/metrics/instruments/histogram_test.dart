// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('Histogram Instrument Tests', () {
    late Meter meter;
    late MemoryMetricExporter memoryExporter;

    setUp(() async {
      await OTel.reset();

      // Create a memory exporter for verification
      memoryExporter = MemoryMetricExporter();

      // Initialize OTel with our memory exporter
      await OTel.initialize(
        serviceName: 'histogram-test-service',
        metricExporter: memoryExporter,
        detectPlatformResources: false,
      );

      // Get a meter for our tests
      meter = OTel.meter('histogram-tests');
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('Histogram records values correctly', () async {
      // Create a histogram instrument
      final histogram = meter.createHistogram<double>(
        name: 'test_histogram',
        description: 'Test histogram for validation',
        unit: 'ms',
      );

      // Record values with different attributes
      final attrs1 = {'endpoint': '/api/users'}.toAttributes();
      final attrs2 = {'endpoint': '/api/products'}.toAttributes();

      // Record multiple values to build up a distribution
      histogram.record(10.0, attrs1);
      histogram.record(20.0, attrs1);
      histogram.record(30.0, attrs1);

      histogram.record(5.0, attrs2);
      histogram.record(15.0, attrs2);
      histogram.record(25.0, attrs2);

      histogram.record(50.0); // No attributes
      histogram.record(100.0); // No attributes

      // Force a collection
      await memoryExporter.forceFlush();

      // Get the collected metrics
      final metrics = memoryExporter.exportedMetrics;

      // We should have one metric (our histogram)
      expect(metrics.length, equals(1));

      // Find our histogram
      final metric = metrics.firstWhere(
        (m) => m.name == 'test_histogram',
        orElse: () => throw StateError('Histogram metric not found'),
      );

      // Check properties
      expect(metric.description, equals('Test histogram for validation'));
      expect(metric.unit, equals('ms'));

      // We should have 3 data points (one for each attributes set)
      final points = metric.points;
      expect(points.length, equals(3));

      // Find each data point by attributes
      final point1 = points.firstWhere(
        (p) => p.attributes.getString('endpoint') == '/api/users',
        orElse: () => throw StateError('Point with /api/users attributes not found'),
      );
      final point2 = points.firstWhere(
        (p) => p.attributes.getString('endpoint') == '/api/products',
        orElse: () => throw StateError('Point with /api/products attributes not found'),
      );
      final point3 = points.firstWhere(
        (p) => p.attributes.isEmpty,
        orElse: () => throw StateError('Point with no attributes not found'),
      );

      // Verify each point's aggregated values
      expect(point1.sum, equals(60.0));  // 10 + 20 + 30
      expect(point1.count, equals(3));

      expect(point2.sum, equals(45.0));  // 5 + 15 + 25
      expect(point2.count, equals(3));

      expect(point3.sum, equals(150.0)); // 50 + 100
      expect(point3.count, equals(2));

      // Verify histograms have buckets
      expect(point1.buckets, isNotNull);
      expect(point1.buckets.isNotEmpty, isTrue);
    });

    test('Histogram with custom boundaries', () async {
      // Create custom boundaries
      final boundaries = [10.0, 20.0, 50.0, 100.0];

      // Create a histogram with explicit boundaries
      final histogram = meter.createHistogram<double>(
        name: 'custom_histogram',
        description: 'Histogram with custom boundaries',
        boundaries: boundaries,
      );

      // Record values that fall into each bucket
      histogram.record(5.0);    // Bucket 0 (≤10)
      histogram.record(15.0);   // Bucket 1 (>10, ≤20)
      histogram.record(35.0);   // Bucket 2 (>20, ≤50)
      histogram.record(75.0);   // Bucket 3 (>50, ≤100)
      histogram.record(150.0);  // Bucket 4 (>100)

      // Force collection
      await memoryExporter.forceFlush();

      // Get metrics
      final metrics = memoryExporter.exportedMetrics;
      final metric = metrics.firstWhere((m) => m.name == 'custom_histogram');

      // Verify we have one data point
      expect(metric.points.length, equals(1));

      // Get the data point
      final point = metric.points.first;

      // Verify aggregated values
      expect(point.sum, equals(280.0)); // 5 + 15 + 35 + 75 + 150
      expect(point.count, equals(5));

      // Verify buckets match our expectations
      // Buckets should be length boundaries + 1 (for overflow bucket)
      expect(point.buckets.length, equals(boundaries.length + 1));

      // Verify bucket counts
      // The buckets should have counts: [1, 1, 1, 1, 1]
      expect(point.buckets[0], equals(1)); // ≤10 (contains 5.0)
      expect(point.buckets[1], equals(1)); // >10, ≤20 (contains 15.0)
      expect(point.buckets[2], equals(1)); // >20, ≤50 (contains 35.0)
      expect(point.buckets[3], equals(1)); // >50, ≤100 (contains 75.0)
      expect(point.buckets[4], equals(1)); // >100 (contains 150.0)
    });

    test('Histogram with integer values', () async {
      // Create a histogram for integers
      final histogram = meter.createHistogram<int>(
        name: 'int_histogram',
        description: 'Integer histogram',
      );

      // Record integer values
      histogram.record(10);
      histogram.record(20);
      histogram.record(30);

      // Force collection
      await memoryExporter.forceFlush();

      // Get metrics
      final metrics = memoryExporter.exportedMetrics;
      final metric = metrics.firstWhere((m) => m.name == 'int_histogram');

      // Get the data point
      final point = metric.points.first;

      // Verify values
      expect(point.sum, equals(60.0)); // 10 + 20 + 30, note conversion to double
      expect(point.count, equals(3));
    });

    test('Histogram with multiple collections', () async {
      // Create a histogram
      final histogram = meter.createHistogram<double>(
        name: 'multi_collection_histogram',
        description: 'Histogram with multiple collections',
      );

      // Record values
      histogram.record(10.0);
      histogram.record(20.0);

      // First collection
      await memoryExporter.forceFlush();

      // Record more values
      histogram.record(30.0);
      histogram.record(40.0);

      // Second collection
      await memoryExporter.forceFlush();

      // Get the latest metrics
      final metrics = memoryExporter.exportedMetrics;
      final metric = metrics.firstWhere((m) => m.name == 'multi_collection_histogram');

      // Get the data point from the second collection
      final point = metric.points.first;

      // Verify only the new values are present (assuming delta aggregation temporality)
      expect(point.sum, equals(70.0)); // 30 + 40
      expect(point.count, equals(2));
    });

    test('Histogram with attributes', () async {
      // Create a histogram
      final histogram = meter.createHistogram<double>(
        'attr_histogram',
      );

      // Create diverse attributes
      final attrs1 = {'service': 'auth', 'endpoint': '/login'}.toAttributes();
      final attrs2 = {'service': 'auth', 'endpoint': '/logout'}.toAttributes();
      final attrs3 = {'service': 'data', 'endpoint': '/query'}.toAttributes();

      // Record with different attribute combinations
      histogram.record(10.0, attrs1);
      histogram.record(20.0, attrs1);

      histogram.record(15.0, attrs2);

      histogram.record(25.0, attrs3);
      histogram.record(35.0, attrs3);

      // Force collection
      await memoryExporter.forceFlush();

      // Get metrics
      final metrics = memoryExporter.exportedMetrics;
      final metric = metrics.firstWhere((m) => m.name == 'attr_histogram');

      // We should have 3 data points (one for each attribute set)
      expect(metric.points.length, equals(3));

      // Find each point
      final point1 = metric.points.firstWhere(
        (p) => p.attributes.getString('endpoint') == '/login',
      );
      final point2 = metric.points.firstWhere(
        (p) => p.attributes.getString('endpoint') == '/logout',
      );
      final point3 = metric.points.firstWhere(
        (p) => p.attributes.getString('endpoint') == '/query',
      );

      // Verify values
      expect(point1.sum, equals(30.0)); // 10 + 20
      expect(point1.count, equals(2));

      expect(point2.sum, equals(15.0));
      expect(point2.count, equals(1));

      expect(point3.sum, equals(60.0)); // 25 + 35
      expect(point3.count, equals(2));
    });
  });
}
