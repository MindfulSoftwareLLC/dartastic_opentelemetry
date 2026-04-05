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

  group('MetricData', () {
    Metric createMetric(String name) {
      final now = DateTime.now();
      final attrs = OTel.attributes([OTel.attributeString('key', 'value')]);
      final point = MetricPoint<int>(
        attributes: attrs,
        startTime: now.subtract(const Duration(seconds: 10)),
        endTime: now,
        value: 42,
      );
      return Metric.sum(name: name, points: [point]);
    }

    test('constructor sets properties', () {
      final resource = OTel.resource(
        OTel.attributes([OTel.attributeString('service.name', 'my-svc')]),
      );
      final metric = createMetric('test.metric');
      final data = MetricData(resource: resource, metrics: [metric]);

      expect(data.resource, equals(resource));
      expect(data.metrics, hasLength(1));
      expect(data.metrics.first.name, equals('test.metric'));
    });

    test('empty() creates empty list with null resource', () {
      final data = MetricData.empty();

      expect(data.resource, isNull);
      expect(data.metrics, isEmpty);
    });

    test('filter() returns matching metrics only', () {
      final m1 = createMetric('requests.count');
      final m2 = createMetric('errors.count');
      final m3 = createMetric('requests.duration');
      final data = MetricData(metrics: [m1, m2, m3]);

      final filtered = data.filter((m) => m.name.startsWith('requests'));

      expect(filtered.metrics, hasLength(2));
      expect(filtered.metrics[0].name, equals('requests.count'));
      expect(filtered.metrics[1].name, equals('requests.duration'));
    });

    test('filter() returns empty when nothing matches', () {
      final m1 = createMetric('requests.count');
      final m2 = createMetric('errors.count');
      final data = MetricData(metrics: [m1, m2]);

      final filtered = data.filter((m) => m.name == 'nonexistent');

      expect(filtered.metrics, isEmpty);
    });

    test('filter() preserves resource', () {
      final resource = OTel.resource(
        OTel.attributes([OTel.attributeString('service.name', 'my-svc')]),
      );
      final m1 = createMetric('requests.count');
      final data = MetricData(resource: resource, metrics: [m1]);

      final filtered = data.filter((m) => true);

      expect(filtered.resource, equals(resource));
    });

    test('merge() combines metrics from both', () {
      final m1 = createMetric('metric.a');
      final m2 = createMetric('metric.b');
      final m3 = createMetric('metric.c');

      final data1 = MetricData(metrics: [m1, m2]);
      final data2 = MetricData(metrics: [m3]);

      final merged = data1.merge(data2);

      expect(merged.metrics, hasLength(3));
      expect(merged.metrics[0].name, equals('metric.a'));
      expect(merged.metrics[1].name, equals('metric.b'));
      expect(merged.metrics[2].name, equals('metric.c'));
    });

    test('merge() uses first resource if available', () {
      final resource1 = OTel.resource(
        OTel.attributes([OTel.attributeString('service.name', 'svc-1')]),
      );
      final resource2 = OTel.resource(
        OTel.attributes([OTel.attributeString('service.name', 'svc-2')]),
      );

      final data1 = MetricData(resource: resource1, metrics: []);
      final data2 = MetricData(resource: resource2, metrics: []);

      final merged = data1.merge(data2);

      expect(merged.resource, equals(resource1));
    });

    test('merge() uses other resource if first is null', () {
      final resource2 = OTel.resource(
        OTel.attributes([OTel.attributeString('service.name', 'svc-2')]),
      );

      final data1 = MetricData(metrics: []);
      final data2 = MetricData(resource: resource2, metrics: []);

      final merged = data1.merge(data2);

      expect(merged.resource, equals(resource2));
    });

    test('merge() results in null resource when both are null', () {
      final data1 = MetricData(metrics: []);
      final data2 = MetricData(metrics: []);

      final merged = data1.merge(data2);

      expect(merged.resource, isNull);
    });
  });
}
