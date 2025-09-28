// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('Gauge Extended Tests', () {
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

    test('Gauge reports correct type properties', () {
      final gauge = meter.createGauge<double>(
        name: 'test-gauge',
        description: 'Test gauge',
        unit: 'celsius',
      );

      // Check instrument properties
      expect(gauge.isCounter, isFalse);
      expect(gauge.isUpDownCounter, isFalse);
      expect(gauge.isGauge, isTrue);
      expect(gauge.isHistogram, isFalse);
    });

    test('Gauge with disabled provider', () async {
      final gauge = meter.createGauge<double>(
        name: 'disabled-gauge',
        description: 'Test disabled gauge',
      );

      // Record initial value
      gauge.record(25.5);

      // Force a collection
      await metricReader.forceFlush();

      // Get the metrics
      var metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue);

      // Disable the meter provider
      OTel.meterProvider().enabled = false;

      // Record more measurements
      gauge.record(30.2);

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
      gauge.record(35.8);

      // Force another collection
      await metricReader.forceFlush();

      // Verify metrics are now exported
      metrics = memoryExporter.exportedMetrics;
      expect(metrics.isNotEmpty, isTrue);
    });

    test('Gauge supports different number types', () async {
      // Integer gauge
      final intGauge = meter.createGauge<int>(
        name: 'int-gauge',
        unit: 'count',
      );

      // Double gauge
      final doubleGauge = meter.createGauge<double>(
        name: 'double-gauge',
        unit: 'percentage',
      );

      // Record values
      intGauge.record(42);
      doubleGauge.record(3.14);

      // Force collection
      await metricReader.forceFlush();

      // Get metrics
      final metrics = memoryExporter.exportedMetrics;

      // Find our gauges
      final intMetric = metrics.firstWhere((m) => m.name == 'int-gauge');
      final doubleMetric = metrics.firstWhere((m) => m.name == 'double-gauge');

      // Verify values
      expect(intMetric.points.first.value, equals(42));
      expect(doubleMetric.points.first.value, equals(3.14));
    });

    test('Gauge with recordWithMap', () async {
      final gauge = meter.createGauge<double>(
        name: 'map-attributes-gauge',
        unit: 'celsius',
      ) as Gauge<
          double>; // Cast to implementation class to access recordWithMap

      // Record using recordWithMap
      gauge.recordWithMap(23.5, {
        'location': 'outside',
        'sensor': 'primary',
      });

      // Force collection
      await metricReader.forceFlush();

      // Get metric
      final metric = memoryExporter.exportedMetrics
          .firstWhere((m) => m.name == 'map-attributes-gauge');

      // Verify value
      expect(metric.points.length, equals(1));
      expect(metric.points.first.value, equals(23.5));

      // Verify attributes
      final attributes = metric.points.first.attributes;
      expect(attributes.getString('location'), equals('outside'));
      expect(attributes.getString('sensor'), equals('primary'));
    });

    test('Gauge.getValue returns most recent value', () {
      final gauge = meter.createGauge<int>(
        name: 'get-value-gauge',
      ) as Gauge<int>; // Cast to implementation class to access getValue

      // Record values with different attributes
      final attrs1 = {'region': 'north'}.toAttributes();
      final attrs2 = {'region': 'south'}.toAttributes();

      gauge.record(50, attrs1);
      gauge.record(30, attrs2);
      gauge.record(75, attrs1); // Update value for attrs1

      // Get values using getValue - for gauge, this should return the latest value for each attribute set
      expect(gauge.getValue(attrs1), equals(75));
      expect(gauge.getValue(attrs2), equals(30));

      // Note: Gauge.getValue requires attributes parameter and doesn't have a version without parameters
      // So we test with a specific attribute set again
      final emptyAttrs = OTel.attributes();
      gauge.record(100, emptyAttrs);
      expect(gauge.getValue(emptyAttrs), equals(100));
    });

    test('Gauge handles negative values correctly', () async {
      final gauge = meter.createGauge<double>(
        name: 'temperature-gauge',
        unit: 'celsius',
      );

      // Record negative value
      gauge.record(-15.5);

      // Force collection
      await metricReader.forceFlush();

      // Get metric
      final metric = memoryExporter.exportedMetrics
          .firstWhere((m) => m.name == 'temperature-gauge');

      // Verify negative value
      expect(metric.points.first.value, equals(-15.5));
    });

    test('Gauge overwrites previous values with same attributes', () async {
      final gauge = meter.createGauge<double>(
        name: 'update-gauge',
        unit: 'percentage',
      );

      final attributes = {'system': 'cpu'}.toAttributes();

      // Record initial value
      gauge.record(50.0, attributes);

      // Update with new value using same attributes
      gauge.record(75.5, attributes);

      // Force collection
      await metricReader.forceFlush();

      // Get metric
      final metric = memoryExporter.exportedMetrics
          .firstWhere((m) => m.name == 'update-gauge');

      // Verify only latest value is reported
      expect(metric.points.length, equals(1));
      expect(metric.points.first.value, equals(75.5));
    });

    test('Gauge collectMetrics respects enabled state', () {
      final gauge = meter.createGauge<double>(
        name: 'collect-metrics-gauge',
      ) as Gauge<double>;

      // Record a value
      gauge.record(42.5);

      // Verify metric collection works when enabled
      var metrics = gauge.collectMetrics();
      expect(metrics.length, equals(1));

      // Disable the meter provider
      OTel.meterProvider().enabled = false;

      // Verify no metrics are collected when disabled
      metrics = gauge.collectMetrics();
      expect(metrics.isEmpty, isTrue);
    });
  });
}
