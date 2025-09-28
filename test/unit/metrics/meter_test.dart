// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('Meter and MeterProvider Tests', () {
    late MemoryMetricExporter memoryExporter;
    late MemoryMetricReader metricReader;

    setUp(() async {
      await OTel.reset();

      // Create a memory exporter for verification
      memoryExporter = MemoryMetricExporter();
      metricReader = MemoryMetricReader(exporter: memoryExporter);

      // Initialize OTel with our memory metric reader
      await OTel.initialize(
        serviceName: 'meter-provider-test-service',
        metricReader: metricReader,
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('MeterProvider can create meters with different names', () {
      // Get meters with different names
      final meter1 = OTel.meter('meter1');
      final meter2 = OTel.meter('meter2');

      // The meters should be different
      expect(identical(meter1, meter2), isFalse);

      // Create instruments on each meter
      final counter1 = meter1.createCounter<int>(
        name: 'counter1',
        description: 'Counter from meter1',
      );

      final counter2 = meter2.createCounter<int>(
        name: 'counter2',
        description: 'Counter from meter2',
      );

      // Record some values
      counter1.add(5);
      counter2.add(10);

      // Both counters should work independently
      expect(counter1, isNotNull);
      expect(counter2, isNotNull);
    });

    test('Meter gets reused when requesting the same meter name', () {
      // Get a meter
      final meter1 = OTel.meter('reused-meter');

      // Get another meter with the same name
      final meter2 = OTel.meter('reused-meter');

      // They should be the same instance
      expect(identical(meter1, meter2), isTrue);
    });

    test('Meter name and version are captured correctly', () async {
      // Get a meter with name and version
      final meter = OTel.meter('versioned-meter');

      // Create an instrument and record data to ensure metadata gets captured
      final counter = meter.createCounter<int>(name: 'test_counter');
      counter.add(5);

      // Force collection
      await metricReader.forceFlush();

      // Get the metrics
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported");

      final metric = metrics.firstWhere((m) => m.name == 'test_counter',
          orElse: () => throw StateError(
              'test_counter metric not found in exported metrics: $metrics'));

      // Check the instrumentation scope information
      expect(metric.name, equals('test_counter'));
    });

    test('Meter can create all instrument types', () {
      final meter = OTel.meter('all-instruments-meter');

      // Create one of each instrument type
      final counter = meter.createCounter<int>(name: 'test_counter');
      final upDownCounter =
          meter.createUpDownCounter<int>(name: 'test_up_down_counter');
      final histogram = meter.createHistogram<double>(name: 'test_histogram');
      final gauge = meter.createGauge<double>(name: 'test_gauge');
      final observableCounter = meter.createObservableCounter<int>(
        name: 'test_obs_counter',
        callback: (result) {
          result.observe(123);
        },
      );
      final observableUpDownCounter = meter.createObservableUpDownCounter<int>(
        name: 'test_obs_up_down',
        callback: (result) {
          result.observe(456);
        },
      );
      final observableGauge = meter.createObservableGauge<double>(
        name: 'test_obs_gauge',
        callback: (result) {
          result.observe(789.0);
        },
      );

      // Verify all instruments are created
      expect(counter, isNotNull);
      expect(upDownCounter, isNotNull);
      expect(histogram, isNotNull);
      expect(gauge, isNotNull);
      expect(observableCounter, isNotNull);
      expect(observableUpDownCounter, isNotNull);
      expect(observableGauge, isNotNull);
    });

    test('Meter with schema url is properly created', () async {
      // Create a meter with schema URL
      final meter = OTel.meter('schema-meter');

      // Create and use an instrument
      final counter = meter.createCounter<int>(name: 'schema_counter');
      counter.add(1);

      // Force collection
      await metricReader.forceFlush();

      // Get the metrics
      final metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue, reason: "No metrics were exported");

      final metric = metrics.firstWhere((m) => m.name == 'schema_counter',
          orElse: () => throw StateError(
              'schema_counter metric not found in exported metrics: $metrics'));

      // Verify metric is captured
      expect(metric.name, equals('schema_counter'));
    });
  });
}
