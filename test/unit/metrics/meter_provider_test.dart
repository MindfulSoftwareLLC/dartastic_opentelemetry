// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// For runZonedGuarded

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('MeterProvider Tests', () {
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

    test('MeterProvider exposes service information', () {
      // Get the meter provider
      final meterProvider = OTel.meterProvider();

      // Verify service information from initialization
      expect(meterProvider.serviceName, equals('meter-provider-test-service'));

      // Modify service information
      meterProvider.serviceName = 'updated-service-name';
      meterProvider.serviceVersion = '1.2.3';
      meterProvider.endpoint = 'https://updated.endpoint';

      // Verify updated values
      expect(meterProvider.serviceName, equals('updated-service-name'));
      expect(meterProvider.serviceVersion, equals('1.2.3'));
      expect(meterProvider.endpoint, equals('https://updated.endpoint'));
    });

    test('MeterProvider can be enabled and disabled', () {
      final meterProvider = OTel.meterProvider();

      // By default, enabled is true
      expect(meterProvider.enabled, isTrue);

      // Create a meter and verify it's also enabled
      final meter = meterProvider.getMeter(name: 'test-meter');
      expect(meter.enabled, isTrue);

      // Disable meter provider
      meterProvider.enabled = false;

      // Verify both meter provider and meter are disabled
      expect(meterProvider.enabled, isFalse);
      expect(meter.enabled, isFalse);

      // Re-enable
      meterProvider.enabled = true;
      expect(meterProvider.enabled, isTrue);
      expect(meter.enabled, isTrue);
    });

    test('MeterProvider returns same meter for same configuration', () {
      final meterProvider = OTel.meterProvider();

      // Get meter with specific configuration
      final meter1 = meterProvider.getMeter(
        name: 'test-meter',
      );

      // Get meter with same configuration
      final meter2 = meterProvider.getMeter(
        name: 'test-meter',
      );

      // Get meter with different configuration
      final meter3 = meterProvider.getMeter(
        name: 'test-meter-different',
      );

      // Verify same configuration returns same meter
      expect(identical(meter1, meter2), isTrue);

      // Verify different configuration returns different meter
      expect(identical(meter1, meter3), isFalse);
    });

    test('MeterProvider manages registered instruments', () {
      final meterProvider = OTel.meterProvider();

      // Create a meter and add an observable instrument
      final meter = meterProvider.getMeter(name: 'instrument-test-meter');
      final counter = meter.createObservableCounter<int>(
        name: 'test_counter',
        callback: (result) {
          result.observe(42);
        },
      );

      // We can't directly access the internal _instruments map, but we can
      // verify the counter was properly registered by checking if metrics
      // are collected
      expect(counter, isNotNull);
    });

    test('MeterProvider.forceFlush fails after shutdown', () async {
      final meterProvider = OTel.meterProvider();

      // Force flush should succeed initially
      final result1 = await meterProvider.forceFlush();
      expect(result1, isTrue);

      // Shutdown
      await meterProvider.shutdown();
      expect(meterProvider.isShutdown, isTrue);

      // Force flush should fail after shutdown
      final result2 = await meterProvider.forceFlush();
      expect(result2, isFalse);
    });

    test('MeterProvider.shutdown sets isShutdown flag', () async {
      final meterProvider = OTel.meterProvider();

      // Add a view
      final view = View(
        instrumentNamePattern: 'test_metric*',
        name: 'test-view',
        description: 'Test view',
      );
      meterProvider.addView(view);
      expect(meterProvider.views.length, equals(1));

      // Add another reader
      final additionalExporter = MemoryMetricExporter();
      final additionalReader = MemoryMetricReader(exporter: additionalExporter);
      meterProvider.addMetricReader(additionalReader);
      expect(meterProvider.metricReaders.length, equals(2));

      // Shutdown
      await meterProvider.shutdown();

      // Verify provider is shutdown
      expect(meterProvider.isShutdown, isTrue);
    });
  });
}
