// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('Histogram Instrument Tests', () {
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
        serviceName: 'histogram-test-service',
        metricReader: metricReader,
        detectPlatformResources: false,
      );

      // Get a meter for our tests
      meter = OTel.meter('histogram-tests');
    });

    tearDown(() async {
      await OTel.shutdown();
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
      await metricReader.forceFlush();

      // Get the collected metrics
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported");

      // Find our histogram
      final metric = metrics.firstWhere(
        (m) => m.name == 'test_histogram',
        orElse: () => throw StateError(
            'Histogram metric not found: ${metrics.map((m) => m.name).join(', ')}'),
      );

      // Check properties
      expect(metric.description, equals('Test histogram for validation'));
      expect(metric.unit, equals('ms'));

      // We should have 3 data points (one for each attributes set)
      final points = metric.points;
      expect(points.length, equals(3),
          reason: "Expected 3 points, got ${points.length}");

      // Find each data point by attributes
      final usersPoints = points
          .where((p) => p.attributes.getString('endpoint') == '/api/users')
          .toList();

      final productsPoints = points
          .where((p) => p.attributes.getString('endpoint') == '/api/products')
          .toList();

      final noAttrPoints =
          points.where((p) => p.attributes.toList().isEmpty).toList();

      // Verify we found the points
      expect(usersPoints.isNotEmpty, isTrue,
          reason: "No points with '/api/users' endpoint attribute found");
      expect(productsPoints.isNotEmpty, isTrue,
          reason: "No points with '/api/products' endpoint attribute found");
      expect(noAttrPoints.isNotEmpty, isTrue,
          reason: "No points without attributes found");

      // Verify each point's aggregated values
      expect(usersPoints.first.histogram().sum, equals(60.0)); // 10 + 20 + 30
      expect(usersPoints.first.histogram().count, equals(3));

      expect(productsPoints.first.histogram().sum, equals(45.0)); // 5 + 15 + 25
      expect(productsPoints.first.histogram().count, equals(3));

      expect(noAttrPoints.first.histogram().sum, equals(150.0)); // 50 + 100
      expect(noAttrPoints.first.histogram().count, equals(2));

      // Verify histograms have buckets
      expect(usersPoints.first.histogram().bucketCounts, isNotNull);
      expect(usersPoints.first.histogram().bucketCounts.isNotEmpty, isTrue);
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
      histogram.record(5.0); // Bucket 0 (≤10)
      histogram.record(15.0); // Bucket 1 (>10, ≤20)
      histogram.record(35.0); // Bucket 2 (>20, ≤50)
      histogram.record(75.0); // Bucket 3 (>50, ≤100)
      histogram.record(150.0); // Bucket 4 (>100)

      // Force collection
      await metricReader.forceFlush();

      // Get metrics
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported");

      final metric = metrics.firstWhere((m) => m.name == 'custom_histogram',
          orElse: () => throw StateError(
              'custom_histogram metric not found: ${metrics.map((m) => m.name).join(', ')}'));

      // Verify we have at least one data point
      expect(metric.points.isNotEmpty, isTrue,
          reason: "No points found in metric");

      // Get the data point
      final point = metric.points.first;

      // Verify aggregated values
      expect(point.histogram().sum, equals(280.0)); // 5 + 15 + 35 + 75 + 150
      expect(point.histogram().count, equals(5));

      // Verify buckets match our expectations
      // Buckets should be length boundaries + 1 (for overflow bucket)
      expect(
          point.histogram().bucketCounts.length, equals(boundaries.length + 1));

      // Verify bucket counts
      // The buckets should have counts: [1, 1, 1, 1, 1]
      expect(
          point.histogram().bucketCounts[0], equals(1)); // ≤10 (contains 5.0)
      expect(point.histogram().bucketCounts[1],
          equals(1)); // >10, ≤20 (contains 15.0)
      expect(point.histogram().bucketCounts[2],
          equals(1)); // >20, ≤50 (contains 35.0)
      expect(point.histogram().bucketCounts[3],
          equals(1)); // >50, ≤100 (contains 75.0)
      expect(point.histogram().bucketCounts[4],
          equals(1)); // >100 (contains 150.0)
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
      await metricReader.forceFlush();

      // Get metrics
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported");

      final metric = metrics.firstWhere((m) => m.name == 'int_histogram',
          orElse: () => throw StateError(
              'int_histogram metric not found: ${metrics.map((m) => m.name).join(', ')}'));

      // Verify we have at least one data point
      expect(metric.points.isNotEmpty, isTrue,
          reason: "No points found in metric");

      // Get the data point
      final point = metric.points.first;

      // Verify values
      expect(point.histogram().sum,
          equals(60.0)); // 10 + 20 + 30, note conversion to double
      expect(point.histogram().count, equals(3));
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
      await metricReader.forceFlush();

      // Clear export data to ensure we only see new values
      memoryExporter.clear();

      // Record more values
      histogram.record(30.0);
      histogram.record(40.0);

      // Second collection
      await metricReader.forceFlush();

      // Get the latest metrics
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue,
          reason: "No metrics were exported in second collection");

      final metric = metrics.firstWhere(
          (m) => m.name == 'multi_collection_histogram',
          orElse: () => throw StateError(
              'multi_collection_histogram metric not found: ${metrics.map((m) => m.name).join(', ')}'));

      // Verify we have at least one data point
      expect(metric.points.isNotEmpty, isTrue,
          reason: "No points found in metric after second collection");

      // Get the data point from the second collection
      final point = metric.points.first;

      // With cumulative aggregation temporality, we expect all values to be present
      expect(point.histogram().sum, equals(100.0)); // 10 + 20 + 30 + 40
      expect(
          point.histogram().count, equals(4)); // All 4 values (10, 20, 30, 40)
    });

    test('Histogram with attributes', () async {
      // Create a histogram
      final histogram = meter.createHistogram<double>(
        name: 'attr_histogram',
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
      await metricReader.forceFlush();

      // Get metrics
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported");

      final metric = metrics.firstWhere((m) => m.name == 'attr_histogram',
          orElse: () => throw StateError(
              'attr_histogram metric not found: ${metrics.map((m) => m.name).join(', ')}'));

      // We should have 3 data points (one for each attribute set)
      expect(metric.points.length, equals(3),
          reason:
              "Expected 3 points (one for each attribute set), got ${metric.points.length}");

      // Find each point
      final loginPoints = metric.points
          .where((p) => p.attributes.getString('endpoint') == '/login')
          .toList();

      final logoutPoints = metric.points
          .where((p) => p.attributes.getString('endpoint') == '/logout')
          .toList();

      final queryPoints = metric.points
          .where((p) => p.attributes.getString('endpoint') == '/query')
          .toList();

      // Verify we found all points
      expect(loginPoints.isNotEmpty, isTrue,
          reason: "No points with '/login' endpoint attribute found");
      expect(logoutPoints.isNotEmpty, isTrue,
          reason: "No points with '/logout' endpoint attribute found");
      expect(queryPoints.isNotEmpty, isTrue,
          reason: "No points with '/query' endpoint attribute found");

      // Verify values
      expect(loginPoints.first.histogram().sum, equals(30.0)); // 10 + 20
      expect(loginPoints.first.histogram().count, equals(2));

      expect(logoutPoints.first.histogram().sum, equals(15.0));
      expect(logoutPoints.first.histogram().count, equals(1));

      expect(queryPoints.first.histogram().sum, equals(60.0)); // 25 + 35
      expect(queryPoints.first.histogram().count, equals(2));
    });
  });
}
