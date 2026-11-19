// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

Metric metric(String name, num value,
        {bool monotonic = true,
        AggregationTemporality temporality =
            AggregationTemporality.cumulative}) =>
    Metric(
        name: name,
        type: MetricType.sum,
        isMonotonic: monotonic,
        temporality: temporality,
        points: [
          MetricPoint(
            attributes:
                OTel.attributesFromMap({'literal': 'AttributeValue(text)'}),
            startTime: DateTime.utc(2026),
            endTime: DateTime.utc(2026),
            value: value,
          )
        ]);

void main() {
  setUp(() async {
    EnvironmentService.testOverrides = {
      'OTEL_TRACES_EXPORTER': 'none',
      'OTEL_METRICS_EXPORTER': 'none',
      'OTEL_LOGS_EXPORTER': 'none',
    };
    await OTel.initialize(detectPlatformResources: false);
  });
  tearDown(() async {
    await OTel.reset();
    EnvironmentService.testOverrides = null;
  });

  test('counter suffix is idempotent and non-monotonic sums are gauges',
      () async {
    final exporter = PrometheusExporter();
    await exporter.export(MetricData(metrics: [
      metric('already_total', 2),
      metric('active', -3, monotonic: false)
    ]));
    expect(exporter.prometheusData, contains('# TYPE already_total counter'));
    expect(exporter.prometheusData, isNot(contains('_total_total')));
    expect(exporter.prometheusData, contains('# TYPE active gauge'));
    expect(exporter.prometheusData, contains('literal="AttributeValue(text)"'));
  });

  test('empty collection removes previously exported samples', () async {
    final exporter = PrometheusExporter();
    await exporter.export(MetricData(metrics: [metric('old', 1)]));
    await exporter.export(MetricData.empty());
    expect(exporter.prometheusData, isEmpty);
  });

  test('one target info exists even without instruments', () async {
    final exporter = PrometheusExporter();
    await exporter.export(MetricData(
        resource: OTel.resource(OTel.attributesFromMap({
          'service.name': 'my"service',
          'a': ['x', 'y']
        })),
        metrics: [metric('target_info', 9, monotonic: false)]));
    final data = exporter.prometheusData;
    expect(RegExp(r'^target_info\{', multiLine: true).allMatches(data),
        hasLength(1));
    expect(data, contains(r'service_name="my\"service"'));
    expect(data, contains(r'a="[\"x\",\"y\"]"'));
    expect(data, endsWith(' 1\n'));
  });

  test('duplicate metadata is suppressed and conflicting types are dropped',
      () async {
    final exporter = PrometheusExporter();
    await exporter.export(MetricData(metrics: [
      metric('same', 1),
      metric('same', 2),
      metric('same_total', 3, monotonic: false)
    ]));
    expect(
        RegExp(r'^# TYPE same_total ', multiLine: true)
            .allMatches(exporter.prometheusData),
        hasLength(1));
    expect(exporter.prometheusData, isNot(contains(' 3\n')));
  });

  test('numbers use Prometheus spellings and invalid initial names are escaped',
      () async {
    final exporter = PrometheusExporter();
    await exporter.export(MetricData(metrics: [
      metric('1inf', double.infinity),
      metric('negative', double.negativeInfinity, monotonic: false),
      metric('nan', double.nan, monotonic: false)
    ]));
    expect(exporter.prometheusData, contains('# TYPE _1inf_total counter'));
    expect(exporter.prometheusData, contains(' +Inf\n'));
    expect(exporter.prometheusData, contains(' -Inf\n'));
    expect(exporter.prometheusData, contains(' NaN\n'));
  });

  test('delta sums are not misrepresented as cumulative counters', () async {
    final exporter = PrometheusExporter();
    await exporter.export(MetricData(metrics: [
      metric('delta', 2, temporality: AggregationTemporality.delta)
    ]));
    expect(exporter.prometheusData, isEmpty);
  });

  test('scope metadata becomes escaped labels', () async {
    final exporter = PrometheusExporter();
    final scope = OTel.instrumentationScope(
        name: 'scope',
        version: '1',
        schemaUrl: 'https://example.org/schema',
        attributes:
            OTel.attributesFromMap({'custom.key': 'value', 'name': 'ignored'}));
    await exporter.export(MetricData(metrics: [
      Metric(
        name: 'scoped',
        type: MetricType.sum,
        isMonotonic: true,
        instrumentationScope: scope,
        points: metric('unused', 1).points,
      )
    ]));
    expect(exporter.prometheusData, contains('otel_scope_name="scope"'));
    expect(exporter.prometheusData, contains('otel_scope_version="1"'));
    expect(exporter.prometheusData,
        contains('otel_scope_schema_url="https://example.org/schema"'));
    expect(exporter.prometheusData, contains('otel_scope_custom_key="value"'));
    expect(exporter.prometheusData, isNot(contains('ignored')));
  });

  test('non-finite values inside array labels do not prevent export', () async {
    final exporter = PrometheusExporter();
    expect(
        await exporter.export(MetricData(
            resource: OTel.resource(OTel.attributesFromMap({
              'values': [double.infinity, double.nan]
            })),
            metrics: [metric('counter', 1)])),
        isTrue);
    expect(
        exporter.prometheusData, contains(r'values="[\"Infinity\",\"NaN\"]"'));
    expect(exporter.prometheusData, contains('counter_total'));
  });
}
