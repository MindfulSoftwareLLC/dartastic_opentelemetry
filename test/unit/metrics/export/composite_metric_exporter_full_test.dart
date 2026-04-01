// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'test',
      detectPlatformResources: false,
    );
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  MetricData createTestMetricData() {
    final now = DateTime.now();
    final points = <MetricPoint<dynamic>>[
      MetricPoint<int>(
        attributes: Attributes.of({'key': 'value'}),
        startTime: now.subtract(const Duration(seconds: 10)),
        endTime: now,
        value: 42,
      ),
    ];
    final metric = Metric.sum(
      name: 'test_counter',
      description: 'A test counter',
      unit: 'requests',
      points: points,
    );
    return MetricData(metrics: [metric]);
  }

  group('CompositeMetricExporter export', () {
    test('delegates to all exporters', () async {
      final exporter1 = _SuccessExporter();
      final exporter2 = _SuccessExporter();
      final composite = CompositeMetricExporter([exporter1, exporter2]);
      final data = createTestMetricData();

      await composite.export(data);

      expect(exporter1.exportCalled, isTrue);
      expect(exporter2.exportCalled, isTrue);
    });

    test('returns true when all succeed', () async {
      final exporter1 = _SuccessExporter();
      final exporter2 = _SuccessExporter();
      final composite = CompositeMetricExporter([exporter1, exporter2]);
      final data = createTestMetricData();

      final result = await composite.export(data);

      expect(result, isTrue);
    });

    test('returns false when any exporter fails', () async {
      final exporter1 = _SuccessExporter();
      final exporter2 = _FailExporter();
      final composite = CompositeMetricExporter([exporter1, exporter2]);
      final data = createTestMetricData();

      final result = await composite.export(data);

      expect(result, isFalse);
      // The success exporter should still have been called
      expect(exporter1.exportCalled, isTrue);
    });

    test('returns false after shutdown', () async {
      final exporter1 = _SuccessExporter();
      final composite = CompositeMetricExporter([exporter1]);
      final data = createTestMetricData();

      await composite.shutdown();
      final result = await composite.export(data);

      expect(result, isFalse);
      // Exporter should not be called after shutdown
      expect(exporter1.exportCalled, isFalse);
    });

    test('continues with remaining exporters even when one throws', () async {
      final exporter1 = _ThrowExporter();
      final exporter2 = _SuccessExporter();
      final composite = CompositeMetricExporter([exporter1, exporter2]);
      final data = createTestMetricData();

      final result = await composite.export(data);

      expect(result, isFalse);
      // The second exporter should still have been called despite the first throwing
      expect(exporter2.exportCalled, isTrue);
    });
  });

  group('CompositeMetricExporter forceFlush', () {
    test('delegates to all exporters', () async {
      final exporter1 = _SuccessExporter();
      final exporter2 = _SuccessExporter();
      final composite = CompositeMetricExporter([exporter1, exporter2]);

      final result = await composite.forceFlush();

      expect(result, isTrue);
      expect(exporter1.flushCalled, isTrue);
      expect(exporter2.flushCalled, isTrue);
    });

    test('returns false after shutdown', () async {
      final exporter1 = _SuccessExporter();
      final composite = CompositeMetricExporter([exporter1]);

      await composite.shutdown();
      final result = await composite.forceFlush();

      expect(result, isFalse);
      expect(exporter1.flushCalled, isFalse);
    });

    test('returns false when any exporter fails', () async {
      final exporter1 = _SuccessExporter();
      final exporter2 = _FailExporter();
      final composite = CompositeMetricExporter([exporter1, exporter2]);

      final result = await composite.forceFlush();

      expect(result, isFalse);
      // The success exporter should still have been called
      expect(exporter1.flushCalled, isTrue);
    });
  });

  group('CompositeMetricExporter shutdown', () {
    test('delegates to all exporters', () async {
      final exporter1 = _SuccessExporter();
      final exporter2 = _SuccessExporter();
      final composite = CompositeMetricExporter([exporter1, exporter2]);

      final result = await composite.shutdown();

      expect(result, isTrue);
      expect(exporter1.shutdownCalled, isTrue);
      expect(exporter2.shutdownCalled, isTrue);
    });

    test('returns true on subsequent calls', () async {
      final exporter1 = _SuccessExporter();
      final composite = CompositeMetricExporter([exporter1]);

      final result1 = await composite.shutdown();
      expect(result1, isTrue);

      // Reset the flag to verify shutdown is not called again
      exporter1.shutdownCalled = false;

      final result2 = await composite.shutdown();
      expect(result2, isTrue);
      // Shutdown should not be called again on the delegate
      expect(exporter1.shutdownCalled, isFalse);
    });

    test('returns false when any exporter fails', () async {
      final exporter1 = _SuccessExporter();
      final exporter2 = _FailExporter();
      final composite = CompositeMetricExporter([exporter1, exporter2]);

      final result = await composite.shutdown();

      expect(result, isFalse);
      // The success exporter should still have been called
      expect(exporter1.shutdownCalled, isTrue);
    });
  });
}

/// A test exporter that always succeeds.
class _SuccessExporter implements MetricExporter {
  bool exportCalled = false;
  bool flushCalled = false;
  bool shutdownCalled = false;

  @override
  Future<bool> export(MetricData data) async {
    exportCalled = true;
    return true;
  }

  @override
  Future<bool> forceFlush() async {
    flushCalled = true;
    return true;
  }

  @override
  Future<bool> shutdown() async {
    shutdownCalled = true;
    return true;
  }
}

/// A test exporter that always returns false.
class _FailExporter implements MetricExporter {
  @override
  Future<bool> export(MetricData data) async {
    return false;
  }

  @override
  Future<bool> forceFlush() async {
    return false;
  }

  @override
  Future<bool> shutdown() async {
    return false;
  }
}

/// A test exporter that always throws an exception.
class _ThrowExporter implements MetricExporter {
  @override
  Future<bool> export(MetricData data) async {
    throw Exception('fail');
  }

  @override
  Future<bool> forceFlush() async {
    throw Exception('fail');
  }

  @override
  Future<bool> shutdown() async {
    throw Exception('fail');
  }
}
