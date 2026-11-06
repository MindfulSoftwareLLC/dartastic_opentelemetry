// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../../testing_utils/memory_metric_exporter.dart';

void main() {
  invalidMeasurements<int>(-1, 0, 5);
  invalidMeasurements<double>(-0.5, 0.0, 5.0);
}

void invalidMeasurements<T extends num>(T negative, T zero, T positive) {
  group('Invalid $T measurements', () {
    late MemoryMetricExporter exporter;
    late MemoryMetricReader reader;
    late Meter meter;
    final logs = <String>[];
    var savedLogFunction = OTelLog.logFunction;
    var savedLevel = OTelLog.currentLevel;

    setUp(() async {
      savedLogFunction = OTelLog.logFunction;
      savedLevel = OTelLog.currentLevel;
      await OTel.reset();
      exporter = MemoryMetricExporter();
      reader = MemoryMetricReader(exporter: exporter);
      await OTel.initialize(
        serviceName: 'invalid-measurements',
        detectPlatformResources: false,
        metricReader: reader,
      );
      meter = OTel.meter('invalid-measurements');
      logs.clear();
      OTelLog.currentLevel = LogLevel.warn;
      OTelLog.logFunction = logs.add;
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
      OTelLog.logFunction = savedLogFunction;
      OTelLog.currentLevel = savedLevel;
    });

    test('counter drops invalid series and preserves exported sums', () async {
      final counter = meter.createCounter<T>(name: 'counter');
      counter.add(negative);
      counter.addWithMap(negative, {'invalid': true});
      expect((await reader.collect()).metrics, isEmpty);
      counter.add(zero);
      counter.add(positive);
      counter.add(negative);
      counter.addWithMap(positive, {'valid': true});
      await reader.forceFlush();
      final points = exporter.exportedMetrics.single.points;
      expect(points, hasLength(2));
      expect(points.map((point) => point.value), everyElement(positive));
      expect(logs.where((line) => line.contains('negative measurement')),
          hasLength(3));
    });

    test('histogram drops invalid series and preserves exported buckets',
        () async {
      final histogram = meter.createHistogram<T>(
        name: 'histogram',
        advisory: const InstrumentAdvisory(explicitBucketBoundaries: [0, 5]),
      );
      histogram.record(negative);
      histogram.recordWithMap(negative, {'invalid': true});
      expect((await reader.collect()).metrics, isEmpty);
      histogram.record(zero);
      histogram.record(positive);
      histogram.record(negative);
      histogram.recordWithMap(positive, {});
      await reader.forceFlush();
      final value = exporter.exportedMetrics.single.points.single.histogram();
      expect(value.count, 3);
      expect(value.sum, positive * 2);
      expect(value.min, zero);
      expect(value.max, positive);
      expect(value.boundaries, [0, 5]);
      expect(value.bucketCounts, [1, 2, 0]);
      expect(logs.where((line) => line.contains('negative measurement')),
          hasLength(3));
    });

    test('mismatched point logs a warning and returns a safe default', () {
      final now = DateTime.now();
      final point = MetricPoint<T>.gauge(
        attributes: OTel.attributes([]),
        startTime: now,
        time: now,
        value: positive,
      );
      final histogram = point.histogram();
      expect(histogram.count, 0);
      expect(histogram.bucketCounts.length, histogram.boundaries.length + 1);
      expect(logs.single, contains('not a histogram point'));
    });
  });
}
