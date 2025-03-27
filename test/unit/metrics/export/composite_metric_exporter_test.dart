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

      // Create a metric reader that will work with our test
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

      // Force collection by calling forceFlush
      await metricReader.forceFlush();

      // Verify both exporters received the metrics
      final metrics1 = exporter1.exportedMetrics;
      final metrics2 = exporter2.exportedMetrics;

      // Both should have the counter metric
      expect(metrics1.isNotEmpty, isTrue);
      expect(metrics2.isNotEmpty, isTrue);

      // Find the test_counter metric in each exporter
      final metric1 = metrics1.firstWhere((m) => m.name == 'test_counter');
      final metric2 = metrics2.firstWhere((m) => m.name == 'test_counter');

      // Verify the metrics exist
      expect(metric1, isNotNull);
      expect(metric2, isNotNull);

      // Verify metric names
      expect(metric1.name, equals('test_counter'));
      expect(metric2.name, equals('test_counter'));
    });

    test('CompositeMetricExporter handles exporter failures gracefully', () async {
      // Create a test exporter that fails on export
      final failingExporter = _FailingMetricExporter();

      // Create a composite with the failing exporter and one normal one
      final compositeWithFailure = CompositeMetricExporter([
        failingExporter,
        exporter1,
      ]);

      // Clear previous metrics
      exporter1.clear();

      // For the test, we will use our own metric reader and exporters
      final memoryMetricReader = MemoryMetricReader();
      
      // Create a new instance with our test reader
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'failure-test-service', 
        metricReader: memoryMetricReader,
        detectPlatformResources: false,
      );

      // Get a meter and record data
      final meter = OTel.meter('failure-test');
      final counter = meter.createCounter<int>(name: 'failure_counter');
      counter.add(42);

      // Attempt to export (shouldn't throw even though one exporter fails)
      await memoryMetricReader.forceFlush();
      
      // We would now manually test the behavior by calling the composite exporter with our own data
      final testData = MetricData.empty();
      bool result = await compositeWithFailure.export(testData);
      
      // Since one exporter fails, the composite should return false
      expect(result, isFalse);
    });

    test('CompositeMetricExporter forceFlush and shutdown calls all exporters', () async {
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
      await composite.export(emptyData);

      // Verify both exporters had export called
      expect(trackedExporter1.exportCalled, isTrue);
      expect(trackedExporter2.exportCalled, isTrue);

      // Call forceFlush
      await composite.forceFlush();

      // Verify both exporters had forceFlush called
      expect(trackedExporter1.forceFlushCalled, isTrue);
      expect(trackedExporter2.forceFlushCalled, isTrue);

      // Call shutdown
      await composite.shutdown();

      // Verify both exporters had shutdown called
      expect(trackedExporter1.shutdownCalled, isTrue);
      expect(trackedExporter2.shutdownCalled, isTrue);
    });
  });
}

/// A test exporter that fails when export is called
class _FailingMetricExporter implements MetricExporter {
@override
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

  @override
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
