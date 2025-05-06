// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// ignore_for_file: unused_field, unused_local_variable

import 'dart:async';
import 'dart:math';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

/// Mock system metrics collector that simulates collecting system metrics
class MockSystemMetricsCollector {
  // Simulated memory metrics
  final int _totalMemoryBytes = 8 * 1024 * 1024 * 1024; // 8 GB
  int _usedMemoryBytes = 2 * 1024 * 1024 * 1024; // 2 GB initially

  // Simulated CPU metrics
  double _cpuUsagePercent = 15.0; // 15% initially

  // Simulated disk metrics
  final int _diskTotalBytes = 512 * 1024 * 1024 * 1024; // 512 GB
  int _diskUsedBytes = 128 * 1024 * 1024 * 1024; // 128 GB initially

  // Random generator for simulating changes
  final Random _random = Random();

  // Getters for current values
  int get totalMemoryBytes => _totalMemoryBytes;
  int get usedMemoryBytes => _usedMemoryBytes;
  int get freeMemoryBytes => _totalMemoryBytes - _usedMemoryBytes;
  double get memoryUsagePercent => (_usedMemoryBytes / _totalMemoryBytes) * 100;

  double get cpuUsagePercent => _cpuUsagePercent;

  int get diskTotalBytes => _diskTotalBytes;
  int get diskUsedBytes => _diskUsedBytes;
  int get diskFreeBytes => _diskTotalBytes - _diskUsedBytes;
  double get diskUsagePercent => (_diskUsedBytes / _diskTotalBytes) * 100;

  // Generate random fluctuations in metrics to simulate a real system
  void updateMetrics() {
    // Simulate memory usage fluctuations (±256MB)
    final memoryDeltaMB = _random.nextInt(512) - 256;
    final memoryDeltaBytes = memoryDeltaMB * 1024 * 1024;
    _usedMemoryBytes = max(0, min(_totalMemoryBytes, _usedMemoryBytes + memoryDeltaBytes));

    // Simulate CPU usage fluctuations (±5%)
    final cpuDelta = (_random.nextDouble() * 10) - 5;
    _cpuUsagePercent = max(0, min(100, _cpuUsagePercent + cpuDelta));

    // Simulate disk usage fluctuations (±1GB)
    final diskDeltaMB = _random.nextInt(2048) - 1024;
    final diskDeltaBytes = diskDeltaMB * 1024 * 1024;
    _diskUsedBytes = max(0, min(_diskTotalBytes, _diskUsedBytes + diskDeltaBytes));
  }
}

/// Custom metric collector for system metrics
class SystemMetricsCollector {
  final MockSystemMetricsCollector _systemCollector;
  final Meter _meter;
  late ObservableGauge<double> _cpuUsageGauge;
  late ObservableGauge<double> _memoryUsageGauge;
  late ObservableUpDownCounter<int> _freeMemoryCounter;
  late ObservableCounter<int> _diskWritesCounter;

  // Track simulated disk writes (monotonically increasing)
  int _totalDiskWrites = 0;

  SystemMetricsCollector(this._systemCollector, this._meter) {
    _initializeMetrics();
  }

  void _initializeMetrics() {
    // CPU usage gauge (percentage)
    _cpuUsageGauge = _meter.createObservableGauge<double>(
      name: 'system.cpu.usage',
      unit: '%',
      description: 'CPU usage percentage',
      callback: (APIObservableResult<double> result) {
        result.observe(_systemCollector.cpuUsagePercent);
      },
    ) as ObservableGauge<double>;

    // Memory usage gauge (percentage)
    _memoryUsageGauge = _meter.createObservableGauge<double>(
      name: 'system.memory.usage',
      unit: '%',
      description: 'Memory usage percentage',
      callback: (APIObservableResult<double> result) {
        result.observe(_systemCollector.memoryUsagePercent);
      },
    ) as ObservableGauge<double>;

    // Free memory counter (bytes)
    _freeMemoryCounter = _meter.createObservableUpDownCounter<int>(
      name: 'system.memory.free',
      unit: 'By',
      description: 'Free memory in bytes',
      callback: (APIObservableResult<int> result) {
        result.observe(_systemCollector.freeMemoryBytes);
      },
    ) as ObservableUpDownCounter<int>;

    // Disk writes counter (operations)
    _diskWritesCounter = _meter.createObservableCounter<int>(
      name: 'system.disk.writes',
      unit: 'operations',
      description: 'Total disk write operations',
      callback: (APIObservableResult<int> result) {
        result.observe(_totalDiskWrites);
      },
    ) as ObservableCounter<int>;
  }

