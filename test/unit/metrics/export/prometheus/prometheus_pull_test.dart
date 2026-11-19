// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

@TestOn('vm')
library;

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/metrics/export/prometheus/prometheus_server_io.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  late http.Client client;

  setUp(() {
    client = http.Client();
    EnvironmentService.testOverrides = {
      'OTEL_TRACES_EXPORTER': 'none',
      'OTEL_LOGS_EXPORTER': 'none',
      'OTEL_METRICS_EXPORTER': 'prometheus',
      'OTEL_EXPORTER_PROMETHEUS_HOST': '127.0.0.1',
      'OTEL_EXPORTER_PROMETHEUS_PORT': '0',
    };
  });

  tearDown(() async {
    client.close();
    await OTel.reset();
    EnvironmentService.testOverrides = null;
  });

  Future<PrometheusMetricReader> initialize() async {
    await OTel.initialize(
        serviceName: 'scrape-test', detectPlatformResources: false);
    final reader = OTel.meterProvider()
        .metricReaders
        .whereType<PrometheusMetricReader>()
        .single;
    expect(await reader.ready, isTrue);
    return reader;
  }

  Uri endpoint(PrometheusMetricReader reader, [String path = '/metrics']) =>
      Uri.parse('http://127.0.0.1:${reader.boundPort}$path');

  test('env pipeline scrapes fresh cumulative counter and histogram data',
      () async {
    final reader = await initialize();
    final meter = OTel.meter();
    final counter = meter.createCounter<int>(name: 'requests');
    final upDown = meter.createUpDownCounter<int>(name: 'active');
    final histogram = meter.createHistogram<double>(
        name: 'latency',
        advisory: const InstrumentAdvisory(explicitBucketBoundaries: [5, 10]));
    counter.add(2);
    upDown.add(3);
    upDown.add(-1);
    for (final value in [1.0, 6.0, 20.0]) {
      histogram.record(value);
    }
    final first = await client.get(endpoint(reader));
    expect(first.statusCode, 200);
    expect(
        first.headers['content-type'], contains('text/plain; version=0.0.4'));
    expect(first.body, contains('# TYPE requests_total counter'));
    expect(first.body,
        matches(r'requests_total\{[^}]*otel_scope_name=\"[^\"]+\"[^}]*\} 2'));
    expect(first.body, contains('# TYPE active gauge'));
    expect(first.body,
        matches(r'active\{[^}]*otel_scope_name=\"[^\"]+\"[^}]*\} 2'));
    expect(first.body, matches(r'latency_bucket\{[^}]*le="5"\} 1'));
    expect(first.body, matches(r'latency_bucket\{[^}]*le="10"\} 2'));
    expect(first.body, matches(r'latency_bucket\{[^}]*le="\+Inf"\} 3'));
    expect(first.body,
        matches(r'latency_count\{[^}]*otel_scope_name=\"[^\"]+\"[^}]*\} 3'));
    expect(first.body,
        matches(r'latency_sum\{[^}]*otel_scope_name=\"[^\"]+\"[^}]*\} 27.0'));
    expect(RegExp(r'^target_info\{', multiLine: true).allMatches(first.body),
        hasLength(1));
    expect(first.body, contains('service_name="scrape-test"'));
    counter.add(4);
    final second = await client.get(endpoint(reader));
    expect(second.body,
        matches(r'requests_total\{[^}]*otel_scope_name=\"[^\"]+\"[^}]*\} 6'));
    expect(second.body,
        matches(r'latency_count\{[^}]*otel_scope_name=\"[^\"]+\"[^}]*\} 3'));
  });

  test('same-name metrics retain scope and form one contiguous family',
      () async {
    final reader = await initialize();
    final first = OTel.meterProvider().getMeter(
        name: 'first',
        version: '1',
        schemaUrl: 'https://example.test/schema',
        attributes: OTel.attributesFromMap({'component': 'test'}));
    final second = OTel.meterProvider().getMeter(name: 'second', version: '2');
    final attrs = OTel.attributesFromMap({'k': 'v'});
    first.createCounter<int>(name: 'dup.count').add(1, attrs);
    first.createCounter<int>(name: 'mid.count').add(1);
    second
        .createCounter<int>(name: 'dup.count', description: 'Duplicate count')
        .add(2, attrs);
    final body = (await client.get(endpoint(reader))).body;
    final samples = body
        .split('\n')
        .where((line) => line.startsWith('dup_count_total{'))
        .toList();
    expect(samples, hasLength(2));
    expect(samples[0], contains('otel_scope_name="first"'));
    expect(samples[0], contains('otel_scope_version="1"'));
    expect(samples[0],
        contains('otel_scope_schema_url="https://example.test/schema"'));
    expect(samples[0], contains('otel_scope_component="test"'));
    expect(samples[0], endsWith(' 1'));
    expect(samples[1], contains('otel_scope_name="second"'));
    expect(samples[1], endsWith(' 2'));
    expect(body, contains('# HELP dup_count_total Duplicate count'));
    expect(
        RegExp(r'^# TYPE dup_count_total ', multiLine: true).allMatches(body),
        hasLength(1));
    expect(body.indexOf(samples[1]),
        lessThan(body.indexOf('# TYPE mid_count_total')));
  });

  test('all SDK instrument kinds propagate their meter scope', () async {
    await initialize();
    final meter =
        OTel.meterProvider().getMeter(name: 'all-kinds', version: '3');
    meter.createCounter<int>(name: 'counter').add(1);
    meter.createUpDownCounter<int>(name: 'updown').add(-1);
    meter.createGauge<int>(name: 'gauge').record(2);
    meter.createHistogram<double>(name: 'histogram').record(3);
    meter.createObservableCounter<int>(name: 'observable_counter', callbacks: [
      (result) => result.observe(4),
    ]);
    meter.createObservableUpDownCounter<int>(
        name: 'observable_updown',
        callbacks: [
          (result) => result.observe(-5),
        ]);
    meter.createObservableGauge<int>(name: 'observable_gauge', callbacks: [
      (result) => result.observe(6),
    ]);
    final metrics = await OTel.meterProvider().collectAllMetrics();
    expect(metrics.map((metric) => metric.name).toSet(), {
      'counter',
      'updown',
      'gauge',
      'histogram',
      'observable_counter',
      'observable_updown',
      'observable_gauge',
    });
    for (final metric in metrics) {
      expect(metric.instrumentationScope?.name, 'all-kinds',
          reason: metric.name);
      expect(metric.instrumentationScope?.version, '3', reason: metric.name);
    }
  });

  test('invalid programmatic ports leave initialization retryable', () async {
    for (final selection in ['prometheus', 'none']) {
      EnvironmentService.testOverrides!['OTEL_METRICS_EXPORTER'] = selection;
      for (final port in [-1, 65536, 70000]) {
        await expectLater(
            OTel.initialize(
                prometheusPort: port, detectPlatformResources: false),
            throwsRangeError);
      }
      await OTel.initialize(prometheusPort: 0, detectPlatformResources: false);
      await OTel.reset();
    }
  });

  test('blank programmatic host uses localhost', () async {
    await OTel.initialize(
        prometheusHost: '  ',
        prometheusPort: 0,
        detectPlatformResources: false);
    final reader =
        OTel.meterProvider().metricReaders.single as PrometheusMetricReader;
    expect(reader.host, 'localhost');
    expect(await reader.ready, isTrue);
  });

  test('failed scrapes return 500 and log at error level', () async {
    final server = PrometheusServer();
    final logs = <String>[];
    final oldLog = OTelLog.logFunction;
    final oldLevel = OTelLog.currentLevel;
    OTelLog.logFunction = logs.add;
    OTelLog.currentLevel = LogLevel.error;
    try {
      await server.start(
          '127.0.0.1', 0, () async => throw StateError('scrape regression'));
      final response = await client
          .get(Uri.parse('http://127.0.0.1:${server.port}/metrics'));
      expect(response.statusCode, 500);
      expect(logs, contains(contains('Prometheus scrape failed:')));
      expect(logs, contains(contains('scrape regression')));
    } finally {
      await server.close();
      OTelLog.logFunction = oldLog;
      OTelLog.currentLevel = oldLevel;
    }
  });

  test('routes, methods and Accept negotiation', () async {
    final reader = await initialize();
    expect((await client.get(endpoint(reader, '/missing'))).statusCode, 404);
    final post = await client.post(endpoint(reader));
    expect(post.statusCode, 405);
    expect(post.headers['allow'], 'GET');
    for (final header in [
      'text/plain; version=0.0.4',
      '*/*',
      'text/*',
      'application/openmetrics-text;q=1, text/plain;version=0.0.4;q=0.5',
      'text/plain;version="0.0.4";charset=utf-8;escaping=underscores',
    ]) {
      expect(
          (await client.get(endpoint(reader), headers: {'Accept': header}))
              .statusCode,
          200,
          reason: header);
    }
    for (final header in [
      'application/json',
      'text/plain;version=1.0.0',
      'text/plain;q=0, */*;q=1',
      'text/plain;q=0, text/*;version=0.0.4;q=1',
      'text/plain;charset=utf-8;q=0, text/plain;q=1',
      '*/*;q=0',
      'text/plain;q=bogus',
      'text/plain;q=2',
      'text/plain;q=NaN',
      'text/plain;escaping=values',
    ]) {
      expect(
          (await client.get(endpoint(reader), headers: {'Accept': header}))
              .statusCode,
          406,
          reason: header);
    }
  });

  test('shutdown releases port and is idempotent', () async {
    final reader = await initialize();
    final port = reader.boundPort!;
    expect(await reader.forceFlush(), isTrue);
    expect(await OTel.meterProvider().shutdown(), isTrue);
    expect(await reader.shutdown(), isTrue);
    expect(reader.boundPort, isNull);
    expect(await reader.forceFlush(), isFalse);
    final rebound = await HttpServer.bind('127.0.0.1', port);
    await rebound.close(force: true);
  });

  test('mixed exporters use independent pull and periodic readers', () async {
    EnvironmentService.testOverrides!['OTEL_METRICS_EXPORTER'] =
        'prometheus,console';
    final reader = await initialize();
    final readers = OTel.meterProvider().metricReaders;
    expect(readers, hasLength(2));
    expect(readers.whereType<PeriodicExportingMetricReader>().single.exporter,
        isA<ConsoleMetricExporter>());
    expect((await client.get(endpoint(reader))).statusCode, 200);
  });

  test('programmatic listener settings override environment', () async {
    EnvironmentService.testOverrides!['OTEL_EXPORTER_PROMETHEUS_HOST'] =
        'invalid.invalid';
    EnvironmentService.testOverrides!['OTEL_EXPORTER_PROMETHEUS_PORT'] = '9464';
    await OTel.initialize(
        prometheusHost: '127.0.0.1',
        prometheusPort: 0,
        detectPlatformResources: false);
    final reader =
        OTel.meterProvider().metricReaders.single as PrometheusMetricReader;
    expect(reader.host, '127.0.0.1');
    expect(reader.port, 0);
    expect(reader.boundPort, greaterThan(0));
  });

  test('none and disabled SDK never install a listener', () async {
    for (final values in [
      {'OTEL_METRICS_EXPORTER': 'none,prometheus'},
      {'OTEL_METRICS_EXPORTER': 'prometheus', 'OTEL_SDK_DISABLED': 'true'},
    ]) {
      EnvironmentService.testOverrides!.addAll(values);
      await OTel.initialize(detectPlatformResources: false);
      expect(OTel.meterProvider().metricReaders, isEmpty);
      await OTel.reset();
    }
  });

  test('explicit exporter wins over prometheus selection', () async {
    await OTel.initialize(
        metricExporter: ConsoleMetricExporter(),
        detectPlatformResources: false);
    final reader = OTel.meterProvider().metricReaders.single;
    expect(reader, isA<PeriodicExportingMetricReader>());
  });

  test('manual factory reader starts on registration, even during shutdown',
      () async {
    await OTel.initialize(enableMetrics: false, detectPlatformResources: false);
    final reader = OTel.prometheusMetricReader(host: '127.0.0.1', port: 0);
    expect(await reader.ready, isFalse);
    OTel.meterProvider().addMetricReader(reader);
    expect(await reader.shutdown(), isTrue);
    expect(reader.boundPort, isNull);
    expect((await reader.collect()).metrics, isEmpty);
  });

  test('bind failure is reported without throwing out of initialization',
      () async {
    final occupied = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(() => occupied.close(force: true));
    EnvironmentService.testOverrides!['OTEL_EXPORTER_PROMETHEUS_PORT'] =
        '${occupied.port}';
    await OTel.initialize(detectPlatformResources: false);
    final reader =
        OTel.meterProvider().metricReaders.single as PrometheusMetricReader;
    expect(await reader.ready, isFalse);
    expect(reader.boundPort, isNull);
  });

  test('concurrent scrapes return consistent cumulative snapshots', () async {
    final reader = await initialize();
    OTel.meter().createCounter<int>(name: 'parallel').add(17);
    final responses = await Future.wait(
        List.generate(8, (_) => client.get(endpoint(reader))));
    for (final response in responses) {
      expect(response.statusCode, 200);
      expect(
          response.body,
          matches(
              r'parallel_total\{[^}]*otel_scope_name=\"[^\"]+\"[^}]*\} 17'));
    }
  });

  test('observable callbacks execute on each scrape, not forceFlush', () async {
    final reader = await initialize();
    var observations = 0;
    OTel.meter().createObservableGauge<int>(name: 'observations', callbacks: [
      (result) => result.observe(++observations),
    ]);
    expect(observations, 0);
    await reader.forceFlush();
    expect(observations, 0);
    expect((await client.get(endpoint(reader))).body,
        matches(r'observations\{[^}]*otel_scope_name=\"[^\"]+\"[^}]*\} 1'));
    expect((await client.get(endpoint(reader))).body,
        matches(r'observations\{[^}]*otel_scope_name=\"[^\"]+\"[^}]*\} 2'));
  });

  test('manual reader defaults and argument validation', () async {
    await OTel.initialize(enableMetrics: false, detectPlatformResources: false);
    final reader = OTel.prometheusMetricReader();
    expect(reader.host, 'localhost');
    expect(reader.port, 9464);
    expect((await reader.collect()).metrics, isEmpty);
    expect(() => OTel.prometheusMetricReader(port: -1), throwsRangeError);
    expect(() => OTel.prometheusMetricReader(port: 65536), throwsRangeError);
    expect(() => OTel.prometheusMetricReader(host: ''), throwsArgumentError);
    await reader.shutdown();
    expect(() => reader.registerMeterProvider(OTel.meterProvider()),
        throwsStateError);
  });
}
