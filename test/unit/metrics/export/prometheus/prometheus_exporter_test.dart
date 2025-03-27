// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.


import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('PrometheusExporter', () {
    late PrometheusExporter exporter;

    setUp(() {
      exporter = PrometheusExporter();
    });

    test('exports empty metrics successfully', () async {
      final result = await exporter.export(MetricData(metrics: []));
      expect(result, isTrue);
      expect(exporter.prometheusData, isEmpty);
    });

    test('exports a counter metric correctly', () async {
      final metric = Metric(
        name: 'test_counter',
        description: 'A test counter',
        type: MetricType.sum,
        unit: '1',
        points: [
          MetricPoint(
            attributes: Attributes.of({'label1': 'value1', 'label2': 'value2'}),
            value: 42.0,
            startTime: DateTime.now(),
            endTime: DateTime.now(),
          ),
        ],
      );

      final result = await exporter.export(MetricData(metrics: [metric]));
      expect(result, isTrue);

      final exportData = exporter.prometheusData;
      expect(exportData, contains('# HELP test_counter A test counter'));
      expect(exportData, contains('# TYPE test_counter counter'));
      expect(exportData, contains('test_counter{label1="value1",label2="value2"} 42.0'));
    });

    test('exports a gauge metric correctly', () async {
      final metric = Metric(
        name: 'test_gauge',
        description: 'A test gauge',
        type: MetricType.gauge,
        unit: '1',
        points: [
          MetricPoint(
            attributes: Attributes.of({'environment': 'production'}),
            value: 123.45,
            startTime: DateTime.now(),
            endTime: DateTime.now(),
          ),
        ],
      );

      final result = await exporter.export(MetricData(metrics: [metric]));
      expect(result, isTrue);

      final exportData = exporter.prometheusData;
      expect(exportData, contains('# HELP test_gauge A test gauge'));
      expect(exportData, contains('# TYPE test_gauge gauge'));
      expect(exportData, contains('test_gauge{environment="production"} 123.45'));
    });

    test('exports a histogram metric correctly', () async {
      final boundaries = [0.0, 5.0, 10.0, 25.0, 50.0, 75.0, 100.0];
      final bucketCounts = [0, 2, 5, 15, 23, 28, 30];

      final metric = Metric(
        name: 'test_histogram',
        description: 'A test histogram',
        type: MetricType.histogram,
        unit: 'ms',
        points: [
          MetricPoint(
            attributes: Attributes.of({'operation': 'fetch'}),
            value: HistogramValue(
              sum: 2250.0,
              count: 30,
              bucketCounts: bucketCounts,
              boundaries: boundaries,
            ),
            startTime: DateTime.now(),
            endTime: DateTime.now(),
          ),
        ],
      );

      final result = await exporter.export(MetricData(metrics: [metric]));
      expect(result, isTrue);

      final exportData = exporter.prometheusData;
      expect(exportData, contains('# HELP test_histogram A test histogram'));
      expect(exportData, contains('# TYPE test_histogram histogram'));
      expect(exportData, contains('test_histogram_sum{operation="fetch"} 2250.0'));
      expect(exportData, contains('test_histogram_count{operation="fetch"} 30'));

      // Check each bucket
      expect(exportData, contains('test_histogram_bucket{operation="fetch",le="0"} 0'));
      expect(exportData, contains('test_histogram_bucket{operation="fetch",le="5"} 2'));
      expect(exportData, contains('test_histogram_bucket{operation="fetch",le="10"} 5'));
      expect(exportData, contains('test_histogram_bucket{operation="fetch",le="25"} 15'));
      expect(exportData, contains('test_histogram_bucket{operation="fetch",le="50"} 23'));
      expect(exportData, contains('test_histogram_bucket{operation="fetch",le="75"} 28'));
      expect(exportData, contains('test_histogram_bucket{operation="fetch",le="100"} 30'));
      expect(exportData, contains('test_histogram_bucket{operation="fetch",le="+Inf"} 30'));
    });

    test('handles special characters in metric names and label values', () async {
      final metric = Metric(
        name: 'test.metric-name',
        description: 'Description with \\ backslash and \n newline',
        type: MetricType.sum,
        unit: '1',
        points: [
          MetricPoint(
            attributes: Attributes.of({
              'label.with-special_chars': 'value with "quotes" and \\ backslash'
            }),
            value: 10.0,
            startTime: DateTime.now(),
            endTime: DateTime.now(),
          ),
        ],
      );

      final result = await exporter.export(MetricData(metrics: [metric]));
      expect(result, isTrue);

      final exportData = exporter.prometheusData;
      expect(exportData, contains('# HELP test_metric_name Description with \\\\ backslash and \\n newline'));
      expect(exportData, contains('# TYPE test_metric_name counter'));
      expect(exportData, contains('test_metric_name{label_with_special_chars="value with \\"quotes\\" and \\\\ backslash"} 10.0'));
    });

    test('handles multiple metrics in one export', () async {
      final metrics = [
        Metric(
          name: 'counter_1',
          description: 'First counter',
          type: MetricType.sum,
          unit: '1',
          points: [
            MetricPoint(
              attributes: Attributes.of({'service': 'api'}),
              value: 100.0,
              startTime: DateTime.now(),
              endTime: DateTime.now(),
            ),
          ],
        ),
        Metric(
          name: 'gauge_1',
          description: 'First gauge',
          type: MetricType.gauge,
          unit: 'bytes',
          points: [
            MetricPoint(
              attributes: Attributes.of({'service': 'api'}),
              value: 1024.0,
              startTime: DateTime.now(),
              endTime: DateTime.now(),
            ),
          ],
        ),
      ];

      final result = await exporter.export(MetricData(metrics:metrics));
      expect(result, isTrue);

      final exportData = exporter.prometheusData;
      expect(exportData, contains('# HELP counter_1 First counter'));
      expect(exportData, contains('# TYPE counter_1 counter'));
      expect(exportData, contains('counter_1{service="api"} 100.0'));

      expect(exportData, contains('# HELP gauge_1 First gauge'));
      expect(exportData, contains('# TYPE gauge_1 gauge'));
      expect(exportData, contains('gauge_1{service="api"} 1024.0'));
    });

    test('handles metrics without description', () async {
      final metric = Metric(
        name: 'no_description_metric',
        description: null,
        type: MetricType.sum,
        unit: '1',
        points: [
          MetricPoint(
            attributes: Attributes.of({}),
            value: 5.0,
            startTime: DateTime.now(),
            endTime: DateTime.now(),
          ),
        ],
      );

      final result = await exporter.export(MetricData(metrics: [metric]));
      expect(result, isTrue);

      final exportData = exporter.prometheusData;
      expect(exportData, isNot(contains('# HELP no_description_metric')));
      expect(exportData, contains('# TYPE no_description_metric counter'));
      expect(exportData, contains('no_description_metric{} 5.0'));
    });

    test('refuses to export after shutdown', () async {
      // First, shut down the exporter
      final shutdownResult = await exporter.shutdown();
      expect(shutdownResult, isTrue);

      // Then try to export
      final metric = Metric(
        name: 'test_metric',
        description: 'Test metric',
        type: MetricType.sum,
        unit: '1',
        points: [
          MetricPoint(
            attributes: Attributes.of({}),
            value: 1.0,
            startTime: DateTime.now(),
            endTime: DateTime.now(),
          ),
        ],
      );

      final exportResult = await exporter.export(MetricData(metrics: [metric]));
      expect(exportResult, isFalse);
    });

    test('force flush returns true', () async {
      final result = await exporter.forceFlush();
      expect(result, isTrue);
    });
  });
}