  // Simulate a disk write operation
  void simulateDiskWrite() {
    _totalDiskWrites++;
  }
}

/// Custom test metric reader for tracking metrics
class TestMetricReader extends MetricReader {
  final List<Metric> _collectedMetrics = [];

  bool _isShutdown = false;

  @override
  Future<MetricData> collect() async {
    if (_isShutdown || meterProvider == null) {
      return MetricData.empty();
    }

    final sdkMeterProvider = meterProvider!;
    final metrics = await sdkMeterProvider.collectAllMetrics();
    _collectedMetrics.clear();
    _collectedMetrics.addAll(metrics);

    return MetricData(
      resource: meterProvider!.resource,
      metrics: metrics,
    );
  }

  @override
  Future<bool> forceFlush() async {
    if (_isShutdown) return false;
    await collect();
    return true;
  }

  @override
  Future<bool> shutdown() async {
    _isShutdown = true;
    _collectedMetrics.clear();
    return true;
  }

  /// Get the most recently collected metrics
  List<Metric> getCollectedMetrics() {
    return List.unmodifiable(_collectedMetrics);
  }
}

/// The integration test for automatic metrics collection
void main() {
  group('Auto Collection Integration Tests', () {
    late MeterProvider meterProvider;
    late Meter meter;
    late MockSystemMetricsCollector systemCollector;
    late SystemMetricsCollector metricsCollector;
    late TestMetricReader metricReader;

    setUp(() async {
      await OTel.reset();

      // Create the system metrics simulator
      systemCollector = MockSystemMetricsCollector();

      // Create and configure the test metric reader
      metricReader = TestMetricReader();

      // Initialize OTel
      await OTel.initialize(
        serviceName: 'metrics-test-service',
        endpoint: 'http://localhost:4317',
        detectPlatformResources: false,
      );

      // Get a meter provider and add our test reader
      meterProvider = OTel.meterProvider();
      meterProvider.addMetricReader(metricReader);

      // Get a meter for our system metrics
      meter = meterProvider.getMeter(
        name: 'system-metrics',
        version: '1.0.0',
      ) as Meter;

      // Create the metrics collector
      metricsCollector = SystemMetricsCollector(systemCollector, meter);
    });

    tearDown(() async {
      await meterProvider.shutdown();
      await OTel.reset();
    });

    test('Metrics are auto-collected on collection interval', () async {
      // Verify initial state
      await metricReader.forceFlush();
      final initialMetrics = metricReader.getCollectedMetrics();
      expect(initialMetrics.length, equals(4)); // Our 4 metrics should be registered

      // Simulate system activity and metric changes
      systemCollector.updateMetrics();
      for (var i = 0; i < 5; i++) {
        metricsCollector.simulateDiskWrite(); // 5 disk writes
      }

      // Force collection and check the values
      await metricReader.forceFlush();
      var metrics = metricReader.getCollectedMetrics();

      // Verify all 4 metrics are present
      expect(metrics.length, equals(4));

      // Helper function to find a metric by name
      Metric findMetric(String name) {
        return metrics.firstWhere((m) => m.name == name);
      }

      // Check CPU usage gauge
      final cpuMetric = findMetric('system.cpu.usage');
      expect(cpuMetric.type, equals(MetricType.gauge));
      expect(cpuMetric.unit, equals('%'));
      expect(cpuMetric.points.length, equals(1));
      expect(cpuMetric.points[0].value, closeTo(systemCollector.cpuUsagePercent, 0.001));

      // Check memory usage gauge
      final memMetric = findMetric('system.memory.usage');
      expect(memMetric.type, equals(MetricType.gauge));
      expect(memMetric.unit, equals('%'));
      expect(memMetric.points.length, equals(1));
      expect(memMetric.points[0].value, closeTo(systemCollector.memoryUsagePercent, 0.001));

      // Check free memory counter
      final freeMemMetric = findMetric('system.memory.free');
      expect(freeMemMetric.type, equals(MetricType.sum));
      expect(freeMemMetric.unit, equals('By'));
      expect(freeMemMetric.points.length, equals(1));
      expect(freeMemMetric.points[0].value, equals(systemCollector.freeMemoryBytes));

      // Check disk writes counter
      final diskWritesMetric = findMetric('system.disk.writes');
      expect(diskWritesMetric.type, equals(MetricType.sum));
      expect(diskWritesMetric.unit, equals('operations'));
      expect(diskWritesMetric.points.length, equals(1));
      expect(diskWritesMetric.points[0].value, equals(5)); // 5 simulated writes

      // Simulate more system activity
      systemCollector.updateMetrics();
      for (var i = 0; i < 7; i++) {
        metricsCollector.simulateDiskWrite(); // 7 more disk writes
      }

      // Force collection and check updated values
      await metricReader.forceFlush();
      metrics = metricReader.getCollectedMetrics();

      // Find the updated metrics
      final updatedCpuMetric = findMetric('system.cpu.usage');
      final updatedDiskWritesMetric = findMetric('system.disk.writes');

      // Verify the values have updated
      expect(updatedCpuMetric.points[0].value, closeTo(systemCollector.cpuUsagePercent, 0.001));
      expect(updatedDiskWritesMetric.points[0].value, equals(12)); // 5 + 7 = 12 disk writes
    });

    test('Force flush during collection', () async {
      // Simulate initial system activity
      systemCollector.updateMetrics();
      metricsCollector.simulateDiskWrite();

      // Force flush metrics
      final flushResult = await meterProvider.forceFlush();
      expect(flushResult, isTrue);

      // Get collected metrics and verify
      var metrics = metricReader.getCollectedMetrics();
      expect(metrics.length, equals(4));

      // Helper function to find a metric by name
      Metric findMetric(String name) {
        return metrics.firstWhere((m) => m.name == name);
      }

      // Verify metrics were collected
      final diskWritesMetric = findMetric('system.disk.writes');
      expect(diskWritesMetric.points[0].value, equals(1)); // 1 simulated write

      // Disable meter provider and verify no metrics are collected
      meterProvider.enabled = false;

      // Add more metrics, which should be ignored
      metricsCollector.simulateDiskWrite();
      systemCollector.updateMetrics();

      // Force flush and collect
      await meterProvider.forceFlush();
      await metricReader.forceFlush();
      metrics = metricReader.getCollectedMetrics();

      // Should be empty as provider is disabled
      expect(metrics.isEmpty, isTrue);

      // Re-enable and verify metrics resume
      meterProvider.enabled = true;

      // Add more metrics
      metricsCollector.simulateDiskWrite();

      // Force flush and collect
      await meterProvider.forceFlush();
      metrics = metricReader.getCollectedMetrics();

      // Should be collecting again
      expect(metrics.isNotEmpty, isTrue);
      final resumedDiskWritesMetric = findMetric('system.disk.writes');
      expect(resumedDiskWritesMetric.points[0].value, equals(3)); // 1 + 1 + 1 = 3 simulated writes
    });

    test('Metrics with attributes', () async {
      // Create a more complex metrics collector with attributes
      final cpuGaugeWithAttributes = meter.createObservableGauge<double>(
        name: 'system.cpu.core.usage',
        unit: '%',
        description: 'CPU usage per core',
        callback: (APIObservableResult<double> result) {
          // Simulate multi-core CPU reporting
          result.observe(systemCollector.cpuUsagePercent * 0.9, {'core': '0', 'type': 'user'}.toAttributes());
          result.observe(systemCollector.cpuUsagePercent * 0.1, {'core': '0', 'type': 'system'}.toAttributes());
          result.observe(systemCollector.cpuUsagePercent * 0.8, {'core': '1', 'type': 'user'}.toAttributes());
          result.observe(systemCollector.cpuUsagePercent * 0.2, {'core': '1', 'type': 'system'}.toAttributes());
        },
      );

      // Update system metrics
      systemCollector.updateMetrics();

      // Force flush and collect
      await meterProvider.forceFlush();
      final metrics = metricReader.getCollectedMetrics();

      // Find our new metric
      final cpuCoreMetric = metrics.firstWhere((m) => m.name == 'system.cpu.core.usage');
      expect(cpuCoreMetric.type, equals(MetricType.gauge));
      expect(cpuCoreMetric.points.length, equals(4)); // 4 data points with different attributes

      // Verify the different attribute combinations
      final core0UserPoint = cpuCoreMetric.points.firstWhere((p) =>
        p.attributes.getString('core') == '0' && p.attributes.getString('type') == 'user'
      );
      final core0SystemPoint = cpuCoreMetric.points.firstWhere((p) =>
        p.attributes.getString('core') == '0' && p.attributes.getString('type') == 'system'
      );

      // Verify values make sense
      expect(core0UserPoint.value, closeTo(systemCollector.cpuUsagePercent * 0.9, 0.1));
      expect(core0SystemPoint.value, closeTo(systemCollector.cpuUsagePercent * 0.1, 0.1));

      // Verify sum of all cores/types approximately equals the total CPU usage
      final sum = cpuCoreMetric.points.fold<double>(0, (sum, point) => sum + (point.value as double));
      expect(sum, closeTo(systemCollector.cpuUsagePercent * 2, 0.1)); // 2 cores total
    });

    test('Histogram metrics collection', () async {
      // Create a histogram to track response times
      final histogram = meter.createHistogram<double>(
        name: 'app.request.duration',
        unit: 'ms',
        description: 'Request duration histogram',
      );

      // Record some sample latencies
      histogram.record(12.5, {'endpoint': '/api/users'}.toAttributes());
      histogram.record(45.2, {'endpoint': '/api/users'}.toAttributes());
      histogram.record(8.7, {'endpoint': '/api/users'}.toAttributes());
      histogram.record(150.0, {'endpoint': '/api/products'}.toAttributes());
      histogram.record(85.3, {'endpoint': '/api/products'}.toAttributes());

      // Force flush and collect
      await meterProvider.forceFlush();
      final metrics = metricReader.getCollectedMetrics();

      // Find the histogram metric
      final histogramMetric = metrics.firstWhere((m) => m.name == 'app.request.duration');
      expect(histogramMetric.type, equals(MetricType.histogram));

      // There should be 2 distinct attribute combinations
      expect(histogramMetric.points.length, equals(2));

      // Find points by endpoint
      final usersPoint = histogramMetric.points.firstWhere((p) =>
        p.attributes.getString('endpoint') == '/api/users'
      );
      final productsPoint = histogramMetric.points.firstWhere((p) =>
        p.attributes.getString('endpoint') == '/api/products'
      );

      // Get histogram values
      final usersHistogram = usersPoint.histogram();
      final productsHistogram = productsPoint.histogram();

      // Check histogram data for users endpoint
      expect(usersHistogram.count, equals(3)); // 3 measurements
      expect(usersHistogram.sum, closeTo(66.4, 0.1)); // 12.5 + 45.2 + 8.7 = 66.4

      // Check histogram data for products endpoint
      expect(productsHistogram.count, equals(2)); // 2 measurements
      expect(productsHistogram.sum, closeTo(235.3, 0.1)); // 150.0 + 85.3 = 235.3
    });

    test('Resource detection and custom attributes', () async {
      // Create a resource attributes
      final resourceAttributes = {
        'service.name': 'test-service',
        'service.version': '1.0.0',
        'host.name': 'test-host',
        'deployment.environment': 'testing'
      }.toAttributes();

      // Create a resource
      final resource = ResourceCreate.create(resourceAttributes);

      // Initialize a new OTel instance with this resource
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'resource-test',
        endpoint: 'http://localhost:4317',
        detectPlatformResources: false,
        // Use the resource with the SDK
        resourceAttributes: resourceAttributes,
      );

      // Get the meter provider and add our reader
      final resourceMeterProvider = OTel.meterProvider();
      resourceMeterProvider.addMetricReader(metricReader);

      // Create a meter and a simple counter
      final resourceMeter = resourceMeterProvider.getMeter(name: 'resource-meter') as Meter;

      final counter = resourceMeter.createCounter<int>(
        name: 'app.request.count',
        unit: 'requests',
      );

      // Record some values
      counter.add(5);
      counter.add(3, {'endpoint': '/api/data'}.toAttributes());

      // Force flush and collect
      await resourceMeterProvider.forceFlush();
      final resourceMetrics = metricReader.getCollectedMetrics();

      // Check the counter metric
      final requestCountMetric = resourceMetrics.firstWhere((m) => m.name == 'app.request.count');

      // Verify metric has expected values
      expect(requestCountMetric.points.length, equals(2));

      // The point with the endpoint attribute should have the custom attributes
      final apiPoint = requestCountMetric.points.firstWhere((p) =>
        p.attributes.getString('endpoint') == '/api/data'
      );
      expect(apiPoint.attributes.getString('endpoint'), equals('/api/data'));
      expect(apiPoint.value, equals(3));

      await resourceMeterProvider.shutdown();
    });
  });
}
