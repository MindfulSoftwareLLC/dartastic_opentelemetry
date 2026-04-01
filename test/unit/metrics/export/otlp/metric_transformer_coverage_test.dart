// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/metrics/v1/metrics.pb.dart'
    as proto;
import 'package:dartastic_opentelemetry/src/metrics/export/otlp/metric_transformer.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('MetricTransformer Coverage Tests', () {
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

    group('transformResource', () {
      test('converts resource attributes to proto', () {
        final resource = OTel.resource(Attributes.of({
          'service.name': 'my-service',
          'version': '2.0',
        }));

        final proto = MetricTransformer.transformResource(resource);
        expect(proto.attributes, isNotEmpty);

        final attrMap = Map.fromEntries(
          proto.attributes.map((kv) => MapEntry(kv.key, kv.value)),
        );
        expect(attrMap['service.name']!.stringValue, equals('my-service'));
        expect(attrMap['version']!.stringValue, equals('2.0'));
      });

      test('converts resource with list attributes', () {
        final resource = ResourceCreate.create(OTel.attributesFromList([
          OTel.attributeStringList('string_list', ['a', 'b']),
          OTel.attributeBoolList('bool_list', [true, false]),
          OTel.attributeIntList('int_list', [1, 2, 3]),
          OTel.attributeDoubleList('double_list', [1.0, 2.0]),
        ]));

        final resourceProto = MetricTransformer.transformResource(resource);
        expect(resourceProto.attributes.length, equals(4));

        final attrMap = Map.fromEntries(
          resourceProto.attributes.map((kv) => MapEntry(kv.key, kv.value)),
        );

        // Verify List<String>
        final stringArray = attrMap['string_list']!.arrayValue;
        expect(stringArray.values.length, equals(2));
        expect(stringArray.values[0].stringValue, equals('a'));
        expect(stringArray.values[1].stringValue, equals('b'));

        // Verify List<bool>
        final boolArray = attrMap['bool_list']!.arrayValue;
        expect(boolArray.values.length, equals(2));
        expect(boolArray.values[0].boolValue, isTrue);
        expect(boolArray.values[1].boolValue, isFalse);

        // Verify List<int>
        final intArray = attrMap['int_list']!.arrayValue;
        expect(intArray.values.length, equals(3));
        expect(intArray.values[0].intValue, equals(Int64(1)));
        expect(intArray.values[1].intValue, equals(Int64(2)));
        expect(intArray.values[2].intValue, equals(Int64(3)));

        // Verify List<double>
        final doubleArray = attrMap['double_list']!.arrayValue;
        expect(doubleArray.values.length, equals(2));
        expect(doubleArray.values[0].doubleValue, equals(1.0));
        expect(doubleArray.values[1].doubleValue, equals(2.0));
      });
    });

    group('transformMetric', () {
      test('creates Sum proto for sum metric', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final point = MetricPoint.sum(
          attributes: OTel.attributes([]),
          startTime: start,
          time: now,
          value: 100,
        );
        final metric = Metric.sum(
          name: 'test.sum',
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        expect(metricProto.name, equals('test.sum'));
        expect(metricProto.sum.dataPoints.length, equals(1));
        expect(metricProto.sum.isMonotonic, isTrue);
        expect(
          metricProto.sum.aggregationTemporality,
          equals(
              proto.AggregationTemporality.AGGREGATION_TEMPORALITY_CUMULATIVE),
        );
      });

      test('creates Gauge proto for gauge metric', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final point = MetricPoint.gauge(
          attributes: OTel.attributes([]),
          startTime: start,
          time: now,
          value: 42.5,
        );
        final metric = Metric.gauge(
          name: 'test.gauge',
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        expect(metricProto.name, equals('test.gauge'));
        expect(metricProto.gauge.dataPoints.length, equals(1));
        expect(metricProto.gauge.dataPoints.first.asDouble, equals(42.5));
      });

      test('creates Histogram proto for histogram metric', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final histogramValue = HistogramValue(
          sum: 50.0,
          count: 3,
          boundaries: [0, 10, 50, 100],
          bucketCounts: [1, 1, 1, 0],
          min: 2.0,
          max: 30.0,
        );
        final point = MetricPoint(
          attributes: OTel.attributes([]),
          startTime: start,
          endTime: now,
          value: histogramValue,
        );
        final metric = Metric.histogram(
          name: 'test.histogram',
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        expect(metricProto.name, equals('test.histogram'));
        expect(metricProto.histogram.dataPoints.length, equals(1));

        final dp = metricProto.histogram.dataPoints.first;
        expect(dp.sum, equals(50.0));
        expect(dp.count, equals(Int64(3)));
        expect(dp.min, equals(2.0));
        expect(dp.max, equals(30.0));
      });

      test('sets description and unit', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final point = MetricPoint.gauge(
          attributes: OTel.attributes([]),
          startTime: start,
          time: now,
          value: 10,
        );
        final metric = Metric.gauge(
          name: 'test.metric',
          description: 'A test metric',
          unit: 'ms',
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        expect(metricProto.description, equals('A test metric'));
        expect(metricProto.unit, equals('ms'));
      });

      test('histogram with delta temporality', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final histogramValue = HistogramValue(
          sum: 25.0,
          count: 2,
          boundaries: [0, 50, 100],
          bucketCounts: [1, 1, 0],
        );
        final point = MetricPoint(
          attributes: OTel.attributes([]),
          startTime: start,
          endTime: now,
          value: histogramValue,
        );
        final metric = Metric.histogram(
          name: 'test.hist.delta',
          temporality: AggregationTemporality.delta,
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        expect(
          metricProto.histogram.aggregationTemporality,
          equals(proto.AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA),
        );
      });

      test('sum with delta temporality', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final point = MetricPoint.sum(
          attributes: OTel.attributes([]),
          startTime: start,
          time: now,
          value: 50,
        );
        final metric = Metric.sum(
          name: 'test.sum.delta',
          temporality: AggregationTemporality.delta,
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        expect(
          metricProto.sum.aggregationTemporality,
          equals(proto.AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA),
        );
      });

      test('sum with isMonotonic false', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final point = MetricPoint.sum(
          attributes: OTel.attributes([]),
          startTime: start,
          time: now,
          value: 10,
        );
        final metric = Metric.sum(
          name: 'test.sum.nonmono',
          points: [point],
          isMonotonic: false,
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        expect(metricProto.sum.isMonotonic, isFalse);
      });
    });

    group('number data point with exemplars', () {
      test('transforms exemplars for sum metric', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final attrs = OTel.attributes([]);

        final exemplar = Exemplar(
          value: 1.5,
          timestamp: now,
          attributes: attrs,
          filteredAttributes: attrs,
        );

        final point = MetricPoint<num>(
          attributes: attrs,
          startTime: start,
          endTime: now,
          value: 42.0,
          exemplars: [exemplar],
        );

        final metric = Metric.sum(
          name: 'test.sum.exemplars',
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        final dp = metricProto.sum.dataPoints.first;
        expect(dp.exemplars.length, equals(1));
        expect(dp.exemplars.first.asDouble, equals(1.5));
        expect(
          dp.exemplars.first.timeUnixNano,
          equals(Int64(now.microsecondsSinceEpoch * 1000)),
        );
      });

      test('transforms exemplars for gauge metric', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final attrs = OTel.attributes([]);

        final exemplar = Exemplar(
          value: 99.9,
          timestamp: now,
          attributes: attrs,
          filteredAttributes: attrs,
        );

        final point = MetricPoint<num>(
          attributes: attrs,
          startTime: start,
          endTime: now,
          value: 55.0,
          exemplars: [exemplar],
        );

        final metric = Metric.gauge(
          name: 'test.gauge.exemplars',
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        final dp = metricProto.gauge.dataPoints.first;
        expect(dp.exemplars.length, equals(1));
        expect(dp.exemplars.first.asDouble, equals(99.9));
      });
    });

    group('histogram data point with exemplars', () {
      test('transforms exemplars for histogram metric', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final attrs = OTel.attributes([]);

        final exemplar1 = Exemplar(
          value: 5.0,
          timestamp: now,
          attributes: attrs,
          filteredAttributes: attrs,
        );
        final exemplar2 = Exemplar(
          value: 15.0,
          timestamp: now.add(const Duration(seconds: 1)),
          attributes: attrs,
          filteredAttributes: attrs,
        );

        final histogramValue = HistogramValue(
          sum: 20.0,
          count: 2,
          boundaries: [0, 10, 50],
          bucketCounts: [1, 1, 0],
          min: 5.0,
          max: 15.0,
        );

        final point = MetricPoint(
          attributes: attrs,
          startTime: start,
          endTime: now,
          value: histogramValue,
          exemplars: [exemplar1, exemplar2],
        );

        final metric = Metric.histogram(
          name: 'test.hist.exemplars',
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        final dp = metricProto.histogram.dataPoints.first;
        expect(dp.exemplars.length, equals(2));
        expect(dp.exemplars[0].asDouble, equals(5.0));
        expect(dp.exemplars[1].asDouble, equals(15.0));
      });
    });

    group('number data point value conversion', () {
      test('converts non-num value via string parsing', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final attrs = OTel.attributes([]);

        // Create a point with a non-num value that can be parsed to double
        // The _createNumberDataPoint handles this via double.tryParse fallback
        final point = MetricPoint(
          attributes: attrs,
          startTime: start,
          endTime: now,
          value: '123.45',
        );

        final metric = Metric(
          name: 'test.string.value',
          type: MetricType.gauge,
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        final dp = metricProto.gauge.dataPoints.first;
        expect(dp.asDouble, equals(123.45));
      });

      test('falls back to 0.0 for unparseable non-num value', () {
        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final attrs = OTel.attributes([]);

        final point = MetricPoint(
          attributes: attrs,
          startTime: start,
          endTime: now,
          value: 'not-a-number',
        );

        final metric = Metric(
          name: 'test.bad.value',
          type: MetricType.gauge,
          points: [point],
        );

        final metricProto = MetricTransformer.transformMetric(metric);
        final dp = metricProto.gauge.dataPoints.first;
        expect(dp.asDouble, equals(0.0));
      });
    });

    group('_createKeyValue scalar types', () {
      test('handles String value via resource', () {
        final resource = ResourceCreate.create(
          Attributes.of({'key': 'value'}),
        );
        final resourceProto = MetricTransformer.transformResource(resource);
        final attr =
            resourceProto.attributes.firstWhere((kv) => kv.key == 'key');
        expect(attr.value.stringValue, equals('value'));
      });

      test('handles bool value via resource', () {
        final resource = ResourceCreate.create(
          Attributes.of({'flag': true}),
        );
        final resourceProto = MetricTransformer.transformResource(resource);
        final attr =
            resourceProto.attributes.firstWhere((kv) => kv.key == 'flag');
        expect(attr.value.boolValue, isTrue);
      });

      test('handles int value via resource', () {
        final resource = ResourceCreate.create(
          Attributes.of({'count': 42}),
        );
        final resourceProto = MetricTransformer.transformResource(resource);
        final attr =
            resourceProto.attributes.firstWhere((kv) => kv.key == 'count');
        expect(attr.value.intValue, equals(Int64(42)));
      });

      test('handles double value via resource', () {
        final resource = ResourceCreate.create(
          Attributes.of({'ratio': 3.14}),
        );
        final resourceProto = MetricTransformer.transformResource(resource);
        final attr =
            resourceProto.attributes.firstWhere((kv) => kv.key == 'ratio');
        expect(attr.value.doubleValue, equals(3.14));
      });
    });

    group('_createKeyValue array types', () {
      test('handles List<String> value', () {
        final resource = ResourceCreate.create(OTel.attributesFromList([
          OTel.attributeStringList('tags', ['web', 'prod']),
        ]));
        final resourceProto = MetricTransformer.transformResource(resource);
        final attr =
            resourceProto.attributes.firstWhere((kv) => kv.key == 'tags');
        final arr = attr.value.arrayValue;
        expect(arr.values.length, equals(2));
        expect(arr.values[0].stringValue, equals('web'));
        expect(arr.values[1].stringValue, equals('prod'));
      });

      test('handles List<bool> value', () {
        final resource = ResourceCreate.create(OTel.attributesFromList([
          OTel.attributeBoolList('flags', [true, false, true]),
        ]));
        final resourceProto = MetricTransformer.transformResource(resource);
        final attr =
            resourceProto.attributes.firstWhere((kv) => kv.key == 'flags');
        final arr = attr.value.arrayValue;
        expect(arr.values.length, equals(3));
        expect(arr.values[0].boolValue, isTrue);
        expect(arr.values[1].boolValue, isFalse);
        expect(arr.values[2].boolValue, isTrue);
      });

      test('handles List<int> value', () {
        final resource = ResourceCreate.create(OTel.attributesFromList([
          OTel.attributeIntList('ids', [10, 20, 30]),
        ]));
        final resourceProto = MetricTransformer.transformResource(resource);
        final attr =
            resourceProto.attributes.firstWhere((kv) => kv.key == 'ids');
        final arr = attr.value.arrayValue;
        expect(arr.values.length, equals(3));
        expect(arr.values[0].intValue, equals(Int64(10)));
        expect(arr.values[1].intValue, equals(Int64(20)));
        expect(arr.values[2].intValue, equals(Int64(30)));
      });

      test('handles List<double> value', () {
        final resource = ResourceCreate.create(OTel.attributesFromList([
          OTel.attributeDoubleList('scores', [1.1, 2.2, 3.3]),
        ]));
        final resourceProto = MetricTransformer.transformResource(resource);
        final attr =
            resourceProto.attributes.firstWhere((kv) => kv.key == 'scores');
        final arr = attr.value.arrayValue;
        expect(arr.values.length, equals(3));
        expect(arr.values[0].doubleValue, equals(1.1));
        expect(arr.values[1].doubleValue, equals(2.2));
        expect(arr.values[2].doubleValue, equals(3.3));
      });
    });

    group('metric logging', () {
      test('transformMetric logs when metric logging is enabled', () {
        final logs = <String>[];
        OTelLog.metricLogFunction = logs.add;

        final now = DateTime.now();
        final start = now.subtract(const Duration(minutes: 1));
        final point = MetricPoint.gauge(
          attributes: OTel.attributes([]),
          startTime: start,
          time: now,
          value: 10,
        );
        final metric = Metric.gauge(
          name: 'logged.metric',
          points: [point],
        );

        MetricTransformer.transformMetric(metric);

        expect(logs, isNotEmpty);
        expect(
          logs.any((l) => l.contains('logged.metric')),
          isTrue,
        );

        OTelLog.metricLogFunction = null;
      });
    });
  });
}
