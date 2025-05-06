// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/metrics/v1/metrics.pb.dart' as proto;
import 'package:dartastic_opentelemetry/src/metrics/export/otlp/metric_transformer.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('MetricTransformer Tests', () {
    setUp(() async {
      await OTel.reset();
      // Initialize OTel with the metric reader
      await OTel.initialize(
        serviceName: 'metric-transformer-test',
        detectPlatformResources: false,
      );
    });

    test('transformResource converts Resource attributes correctly', () {
      // Resource with various attribute types
      final resource = OTel.resource(Attributes.of({
        'service.name': 'test-service',
        'service.version': '1.0.0',
        'host.id': 'test-host',
        'process.pid': 1234,
        'is.test': true,
        'cpu.usage': 0.75,
      }));

      // Transform the resourceAttributes
      final resourceProto = MetricTransformer.transformResource(resource);

      // Verify attributes were converted correctly
      expect(resourceProto.attributes.length, equals(6));

      // Check each attribute
      final attributeMap = Map.fromEntries(resourceProto.attributes.map((kv) =>
          MapEntry(kv.key, kv.value)));

      expect(attributeMap['service.name']!.stringValue, equals('test-service'));
      expect(attributeMap['service.version']!.stringValue, equals('1.0.0'));
      expect(attributeMap['host.id']!.stringValue, equals('test-host'));
      expect(attributeMap['process.pid']!.intValue, equals(Int64(1234)));
      expect(attributeMap['is.test']!.boolValue, isTrue);
      expect(attributeMap['cpu.usage']!.doubleValue, equals(0.75));
    });

    test('transformMetric converts Gauge metric correctly', () {
      // Create a gauge metric
      final nowTime = DateTime.now();
      final startTime = nowTime.subtract(const Duration(minutes: 5));

      final attributes = {'dimension': 'value'}.toAttributes();
      final metricPoint = MetricPoint.gauge(
        attributes: attributes,
        startTime: startTime,
        time: nowTime,
        value: 42.5,
      );

      final metric = Metric(
        name: 'test.gauge',
        description: 'Test gauge metric',
        unit: 'items',
        type: MetricType.gauge,
        points: [metricPoint],
      );

      // Transform the gauge metric
      final metricProto = MetricTransformer.transformMetric(metric);

      // Verify basic fields
      expect(metricProto.name, equals('test.gauge'));
      expect(metricProto.description, equals('Test gauge metric'));
      expect(metricProto.unit, equals('items'));

      // Verify it was transformed as a gauge
      expect(metricProto.gauge.dataPoints.length, equals(1));

      // Check point details
      final gaugePoint = metricProto.gauge.dataPoints.first;
      expect(gaugePoint.asDouble, equals(42.5));
      expect(gaugePoint.startTimeUnixNano, equals(Int64(startTime.microsecondsSinceEpoch * 1000)));
      expect(gaugePoint.timeUnixNano, equals(Int64(nowTime.microsecondsSinceEpoch * 1000)));

      // Check attributes
      expect(gaugePoint.attributes.length, equals(1));
      expect(gaugePoint.attributes.first.key, equals('dimension'));
      expect(gaugePoint.attributes.first.value.stringValue, equals('value'));
    });

    test('transformMetric converts Sum metric correctly', () {
      // Create a sum metric
      final nowTime = DateTime.now();
      final startTime = nowTime.subtract(const Duration(minutes: 5));

      final attributes = {'counter': 'requests'}.toAttributes();
      final metricPoint = MetricPoint.sum(
        attributes: attributes,
        startTime: startTime,
        time: nowTime,
        value: 100,
        isMonotonic: true,
      );

      final metric = Metric.sum(
        name: 'test.counter',
        description: 'Test counter metric',
        unit: 'requests',
        temporality: AggregationTemporality.cumulative,
        points: [metricPoint],
        isMonotonic: true,
      );

      // Transform the sum metric
      final metricProto = MetricTransformer.transformMetric(metric);

      // Verify basic fields
      expect(metricProto.name, equals('test.counter'));
      expect(metricProto.description, equals('Test counter metric'));
      expect(metricProto.unit, equals('requests'));

      // Verify it was transformed as a sum
      expect(metricProto.sum.dataPoints.length, equals(1));
      expect(metricProto.sum.isMonotonic, isTrue);
      expect(metricProto.sum.aggregationTemporality, equals(proto.AggregationTemporality.AGGREGATION_TEMPORALITY_CUMULATIVE));

      // Check point details
      final sumPoint = metricProto.sum.dataPoints.first;
      expect(sumPoint.asDouble, equals(100.0));
      expect(sumPoint.startTimeUnixNano, equals(Int64(startTime.microsecondsSinceEpoch * 1000)));
      expect(sumPoint.timeUnixNano, equals(Int64(nowTime.microsecondsSinceEpoch * 1000)));

      // Check attributes
      expect(sumPoint.attributes.length, equals(1));
      expect(sumPoint.attributes.first.key, equals('counter'));
      expect(sumPoint.attributes.first.value.stringValue, equals('requests'));
    });

    test('transformMetric converts Histogram metric correctly', () {
      // Create a histogram metric
      final nowTime = DateTime.now();
      final startTime = nowTime.subtract(const Duration(minutes: 5));

      final attributes = {'endpoint': '/api'}.toAttributes();

      // Create histogram point with bucket data
      final histogramValue = HistogramValue(
        sum: 100.0,
        count: 5,
        boundaries: [0, 10, 20, 50, 100],
        bucketCounts: [1, 1, 2, 1, 0],
        min: 1.0,
        max: 75.0,
      );

      final metricPoint = MetricPoint(
        attributes: attributes,
        startTime: startTime,
        endTime: nowTime,
        value: histogramValue,
      );

      final metric = Metric(
        name: 'http.duration',
        description: 'HTTP request duration',
        unit: 'ms',
        type: MetricType.histogram,
        points: [metricPoint],
        temporality: AggregationTemporality.delta,
      );

      // Transform the histogram metric
      final metricProto = MetricTransformer.transformMetric(metric);

      // Verify basic fields
      expect(metricProto.name, equals('http.duration'));
      expect(metricProto.description, equals('HTTP request duration'));
      expect(metricProto.unit, equals('ms'));

      // Verify it was transformed as a histogram
      expect(metricProto.histogram.dataPoints.length, equals(1));
      expect(metricProto.histogram.aggregationTemporality, equals(proto.AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA));

      // Check point details
      final histogramPoint = metricProto.histogram.dataPoints.first;
      expect(histogramPoint.sum, equals(100.0));
      expect(histogramPoint.count, equals(Int64(5)));
      expect(histogramPoint.min, equals(1.0));
      expect(histogramPoint.max, equals(75.0));

      // Check buckets
      expect(histogramPoint.explicitBounds, equals([0, 10, 20, 50, 100]));
      expect(histogramPoint.bucketCounts.map((c) => c.toInt()).toList(), equals([1, 1, 2, 1, 0]));

      // Check attributes
      expect(histogramPoint.attributes.length, equals(1));
      expect(histogramPoint.attributes.first.key, equals('endpoint'));
      expect(histogramPoint.attributes.first.value.stringValue, equals('/api'));
    });

    test('transforms attributes with various types correctly', () {
      // Test by creating a metric with various attribute types and verify conversion
      final nowTime = DateTime.now();
      final startTime = nowTime.subtract(const Duration(minutes: 1));

      // Create attributes with different types
      final attributes = Attributes.of({
        'string_key': 'string_value',
        'bool_key': true,
        'int_key': 42,
        'double_key': 3.14,
        // Arrays can't be directly used in Attributes.of(), so we'll skip that test
      });

      final metricPoint = MetricPoint.gauge(
        attributes: attributes,
        startTime: startTime,
        time: nowTime,
        value: 100,
      );

      final metric = Metric(
        name: 'attribute_test_metric',
        type: MetricType.gauge,
        points: [metricPoint],
      );

      // Transform the metric
      final metricProto = MetricTransformer.transformMetric(metric);

      // Get the attributes from the transformed point
      final protoAttributes = metricProto.gauge.dataPoints.first.attributes;

      // Create a map for easier verification
      final attributeMap = Map.fromEntries(protoAttributes.map((kv) =>
          MapEntry(kv.key, kv.value)));

      // Verify each attribute type was converted correctly
      expect(attributeMap['string_key']!.stringValue, equals('string_value'));
      expect(attributeMap['bool_key']!.boolValue, isTrue);
      expect(attributeMap['int_key']!.intValue, equals(Int64(42)));
      expect(attributeMap['double_key']!.doubleValue, equals(3.14));
    });
  });
}
