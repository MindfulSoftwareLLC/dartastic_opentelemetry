// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    await OTel.reset();
    await OTel.initialize(serviceName: 'test', detectPlatformResources: false);
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  group('MetricPoint', () {
    late Attributes attrs;
    late DateTime startTime;
    late DateTime endTime;

    setUp(() {
      attrs = OTel.attributes([OTel.attributeString('key', 'value')]);
      endTime = DateTime.now();
      startTime = endTime.subtract(const Duration(seconds: 10));
    });

    test('constructor sets all fields', () {
      final exemplar = Exemplar(
        attributes: OTel.attributes([]),
        filteredAttributes: OTel.attributes([]),
        timestamp: DateTime.now(),
        value: 1.0,
      );
      final point = MetricPoint<int>(
        attributes: attrs,
        startTime: startTime,
        endTime: endTime,
        value: 42,
        exemplars: [exemplar],
      );

      expect(point.attributes, equals(attrs));
      expect(point.startTime, equals(startTime));
      expect(point.endTime, equals(endTime));
      expect(point.value, equals(42));
      expect(point.exemplars, hasLength(1));
    });

    test('sum factory creates correctly', () {
      final point = MetricPoint<int>.sum(
        attributes: attrs,
        startTime: startTime,
        time: endTime,
        value: 100,
      );

      expect(point.attributes, equals(attrs));
      expect(point.startTime, equals(startTime));
      expect(point.endTime, equals(endTime));
      expect(point.value, equals(100));
      expect(point.exemplars, isNull);
    });

    test('gauge factory creates correctly', () {
      final point = MetricPoint<double>.gauge(
        attributes: attrs,
        startTime: startTime,
        time: endTime,
        value: 3.14,
      );

      expect(point.attributes, equals(attrs));
      expect(point.startTime, equals(startTime));
      expect(point.endTime, equals(endTime));
      expect(point.value, equals(3.14));
      expect(point.exemplars, isNull);
    });

    test('histogram factory creates HistogramValue', () {
      final point = MetricPoint<dynamic>.histogram(
        attributes: attrs,
        startTime: startTime,
        time: endTime,
        count: 10,
        sum: 250.0,
        counts: [2, 3, 5],
        boundaries: [10.0, 50.0],
        min: 1.0,
        max: 99.0,
      );

      expect(point.value, isA<HistogramValue>());
      final histValue = point.value as HistogramValue;
      expect(histValue.sum, equals(250.0));
      expect(histValue.count, equals(10));
      expect(histValue.boundaries, equals([10.0, 50.0]));
      expect(histValue.bucketCounts, equals([2, 3, 5]));
      expect(histValue.min, equals(1.0));
      expect(histValue.max, equals(99.0));
    });

    test('histogram factory works without min and max', () {
      final point = MetricPoint<dynamic>.histogram(
        attributes: attrs,
        startTime: startTime,
        time: endTime,
        count: 5,
        sum: 100.0,
        counts: [2, 3],
        boundaries: [50.0],
      );

      expect(point.value, isA<HistogramValue>());
      final histValue = point.value as HistogramValue;
      expect(histValue.min, isNull);
      expect(histValue.max, isNull);
    });

    group('hasExemplars', () {
      test('returns false when exemplars is null', () {
        final point = MetricPoint<int>(
          attributes: attrs,
          startTime: startTime,
          endTime: endTime,
          value: 42,
          exemplars: null,
        );

        expect(point.hasExemplars, isFalse);
      });

      test('returns false when exemplars list is empty', () {
        final point = MetricPoint<int>(
          attributes: attrs,
          startTime: startTime,
          endTime: endTime,
          value: 42,
          exemplars: [],
        );

        expect(point.hasExemplars, isFalse);
      });

      test('returns true when exemplars exist', () {
        final exemplar = Exemplar(
          attributes: OTel.attributes([]),
          filteredAttributes: OTel.attributes([]),
          timestamp: DateTime.now(),
          value: 1.0,
        );
        final point = MetricPoint<int>(
          attributes: attrs,
          startTime: startTime,
          endTime: endTime,
          value: 42,
          exemplars: [exemplar],
        );

        expect(point.hasExemplars, isTrue);
      });
    });

    group('valueAsString', () {
      test('for number value', () {
        final point = MetricPoint<int>(
          attributes: attrs,
          startTime: startTime,
          endTime: endTime,
          value: 42,
        );

        expect(point.valueAsString, equals('42'));
      });

      test('for double value', () {
        final point = MetricPoint<double>(
          attributes: attrs,
          startTime: startTime,
          endTime: endTime,
          value: 3.14,
        );

        expect(point.valueAsString, equals('3.14'));
      });

      test('for HistogramValue', () {
        final point = MetricPoint<dynamic>.histogram(
          attributes: attrs,
          startTime: startTime,
          time: endTime,
          count: 10,
          sum: 250.5,
          counts: [2, 3, 5],
          boundaries: [10.0, 50.0],
        );

        expect(point.valueAsString, equals('Histogram(sum: 250.5, count: 10)'));
      });
    });

    group('histogram()', () {
      test('returns HistogramValue for histogram point', () {
        final point = MetricPoint<dynamic>.histogram(
          attributes: attrs,
          startTime: startTime,
          time: endTime,
          count: 7,
          sum: 350.0,
          counts: [1, 2, 4],
          boundaries: [10.0, 100.0],
          min: 2.0,
          max: 200.0,
        );

        final histValue = point.histogram();

        expect(histValue, isA<HistogramValue>());
        expect(histValue.sum, equals(350.0));
        expect(histValue.count, equals(7));
        expect(histValue.boundaries, equals([10.0, 100.0]));
        expect(histValue.bucketCounts, equals([1, 2, 4]));
        expect(histValue.min, equals(2.0));
        expect(histValue.max, equals(200.0));
      });

      test('throws StateError for non-histogram point', () {
        final point = MetricPoint<int>(
          attributes: attrs,
          startTime: startTime,
          endTime: endTime,
          value: 42,
        );

        expect(point.histogram, throwsA(isA<StateError>()));
      });
    });
  });

  group('HistogramValue', () {
    test('stores all fields correctly', () {
      final histValue = HistogramValue(
        sum: 500.0,
        count: 20,
        boundaries: [10.0, 25.0, 50.0, 100.0],
        bucketCounts: [3, 5, 7, 4, 1],
        min: 1.5,
        max: 150.0,
      );

      expect(histValue.sum, equals(500.0));
      expect(histValue.count, equals(20));
      expect(histValue.boundaries, equals([10.0, 25.0, 50.0, 100.0]));
      expect(histValue.bucketCounts, equals([3, 5, 7, 4, 1]));
      expect(histValue.min, equals(1.5));
      expect(histValue.max, equals(150.0));
    });

    test('min and max are optional', () {
      final histValue = HistogramValue(
        sum: 100.0,
        count: 5,
        boundaries: [50.0],
        bucketCounts: [2, 3],
      );

      expect(histValue.min, isNull);
      expect(histValue.max, isNull);
    });
  });
}
