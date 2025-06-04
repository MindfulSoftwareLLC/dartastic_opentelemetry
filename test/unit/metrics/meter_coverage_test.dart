// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart' show LogFunction, OTelAPI;
import 'package:test/test.dart';
import '../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('Meter Advanced Coverage Tests', () {
    late MemoryMetricExporter memoryExporter;
    late MemoryMetricReader metricReader;

    setUp(() async {
      await OTel.reset();

      // Create a memory exporter for verification
      memoryExporter = MemoryMetricExporter();
      metricReader = MemoryMetricReader(exporter: memoryExporter);

      // Initialize OTel with our memory metric reader
      await OTel.initialize(
        serviceName: 'meter-coverage-test-service',
        metricReader: metricReader,
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.shutdown();
    });

    test('Meter properties are properly exposed', () {
      // Get a meter with specific properties - use only the properties that exist
      final meter = OTel.meter('property-test-meter');

      // Verify the properties are correctly exposed
      expect(meter.name, equals('property-test-meter'));
      expect(meter.enabled, isTrue);
    });

    test('MeterProvider can be disabled and re-enabled', () {
      final meterProvider = OTel.meterProvider();
      final meter = OTel.meter('enabled-test-meter');

      // Initially enabled
      expect(meterProvider.enabled, isTrue);
      expect(meter.enabled, isTrue);

      // Disable the provider
      meterProvider.enabled = false;
      expect(meterProvider.enabled, isFalse);
      expect(meter.enabled, isFalse); // Meter should reflect provider state

      // Re-enable the provider
      meterProvider.enabled = true;
      expect(meterProvider.enabled, isTrue);
      expect(meter.enabled, isTrue);
    });

    test('NoopMeter instruments create NoOp implementations when SDK not initialized', () async {
      // Reset the SDK state to force NoOp behavior
      await OTel.reset();
      OTelAPI.initialize();

      // Get a meter WITHOUT initializing the SDK - this should return NoOp implementations
      final noopMeter = OTel.meter('noop-test-meter');
      
      // Verify the meter is a NoOp implementation (API factory creates disabled meters)
      expect(noopMeter.enabled, isFalse);

      // Create instruments and verify they work without errors (NoOp behavior)
      final counter = noopMeter.createCounter<int>(name: 'noop_counter');
      final upDownCounter = noopMeter.createUpDownCounter<int>(name: 'noop_up_down');
      final histogram = noopMeter.createHistogram<double>(name: 'noop_histogram');
      final gauge = noopMeter.createGauge<double>(name: 'noop_gauge');
      final obsCounter = noopMeter.createObservableCounter<int>(
        name: 'noop_obs_counter',
        callback: (result) {
          result.observe(123);
        },
      );
      final obsUpDown = noopMeter.createObservableUpDownCounter<int>(
        name: 'noop_obs_up_down',
        callback: (result) {
          result.observe(456);
        },
      );
      final obsGauge = noopMeter.createObservableGauge<double>(
        name: 'noop_obs_gauge',
        callback: (result) {
          result.observe(789.0);
        },
      );
      
      // Verify instruments are disabled (NoOp implementations)
      expect(counter.enabled, isFalse);
      expect(upDownCounter.enabled, isFalse);
      expect(histogram.enabled, isFalse);
      expect(gauge.enabled, isFalse);
      expect(obsCounter.enabled, isFalse);
      expect(obsUpDown.enabled, isFalse);
      expect(obsGauge.enabled, isFalse);
      
      // Exercise the APIs to ensure no exceptions - NoOp implementations should do nothing
      counter.add(10);
      upDownCounter.add(30);
      upDownCounter.add(-15);
      histogram.record(50.5);
      gauge.record(70.5);
      
      // Check instrument properties
      expect(counter.name, equals('noop_counter'));
      expect(counter.isCounter, isTrue);
      expect(counter.isGauge, isFalse);
      expect(counter.isHistogram, isFalse);
      expect(counter.isUpDownCounter, isFalse);
      
      expect(upDownCounter.name, equals('noop_up_down'));
      expect(upDownCounter.isCounter, isFalse);
      expect(upDownCounter.isGauge, isFalse);
      expect(upDownCounter.isHistogram, isFalse);
      expect(upDownCounter.isUpDownCounter, isTrue);
      
      expect(histogram.name, equals('noop_histogram'));
      expect(histogram.isCounter, isFalse);
      expect(histogram.isGauge, isFalse);
      expect(histogram.isHistogram, isTrue);
      expect(histogram.isUpDownCounter, isFalse);
      
      expect(gauge.name, equals('noop_gauge'));
      expect(gauge.isCounter, isFalse);
      expect(gauge.isGauge, isTrue);
      expect(gauge.isHistogram, isFalse);
      expect(gauge.isUpDownCounter, isFalse);

      // Test observable instrument methods
      expect(obsCounter.callbacks.length, equals(1));
      expect(obsCounter.collect(), isEmpty);
      
      expect(obsUpDown.callbacks.length, equals(1));
      expect(obsUpDown.collect(), isEmpty);
      
      expect(obsGauge.callbacks.length, equals(1));
      expect(obsGauge.collect(), isEmpty);

      // Test callback registration
      final cbReg1 = obsCounter.addCallback((result) => result.observe(100));
      final cbReg2 = obsUpDown.addCallback((result) => result.observe(200));
      final cbReg3 = obsGauge.addCallback((result) => result.observe(300.0));

      expect(obsCounter.callbacks.length, equals(2));
      expect(obsUpDown.callbacks.length, equals(2));
      expect(obsGauge.callbacks.length, equals(2));

      // Test unregister
      cbReg1.unregister();
      cbReg2.unregister();
      cbReg3.unregister();

      expect(obsCounter.callbacks.length, equals(1));
      expect(obsUpDown.callbacks.length, equals(1));
      expect(obsGauge.callbacks.length, equals(1));

      // Now initialize the SDK and verify the API switches to using it
      await OTel.initialize(
        serviceName: 'switched-test-service',
        metricReader: MemoryMetricReader(exporter: MemoryMetricExporter()),
        detectPlatformResources: false,
      );

      // Get a new meter - this should now use the SDK factory
      final sdkMeter = OTel.meter('sdk-test-meter');

      // Verify the meter is now enabled (SDK implementation)
      expect(sdkMeter.enabled, isTrue);

      // Create a new instrument with the SDK-backed meter
      final sdkCounter = sdkMeter.createCounter<int>(name: 'sdk_counter');
      expect(sdkCounter.enabled, isTrue);
    }, skip: true);
  });

  group('MeterProvider Advanced Coverage Tests', () {
    late MemoryMetricExporter memoryExporter;
    late MemoryMetricReader metricReader;

    setUp(() async {
      await OTel.reset();

      // Create a memory exporter for verification
      memoryExporter = MemoryMetricExporter();
      metricReader = MemoryMetricReader(exporter: memoryExporter);

      // Initialize OTel with our memory metric reader
      await OTel.initialize(
        serviceName: 'meter-provider-coverage-test-service',
        metricReader: metricReader,
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.shutdown();
    });

    test('MeterProvider endpoint and service settings are exposed', () {
      final meterProvider = OTel.meterProvider();
      
      // Set and verify endpoint
      meterProvider.endpoint = 'https://example.com/otlp';
      expect(meterProvider.endpoint, equals('https://example.com/otlp'));
      
      // Set and verify service name
      meterProvider.serviceName = 'test-service-updated';
      expect(meterProvider.serviceName, equals('test-service-updated'));
      
      // Set and verify service version
      meterProvider.serviceVersion = '2.0.0';
      expect(meterProvider.serviceVersion, equals('2.0.0'));
    });

    test('MeterProvider handles views properly', () {
      final meterProvider = OTel.meterProvider();
      
      // Initially no views
      expect(meterProvider.views, isEmpty);
      
      // Add views
      final view1 = View(
        instrumentNamePattern: 'test_metric*',
        name: 'test-view-1',
        description: 'Test view 1',
      );
      
      final view2 = View(
        instrumentNamePattern: 'another_metric*',
        name: 'test-view-2',
        description: 'Test view 2',
      );
      
      meterProvider.addView(view1);
      meterProvider.addView(view2);
      
      // Verify views added
      expect(meterProvider.views.length, equals(2));
      expect(meterProvider.views[0].name, equals('test-view-1'));
      expect(meterProvider.views[1].name, equals('test-view-2'));
    });

    test('MeterProvider exposes metric readers', () {
      final meterProvider = OTel.meterProvider();
      
      // Verify our metric reader was added during initialization
      expect(meterProvider.metricReaders.length, equals(1));
      
      // Create and add additional metric reader
      final additionalExporter = MemoryMetricExporter();
      final additionalReader = MemoryMetricReader(exporter: additionalExporter);
      
      meterProvider.addMetricReader(additionalReader);
      
      // Verify the additional reader was added
      expect(meterProvider.metricReaders.length, equals(2));
      
      // Adding same reader again should not duplicate
      meterProvider.addMetricReader(additionalReader);
      expect(meterProvider.metricReaders.length, equals(2));
    });

    test('MeterProvider does not flush after shutting down', () async {
      final meterProvider = OTel.meterProvider();
      
      // Verify initial state
      expect(meterProvider.isShutdown, isFalse);
      
      // Should succeed initially
      bool flushResult = await meterProvider.forceFlush();
      expect(flushResult, isTrue);
      
      // Shutdown the provider
      await meterProvider.shutdown();
      expect(meterProvider.isShutdown, isTrue);
      
      // Should fail after shutdown
      flushResult = await meterProvider.forceFlush();
      expect(flushResult, isFalse);
      
      // Calling shutdown again should just return success
      final bool secondShutdown = await meterProvider.shutdown();
      expect(secondShutdown, isTrue);
    });
  });

  group('OTelLog Control Tests', () {
    // Temporary log capture for testing
    List<String> capturedLogs = [];
    bool wasLoggingEnabled = false;
    LogFunction? originalLogFunction;
    LogFunction? originalMetricLogFunction;

    setUp(() async {
      // Save original logging state to restore later
      wasLoggingEnabled = OTelLog.isDebug();
      originalLogFunction = OTelLog.logFunction;
      originalMetricLogFunction = OTelLog.metricLogFunction;
      
      // Clear captured logs
      capturedLogs = [];
      
      // Set up log capture
      OTelLog.logFunction = (String message) {
        capturedLogs.add(message);
      };
      
      // Enable debug logging
      OTelLog.enableDebugLogging();
      
      await OTel.reset();
    });

    tearDown(() async {
      await OTel.shutdown();
      // Restore original logging state
      if (wasLoggingEnabled) {
        OTelLog.enableDebugLogging();
      } else {
        // Disable logging by setting to null
        OTelLog.logFunction = null;
      }
      OTelLog.logFunction = originalLogFunction;
      OTelLog.metricLogFunction = originalMetricLogFunction;
      
      await OTel.reset();
    });

    test('OTelLog.debug messages are captured when enabled', () {
      OTelLog.debug('Test debug message');
      expect(capturedLogs.length, equals(1));
      expect(capturedLogs.first, contains('DEBUG'));
      expect(capturedLogs.first, contains('Test debug message'));
    }, skip: true);

    test('OTelLog controls metrics logging', () {
      // Set up metrics log capture
      final List<String> metricLogs = [];
      OTelLog.metricLogFunction = metricLogs.add;
      
      // Log a metric message
      OTelLog.logMetric('Test metric message');
      
      // Verify log was captured
      expect(metricLogs.length, equals(1));
      expect(metricLogs.first, contains('metric'));
      expect(metricLogs.first, contains('Test metric message'));
      
      // Disable metric logging
      OTelLog.metricLogFunction = null;
      
      // Try logging again
      OTelLog.logMetric('This should not be captured');
      
      // Verify no additional logs were captured
      expect(metricLogs.length, equals(1));
    });

    test('Meter creation logs when metrics logging is enabled', () async {
      // Set up metrics log capture
      final List<String> metricLogs = [];
      OTelLog.metricLogFunction = metricLogs.add;
      
      // Initialize OTel
      await OTel.initialize(
        serviceName: 'logging-test-service',
        detectPlatformResources: false,
      );
      
      // Create a meter, which should trigger logging
      OTel.meter('log-test-meter');
      
      // Verify a log was captured about meter creation
      expect(metricLogs.any((log) => log.contains('Created meter') && log.contains('log-test-meter')), isTrue);
    });
  });
}
