// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('MetricReader Tests', () {
    late MemoryMetricExporter memoryExporter;
    late MemoryMetricReader metricReader;

    setUp(() async {
      await OTel.reset();

      // Create a memory exporter for verification
      memoryExporter = MemoryMetricExporter();

      // Create a metric reader
      metricReader = MemoryMetricReader(exporter: memoryExporter);

      // Initialize OTel with our metric reader
      await OTel.initialize(
        serviceName: 'metric-reader-test-service',
        metricReader: metricReader,
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('MetricReader forceFlush collects metrics', () async {
      // Get a meter and create a counter
      final meter = OTel.meter('forceflush-test');
      final counter = meter.createCounter<int>(name: 'forceflush_counter');

      // Add value to counter
      counter.add(50);

      // Force flush to collect metrics
      await metricReader.forceFlush();

      // Verify metrics were collected
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue);

      // Find our counter
      final counterMetric =
          metrics.where((m) => m.name == 'forceflush_counter').toList();
      expect(counterMetric.isNotEmpty, isTrue);
    });

    test('MetricReader collects metrics on demand', () async {
      // Create a meter and counter
      final meter = OTel.meter('on-demand-collection-test');
      final counter = meter.createCounter<int>(name: 'demand_counter');

      // Add value to counter
      counter.add(100);

      // Initially no metrics should be collected
      expect(memoryExporter.exportedMetrics, isEmpty);

      // Trigger manual collection
      await metricReader.forceFlush();

      // Now metrics should be present
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue);

      // Find our counter
      final counterMetric =
          metrics.where((m) => m.name == 'demand_counter').toList();
      expect(counterMetric.isNotEmpty, isTrue);
    });

    test('MetricReader shutdown works', () async {
      // Mark the reader as shutdown
      await metricReader.shutdown();

      // Create a meter and counter
      final meter = OTel.meter('shutdown-test');
      final counter = meter.createCounter<int>(name: 'shutdown_counter');
      counter.add(10);

      // Try to collect metrics (should not work after shutdown)
      await metricReader.forceFlush();

      // No metrics should be present (since reader is shutdown)
      final metrics = memoryExporter.exportedMetrics;
      expect(
          metrics.where((m) => m.name == 'shutdown_counter').isEmpty, isTrue);
    });
  });
}
