// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('Histogram Extended Tests', () {
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
        serviceName: 'histogram-extended-test-service',
        metricReader: metricReader,
        detectPlatformResources: false,
      );

      // Get a meter for our tests
      meter = OTel.meter('histogram-extended-tests');
    });

    tearDown(() async {
      await OTel.shutdown();
    });

    test('Histogram reports correct type properties', () {
      final histogram = meter.createHistogram<double>(
        name: 'test-histogram',
        description: 'Test histogram',
        unit: 'ms',
      );

      // Check instrument properties
      expect(histogram.isCounter, isFalse);
      expect(histogram.isUpDownCounter, isFalse);
      expect(histogram.isGauge, isFalse);
      expect(histogram.isHistogram, isTrue);
    });

    test('Histogram with disabled provider', () async {
      final histogram = meter.createHistogram<double>(
        name: 'disabled-histogram',
        description: 'Test disabled histogram',
      );

      // Record initial values
      histogram.record(10.0);
      histogram.record(20.0);

      // Force a collection
      await metricReader.forceFlush();

      // Get the metrics
      var metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue);

      // Disable the meter provider
      OTel.meterProvider().enabled = false;

      // Record more measurements
      histogram.record(30.0);

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
      histogram.record(40.0);

      // Force another collection
      await metricReader.forceFlush();

      // Verify metrics are now exported
      metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue);
    });

    test('Histogram supports different number types', () async {
      // Integer histogram
      final intHistogram = meter.createHistogram<int>(
        name: 'int-histogram',
        unit: 'bytes',
      );

      // Double histogram
      final doubleHistogram = meter.createHistogram<double>(
        name: 'double-histogram',
        unit: 'seconds',
      );

      // Record values
      intHistogram.record(42);
      intHistogram.record(100);

      doubleHistogram.record(1.5);
      doubleHistogram.record(2.75);

      // Force collection
      await metricReader.forceFlush();

      // Get metrics
      final metrics = memoryExporter.exportedMetrics;

      // Find our histograms
      final intMetric = metrics.firstWhere((m) => m.name == 'int-histogram');
      final doubleMetric =
          metrics.firstWhere((m) => m.name == 'double-histogram');

      // Verify int histogram
      expect(intMetric.points.first.histogram().sum, equals(142.0)); // 42 + 100
      expect(intMetric.points.first.histogram().count, equals(2));

      // Verify double histogram
      expect(doubleMetric.points.first.histogram().sum,
          equals(4.25)); // 1.5 + 2.75
      expect(doubleMetric.points.first.histogram().count, equals(2));
    });

    test('Histogram with custom boundaries', () async {
      // Define custom boundaries for fine-grained latency tracking
      final boundaries = [
        1.0,
        5.0,
        10.0,
        25.0,
        50.0,
        100.0,
        250.0,
        500.0,
        1000.0
      ];

      final histogram = meter.createHistogram<double>(
        name: 'custom-boundaries-histogram',
        unit: 'ms',
        boundaries: boundaries,
      );

      // Record values to hit different buckets
      histogram.record(3); // Bucket 1 (>1, ≤5)
      histogram.record(7); // Bucket 2 (>5, ≤10)
      histogram.record(15); // Bucket 3 (>10, ≤25)
      histogram.record(75); // Bucket 5 (>50, ≤100)
      histogram.record(600); // Bucket 8 (>500, ≤1000)

      // Force collection
      await metricReader.forceFlush();

      // Get metric
      final metric = memoryExporter.exportedMetrics
          .firstWhere((m) => m.name == 'custom-boundaries-histogram');

      // Verify histogram data
      final histData = metric.points.first.histogram();

      // Check sum and count
      expect(histData.sum, equals(700.0)); // 3 + 7 + 15 + 75 + 600
      expect(histData.count, equals(5));

      // Check boundaries
      expect(histData.boundaries, equals(boundaries));

      // Verify bucket counts match our expectations
      final counts = histData.bucketCounts;

      // Expected distribution:
      // Bucket 0 (≤1): 0 values
      // Bucket 1 (>1, ≤5): 1 value (3)
      // Bucket 2 (>5, ≤10): 1 value (7)
      // Bucket 3 (>10, ≤25): 1 value (15)
      // Bucket 4 (>25, ≤50): 0 values
      // Bucket 5 (>50, ≤100): 1 value (75)
      // Bucket 6 (>100, ≤250): 0 values
      // Bucket 7 (>250, ≤500): 0 values
      // Bucket 8 (>500, ≤1000): 1 value (600)
      // Bucket 9 (>1000): 0 values

      expect(counts.length, equals(boundaries.length + 1));
      expect(counts[0], equals(0)); // ≤1
      expect(counts[1], equals(1)); // >1, ≤5
      expect(counts[2], equals(1)); // >5, ≤10
      expect(counts[3], equals(1)); // >10, ≤25
      expect(counts[4], equals(0)); // >25, ≤50
      expect(counts[5], equals(1)); // >50, ≤100
      expect(counts[6], equals(0)); // >100, ≤250
      expect(counts[7], equals(0)); // >250, ≤500
      expect(counts[8], equals(1)); // >500, ≤1000
      expect(counts[9], equals(0)); // >1000
    });

    test('Histogram.getValue returns sum of recorded values', () {
      final histogram = meter.createHistogram<double>(
        name: 'get-value-histogram',
      ) as Histogram<double>; // Cast to implementation class to access getValue

      // Record values with different attributes
      final attrs1 = {'endpoint': '/api/users'}.toAttributes();
      final attrs2 = {'endpoint': '/api/products'}.toAttributes();

      histogram.record(10.0, attrs1);
      histogram.record(20.0, attrs1);
      histogram.record(15.0, attrs2);
      histogram.record(25.0, attrs2);

      // Get histogram values using getValue and extract sum
      final histValue1 = histogram.getValue(attrs1);
      final histValue2 = histogram.getValue(attrs2);
      final histValueTotal = histogram.getValue();

      // Extract sums from histogram values
      expect(histValue1.sum, equals(30.0)); // 10 + 20
      expect(histValue2.sum, equals(40.0)); // 15 + 25
      expect(histValueTotal.sum, equals(70.0)); // 10 + 20 + 15 + 25

      // Also verify counts
      expect(histValue1.count, equals(2));
      expect(histValue2.count, equals(2));
      expect(histValueTotal.count, equals(4));
    });

    test('Histogram with recordWithMap', () async {
      final histogram = meter.createHistogram<double>(
        name: 'map-attributes-histogram',
        unit: 'ms',
      ) as Histogram<
          double>; // Cast to implementation class to access recordWithMap

      // Record using recordWithMap
      histogram.recordWithMap(15.5, {
        'method': 'GET',
        'status': 200,
      });

      histogram.recordWithMap(250.0, {
        'method': 'POST',
        'status': 201,
      });

      // Force collection
      await metricReader.forceFlush();

      // Get metric
      final metric = memoryExporter.exportedMetrics
          .firstWhere((m) => m.name == 'map-attributes-histogram');

      // Verify we have two data points (one for each attribute set)
      expect(metric.points.length, equals(2));

      // Find each point
      final getPoint = metric.points
          .firstWhere((p) => p.attributes.getString('method') == 'GET');

      final postPoint = metric.points
          .firstWhere((p) => p.attributes.getString('method') == 'POST');

      // Verify values
      expect(getPoint.histogram().sum, equals(15.5));
      expect(getPoint.histogram().count, equals(1));

      expect(postPoint.histogram().sum, equals(250.0));
      expect(postPoint.histogram().count, equals(1));
    });

    test('Histogram collectMetrics respects enabled state', () {
      final histogram = meter.createHistogram<double>(
        name: 'collect-metrics-histogram',
      ) as Histogram<double>;

      // Record a value
      histogram.record(42.5);

      // Verify metric collection works when enabled
      var metrics = histogram.collectMetrics();
      expect(metrics.length, equals(1));

      // Disable the meter provider
      OTel.meterProvider().enabled = false;

      // Verify no metrics are collected when disabled
      metrics = histogram.collectMetrics();
      expect(metrics.isEmpty, isTrue);
    });

    test('Histogram collectPoints returns all points', () {
      final histogram = meter.createHistogram<double>(
        name: 'collect-points-histogram',
      ) as Histogram<double>;

      // Record values with different attributes
      final attrs1 = {'region': 'east'}.toAttributes();
      final attrs2 = {'region': 'west'}.toAttributes();

      histogram.record(100.0, attrs1);
      histogram.record(200.0, attrs2);

      // Collect points
      final points = histogram.collectPoints();

      // Verify points are collected correctly
      expect(points.length, equals(2));

      // Find each point
      final eastPoint =
          points.firstWhere((p) => p.attributes.getString('region') == 'east');

      final westPoint =
          points.firstWhere((p) => p.attributes.getString('region') == 'west');

      // Verify values
      expect(eastPoint.histogram().sum, equals(100.0));
      expect(westPoint.histogram().sum, equals(200.0));
    });

    test('Histogram reset clears accumulated values', () async {
      final histogram = meter.createHistogram<double>(
        name: 'reset-histogram',
      ) as Histogram<double>;

      // Record initial values
      histogram.record(10.0);
      histogram.record(20.0);

      // Force collection
      await metricReader.forceFlush();

      // Verify the exported metric
      var metric = memoryExporter.exportedMetrics
          .firstWhere((m) => m.name == 'reset-histogram');

      expect(metric.points.first.histogram().sum, equals(30.0)); // 10 + 20

      // Reset the histogram
      histogram.reset();

      // Clear exporter
      memoryExporter.clear();

      // Record new values after reset
      histogram.record(5.0);

      // Force collection
      await metricReader.forceFlush();

      // Get the new metric
      metric = memoryExporter.exportedMetrics
          .firstWhere((m) => m.name == 'reset-histogram');

      // Verify only new value is present
      expect(metric.points.first.histogram().sum, equals(5.0));
      expect(metric.points.first.histogram().count, equals(1));
    });
  });
}
