// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('CompositeMetricExporter Tests', () {
    late MemoryMetricExporter exporter1;
    late MemoryMetricExporter exporter2;
    late CompositeMetricExporter compositeExporter;
    late MemoryMetricReader metricReader;

    setUp(() async {
      await OTel.reset();

      // Create two memory exporters
      exporter1 = MemoryMetricExporter();
      exporter2 = MemoryMetricExporter();

      // Create the composite exporter with both memory exporters
      compositeExporter = CompositeMetricExporter([exporter1, exporter2]);

      // Create a metric reader with a separate exporter for test infrastructure
      metricReader = MemoryMetricReader();

      // Initialize OTel with the metric reader
      await OTel.initialize(
        serviceName: 'composite-exporter-test',
        metricReader: metricReader,
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('CompositeMetricExporter forwards metrics to all exporters', () async {
      // Create a meter and record some metrics
      final meter = OTel.meter('composite-test');
      final counter = meter.createCounter<int>(name: 'test_counter');

      counter.add(5);
      counter.add(10, {'service': 'api'}.toAttributes());

      // Collect metrics
      final data = await metricReader.collect();

      // Manually export metrics through our composite exporter
      final bool exportResult = await compositeExporter.export(data);
      expect(exportResult, isTrue);

      // Verify both exporters received the metrics
      final metrics1 = exporter1.exportedMetrics;
      final metrics2 = exporter2.exportedMetrics;

      // Both should have the counter metric
      expect(metrics1.isNotEmpty, isTrue);
      expect(metrics2.isNotEmpty, isTrue);

      // Find the test_counter metric in each exporter
      final metric1 = metrics1.firstWhere((m) => m.name == 'test_counter',
          orElse: () =>
              throw StateError('test_counter not found in exporter1'));
      final metric2 = metrics2.firstWhere((m) => m.name == 'test_counter',
          orElse: () =>
              throw StateError('test_counter not found in exporter2'));

      // Verify the metrics exist
      expect(metric1, isNotNull);
      expect(metric2, isNotNull);

      // Verify metric names
      expect(metric1.name, equals('test_counter'));
      expect(metric2.name, equals('test_counter'));
    });

    test('CompositeMetricExporter handles exporter failures gracefully',
        () async {
      // Create a test exporter that fails on export
      final failingExporter = _FailingMetricExporter();

      // Create a composite with the failing exporter and one normal one
      final compositeWithFailure = CompositeMetricExporter([
        failingExporter,
        exporter1,
      ]);

      // Clear previous metrics
      exporter1.clear();

      // Create a new instance with our test reader
      await OTel.reset();
      // Use a separate reader for test infrastructure
      final memoryMetricReader = MemoryMetricReader();

      await OTel.initialize(
        serviceName: 'failure-test-service',
        metricReader: memoryMetricReader,
        detectPlatformResources: false,
      );

      // Get a meter and record data
      final meter = OTel.meter('failure-test');
      final counter = meter.createCounter<int>(name: 'failure_counter');
      counter.add(42);

      // Collect metrics
      final data = await memoryMetricReader.collect();

      // Manually export through our composite exporter
      final bool result = await compositeWithFailure.export(data);

      // Since one exporter fails, the composite should return false
      expect(result, isFalse);

      // But metrics should still reach the working exporter
      expect(exporter1.exportedMetrics.isNotEmpty, isTrue);
    });

    test('CompositeMetricExporter forceFlush and shutdown calls all exporters',
        () async {
      // Create tracked exporters
      final trackedExporter1 = _TrackedMetricExporter();
      final trackedExporter2 = _TrackedMetricExporter();

      // Create composite
      final composite = CompositeMetricExporter([
        trackedExporter1,
        trackedExporter2,
      ]);

      // Create an empty MetricData for testing
      final emptyData = MetricData.empty();

      // Call export
      final bool result = await composite.export(emptyData);

      // Export should succeed
      expect(result, isTrue);

      // Verify both exporters had export called
      expect(trackedExporter1.exportCalled, isTrue);
      expect(trackedExporter2.exportCalled, isTrue);

      // Call forceFlush
      final bool flushResult = await composite.forceFlush();
      expect(flushResult, isTrue);

      // Verify both exporters had forceFlush called
      expect(trackedExporter1.forceFlushCalled, isTrue);
      expect(trackedExporter2.forceFlushCalled, isTrue);

      // Call shutdown
      final bool shutdownResult = await composite.shutdown();
      expect(shutdownResult, isTrue);

      // Verify both exporters had shutdown called
      expect(trackedExporter1.shutdownCalled, isTrue);
      expect(trackedExporter2.shutdownCalled, isTrue);
    });
  });
}

/// A test exporter that fails when export is called
class _FailingMetricExporter implements MetricExporter {
  String get name => 'FailingMetricExporter';

  @override
  Future<bool> export(MetricData data) async {
// This exporter intentionally fails and returns false to test that the composite exporter correctly propagates failures
    print('Intentional export failure that should be caught internally');
    return false;
  }

  @override
  Future<bool> forceFlush() async {
    return true;
  }

  @override
  Future<bool> shutdown() async {
    return true;
  }
}

/// A test exporter that tracks which methods were called
class _TrackedMetricExporter implements MetricExporter {
  bool exportCalled = false;
  bool forceFlushCalled = false;
  bool shutdownCalled = false;

  String get name => 'TrackedMetricExporter';

  @override
  Future<bool> export(MetricData data) async {
    exportCalled = true;
    return true;
  }

  @override
  Future<bool> forceFlush() async {
    forceFlushCalled = true;
    return true;
  }

  @override
  Future<bool> shutdown() async {
    shutdownCalled = true;
    return true;
  }
}
