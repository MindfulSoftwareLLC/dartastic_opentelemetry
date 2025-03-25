// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';
import '../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('MetricReader Tests', () {
    late MemoryMetricExporter memoryExporter;

    setUp(() async {
      await OTel.reset();

      // Create a memory exporter for verification
      memoryExporter = MemoryMetricExporter();

      // Initialize OTel with our memory exporter
      await OTel.initialize(
        serviceName: 'metric-reader-test-service',
        metricExporter: memoryExporter,
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('MetricReader collects metrics on schedule', () async {
      // Create a metric reader with a short collection interval
      final reader = PeriodicMetricReader(
        exporter: memoryExporter,
        intervalMillis: 100, // Very short for testing
      );

      // Create a meter provider with this reader
      final meterProvider = OTelFactory.otelFactory!.meterProvider(
        resource: OTel.resource,
        metricReader: reader,
      );

      // Get a meter and create a counter
      final meter = meterProvider.getMeter('scheduled-collection-test');
      final counter = meter.createCounter<int>('scheduled_counter');

      // Add value to counter
      counter.add(42);

      // Wait for the scheduled collection to happen
      await Future.delayed(Duration(milliseconds: 150));

      // Verify metrics were collected
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue);
      expect(metrics.first.name, equals('scheduled_counter'));

      // Shutdown the reader
      await reader.shutdown();
    });

    test('MetricReader collects metrics on demand', () async {
      // Create a reader without automatic collection
      final reader = CustomMetricReader(memoryExporter);

      // Create a meter provider with this reader
      final meterProvider = OTelFactory.otelFactory!.createMeterProvider(
        resource: OTel.resource,
        metricReader: reader,
      );

      // Get a meter and create a counter
      final meter = meterProvider.getMeter('on-demand-collection-test');
      final counter = meter.createCounter<int>('demand_counter');

      // Add value to counter
      counter.add(100);

      // Initially no metrics should be collected
      expect(memoryExporter.getMetrics(), isEmpty);

      // Trigger manual collection
      await reader.collect();

      // Now metrics should be present
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue);
      expect(metrics.first.name, equals('demand_counter'));
    });

    test('MetricReader forceFlush and shutdown work', () async {
      // Create a tracked exporter to verify method calls
      final trackedExporter = _TrackedMetricExporter();

      // Create a reader with this exporter
      final reader = CustomMetricReader(trackedExporter);

      // Create a meter provider with this reader
      final meterProvider = OTelFactory.otelFactory!.createMeterProvider(
        resource: OTel.resource,
        metricReader: reader,
      );

      // Call forceFlush
      await meterProvider.forceFlush();

      // Verify forceFlush was called on the exporter
      expect(trackedExporter.forceFlushCalled, isTrue);

      // Call shutdown
      await meterProvider.shutdown();

      // Verify shutdown was called on the exporter
      expect(trackedExporter.shutdownCalled, isTrue);
    });
  });
}

/// A simple metric reader for on-demand metric collection
class CustomMetricReader extends MetricReader {
  final MetricExporter _exporter;

  CustomMetricReader(this._exporter);

  @override
  Future<void> collect() async {
    final metrics = await collectMetrics();
    await _exporter.export(metrics);
  }

  @override
  Future<void> forceFlush() async {
    await _exporter.forceFlush();
  }

  @override
  Future<void> shutdown() async {
    await _exporter.shutdown();
  }
}

/// A test exporter that tracks which methods were called
class _TrackedMetricExporter implements MetricExporter {
  bool forceFlushCalled = false;
  bool shutdownCalled = false;
  List<Metric> lastExportedMetrics = [];

  @override
  Future<void> export(List<Metric> metrics) async {
    lastExportedMetrics = metrics;
  }

  @override
  Future<void> forceFlush() async {
    forceFlushCalled = true;
  }

  @override
  Future<void> shutdown() async {
    shutdownCalled = true;
  }
}
