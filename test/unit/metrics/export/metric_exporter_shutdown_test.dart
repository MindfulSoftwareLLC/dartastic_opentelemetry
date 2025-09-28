// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

class MockMetricExporter implements MetricExporter {
  bool _isShutdown = false;
  bool _forceFlushCalled = false;
  final List<MetricData> _exportedData = [];

  List<MetricData> get exportedData => List.unmodifiable(_exportedData);
  bool get isShutdown => _isShutdown;
  bool get forceFlushCalled => _forceFlushCalled;

  @override
  Future<bool> export(MetricData data) async {
    if (_isShutdown) {
      return false;
    }
    _exportedData.add(data);
    return true;
  }

  @override
  Future<bool> forceFlush() async {
    _forceFlushCalled = true;
    return !_isShutdown;
  }

  @override
  Future<bool> shutdown() async {
    _isShutdown = true;
    return true;
  }
}

void main() {
  group('MetricExporter Shutdown Tests', () {
    late MockMetricExporter exporter;
    late MetricReader reader;

    setUp(() async {
      exporter = MockMetricExporter();
      reader = PeriodicExportingMetricReader(exporter,
          interval: const Duration(milliseconds: 100));

      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        metricReader: reader,
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('Exporter rejects data after shutdown', () async {
      // Create and record a metric before shutdown
      final meter = OTel.meter('shutdown-test');
      final counter = meter.createCounter<int>(
        name: 'test-counter',
        unit: 'count',
      );

      counter.add(5);

      // Force flush to ensure data is exported
      await reader.forceFlush();

      // Verify data was exported
      expect(exporter.exportedData.isNotEmpty, isTrue);
      expect(exporter.isShutdown, isFalse);

      // Shutdown the exporter
      await exporter.shutdown();
      expect(exporter.isShutdown, isTrue);

      // Clear the exported data to verify nothing new comes in
      exporter._exportedData.clear();

      // Record more data
      counter.add(10);

      // Try to flush again
      await reader.forceFlush();

      // Verify no new data was exported
      expect(exporter.exportedData.isEmpty, isTrue);
    });

    test('MetricReader shutdown propagates to exporter', () async {
      // Create a metric
      final meter = OTel.meter('shutdown-test');
      final counter = meter.createCounter<int>(
        name: 'propagation-counter',
        unit: 'count',
      );

      counter.add(42);

      // Verify exporter is not yet shutdown
      expect(exporter.isShutdown, isFalse);

      // Shutdown the reader
      await reader.shutdown();

      // Verify exporter was also shutdown
      expect(exporter.isShutdown, isTrue);

      // Try to record more data
      counter.add(100);

      // Try to flush again - this should not add more data
      await reader.forceFlush();

      // Check that only the first data point was exported
      expect(exporter.exportedData.length, equals(1));
    });

    test('MeterProvider shutdown propagates to readers and exporters',
        () async {
      // Create a metric
      final meter = OTel.meter('shutdown-test');
      final counter = meter.createCounter<int>(
        name: 'provider-shutdown-counter',
        unit: 'count',
      );

      counter.add(7);

      // Get meter provider
      final meterProvider = OTel.meterProvider();

      // Verify exporter is not yet shutdown
      expect(exporter.isShutdown, isFalse);

      // Shutdown the meter provider
      await meterProvider.shutdown();

      // Verify exporter was also shutdown
      expect(exporter.isShutdown, isTrue);

      // Verify the provider's isShutdown state
      expect(meterProvider.isShutdown, isTrue);

      // Try to create a new meter with the shutdown provider
      final newMeter = meterProvider.getMeter(name: 'shutdown-test-2');

      // Creating a meter with a shutdown provider should succeed but meters will be disabled
      expect(newMeter, isNotNull);
    });

    test('OTel.reset() properly shuts down existing providers', () async {
      // Create a metric
      final meter = OTel.meter('reset-test');
      final counter = meter.createCounter<int>(
        name: 'reset-counter',
        unit: 'count',
      );

      counter.add(3);

      // Verify exporter is not yet shutdown
      expect(exporter.isShutdown, isFalse);

      // Reset OTel
      await OTel.reset();

      // Verify exporter was shutdown
      expect(exporter.isShutdown, isTrue);
    });
  });
}
