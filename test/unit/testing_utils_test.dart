// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Coverage for the shipped test utilities (lib/testing.dart) and the
// ConsoleMetricExporter.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    await OTel.reset();
    EnvironmentService.testOverrides = {
      'OTEL_TRACES_EXPORTER': 'none',
      'OTEL_METRICS_EXPORTER': 'none',
      'OTEL_LOGS_EXPORTER': 'none',
    };
    await OTel.initialize(
      serviceName: 'testing-utils-test',
      detectPlatformResources: false,
      enableMetrics: true,
      enableLogs: false,
    );
  });

  tearDown(() async {
    try {
      await OTel.shutdown();
    } catch (_) {}
    await OTel.reset();
    EnvironmentService.testOverrides = null;
  });

  group('InMemorySpanExporter', () {
    test('stores spans, flushes, and refuses export after shutdown', () async {
      final exporter = InMemorySpanExporter();
      final span = OTel.tracer().startSpan('kept')..end();
      await exporter.export([span]);
      expect(exporter.findSpansStartingWith('kep'), hasLength(1));
      await exporter.forceFlush();
      await exporter.shutdown();
      expect(() => exporter.export([span]), throwsStateError);
    });
  });

  group('InMemoryLogExporter', () {
    test('flushes and shuts down', () async {
      final exporter = InMemoryLogExporter();
      await exporter.forceFlush();
      await exporter.shutdown();
    });
  });

  group('InMemoryMetricExporter', () {
    test('exports, flushes, and reports shutdown through forceFlush', () async {
      final exporter = InMemoryMetricExporter();
      expect(await exporter.export(MetricData.empty()), isTrue);
      expect(await exporter.forceFlush(), isTrue);
      expect(await exporter.shutdown(), isTrue);
      expect(await exporter.forceFlush(), isFalse);
    });
  });

  group('OnDemandMetricReader', () {
    test('collects on demand, flushes through its exporter, and shuts down',
        () async {
      final exporter = InMemoryMetricExporter();
      final reader = OnDemandMetricReader(exporter);

      // Unattached reader collects nothing.
      expect((await reader.collect()).metrics, isEmpty);

      OTel.meterProvider().addMetricReader(reader);
      OTel.meter('on-demand').createCounter<int>(name: 'hits').add(3);

      final collected = await reader.collect();
      expect(collected.metrics, isNotEmpty);

      expect(await reader.forceFlush(), isTrue);
      expect(await reader.shutdown(), isTrue);
      expect(await reader.forceFlush(), isFalse);
      expect(await reader.shutdown(), isTrue,
          reason: 'second shutdown is a no-op success');
    });
  });

  group('ConsoleMetricExporter', () {
    test('prints real collected metrics and exemplar counts', () async {
      OTel.meter('console').createCounter<int>(name: 'printed').add(1);
      final metrics = await OTel.meterProvider().collectAllMetrics();
      final data =
          MetricData(resource: OTel.meterProvider().resource, metrics: metrics);

      final exporter = ConsoleMetricExporter();
      expect(await exporter.export(data), isTrue);

      // Manual metric with exemplars to reach the exemplar print branch.
      final now = DateTime.now();
      final withExemplars = MetricData(metrics: [
        Metric(
          name: 'exemplar.metric',
          type: MetricType.sum,
          points: [
            MetricPoint<int>(
              attributes: OTel.attributesFromMap({'k': 'v'}),
              startTime: now,
              endTime: now,
              value: 42,
              exemplars: [
                Exemplar(
                  attributes: OTel.attributesFromMap({'e': '1'}),
                  filteredAttributes: OTel.attributes(),
                  timestamp: now,
                  value: 42,
                ),
              ],
            ),
          ],
        ),
      ]);
      expect(await exporter.export(withExemplars), isTrue);

      expect(await exporter.forceFlush(), isTrue);
      expect(await exporter.shutdown(), isTrue);
      expect(await exporter.export(data), isFalse,
          reason: 'export after shutdown fails');
    });
  });
}
