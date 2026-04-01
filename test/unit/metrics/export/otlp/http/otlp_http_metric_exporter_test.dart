// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpHttpMetricExporter', () {
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

    group('constructor', () {
      test('creates exporter with default config', () {
        final exporter = OtlpHttpMetricExporter();
        expect(exporter, isNotNull);
      });

      test('creates exporter with custom config', () {
        final config = OtlpHttpMetricExporterConfig(
          endpoint: 'http://custom-host:4318',
          timeout: const Duration(seconds: 30),
          compression: true,
          maxRetries: 5,
        );
        final exporter = OtlpHttpMetricExporter(config);
        expect(exporter, isNotNull);
      });

      test('creates exporter with custom headers', () {
        final config = OtlpHttpMetricExporterConfig(
          headers: {'authorization': 'Bearer test-token'},
        );
        final exporter = OtlpHttpMetricExporter(config);
        expect(exporter, isNotNull);
      });
    });

    group('export', () {
      test('throws StateError after shutdown', () async {
        final exporter = OtlpHttpMetricExporter();
        await exporter.shutdown();

        final metricData = MetricData(
          metrics: [
            Metric.sum(name: 'test-metric', points: []),
          ],
        );

        expect(
          () => exporter.export(metricData),
          throwsA(isA<StateError>()),
        );
      });

      test('with empty metrics returns true', () async {
        final exporter = OtlpHttpMetricExporter();
        final result = await exporter.export(MetricData.empty());
        expect(result, isTrue);
      });

      test('with MetricData.empty() returns true', () async {
        final exporter = OtlpHttpMetricExporter();
        final metricData = MetricData.empty();
        final result = await exporter.export(metricData);
        expect(result, isTrue);
      });
    });

    group('shutdown', () {
      test('completes successfully and returns true', () async {
        final exporter = OtlpHttpMetricExporter();
        final result = await exporter.shutdown();
        expect(result, isTrue);
      });

      test('is idempotent - can be called multiple times', () async {
        final exporter = OtlpHttpMetricExporter();
        final result1 = await exporter.shutdown();
        final result2 = await exporter.shutdown();
        expect(result1, isTrue);
        expect(result2, isTrue);
      });

      test('sets shutdown state so export throws StateError', () async {
        final exporter = OtlpHttpMetricExporter();

        // Export with empty data should work before shutdown
        final beforeResult = await exporter.export(MetricData.empty());
        expect(beforeResult, isTrue);

        await exporter.shutdown();

        // After shutdown, export should throw
        final metricData = MetricData(
          metrics: [
            Metric.sum(name: 'test-metric', points: []),
          ],
        );

        expect(
          () => exporter.export(metricData),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('forceFlush', () {
      test('returns true before shutdown', () async {
        final exporter = OtlpHttpMetricExporter();
        final result = await exporter.forceFlush();
        expect(result, isTrue);
      });

      test('returns true after shutdown', () async {
        final exporter = OtlpHttpMetricExporter();
        await exporter.shutdown();
        final result = await exporter.forceFlush();
        expect(result, isTrue);
      });
    });
  });
}
