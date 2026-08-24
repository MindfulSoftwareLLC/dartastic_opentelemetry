// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Pins that OTEL_METRICS_EXEMPLAR_FILTER actually reaches the code that
// applies it. Parsing the variable into MetricsSdkConfig is only half the
// job: without the wiring, setting the variable changes nothing at
// runtime, which is the failure mode the SDK already carries elsewhere
// (env vars declared, parsed, and then ignored).

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/metrics/export/otlp/metric_transformer.dart';
import 'package:test/test.dart';

import '../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('OTEL_METRICS_EXEMPLAR_FILTER wiring', () {
    setUp(() async {
      await OTel.reset();
      // Start from the default so the assertions observe the wiring rather
      // than state left behind by another test - the filter lives in a
      // static, so it leaks across tests by construction.
      MetricTransformer.setExemplarFilter(MetricsExemplarFilter.traceBased);
    });

    tearDown(() async {
      EnvironmentService.testOverrides = null;
      MetricTransformer.setExemplarFilter(MetricsExemplarFilter.traceBased);
      await OTel.reset();
    });

    /// A gauge carrying one exemplar with no trace context. Under
    /// `trace_based` (the default) it is dropped; under `always_on` it
    /// survives - which is what makes it a witness for the filter in use.
    Metric metricWithUntracedExemplar() {
      final now = DateTime.now();
      final attributes = {'witness': 'exemplar'}.toAttributes();
      return Metric(
        name: 'exemplar.wiring.metric',
        type: MetricType.gauge,
        points: [
          MetricPoint.gauge(
            attributes: attributes,
            startTime: now.subtract(const Duration(minutes: 1)),
            time: now,
            value: 10,
            exemplars: [
              Exemplar(
                attributes: attributes,
                filteredAttributes: OTel.attributes(),
                timestamp: now,
                value: 1,
              ),
            ],
          ),
        ],
      );
    }

    test('always_on from the environment reaches the transformer', () async {
      EnvironmentService.testOverrides = {
        'OTEL_METRICS_EXEMPLAR_FILTER': 'always_on',
      };

      await OTel.initialize(
        serviceName: 'exemplar-filter-wiring',
        detectPlatformResources: false,
        metricExporter: MemoryMetricExporter(),
      );

      final transformed =
          MetricTransformer.transformMetric(metricWithUntracedExemplar());

      expect(
        transformed.gauge.dataPoints.first.exemplars,
        hasLength(1),
        reason: 'OTEL_METRICS_EXEMPLAR_FILTER=always_on must keep an '
            'exemplar that has no trace context; if it is dropped the '
            'transformer is still on the trace_based default, meaning the '
            'parsed configuration never reached it',
      );
    });

    test('always_off from the environment reaches the transformer', () async {
      EnvironmentService.testOverrides = {
        'OTEL_METRICS_EXEMPLAR_FILTER': 'always_off',
      };
      // Prove the wiring rather than the default: start from always_on, so
      // an unwired run leaves exemplars in place and fails.
      MetricTransformer.setExemplarFilter(MetricsExemplarFilter.alwaysOn);

      await OTel.initialize(
        serviceName: 'exemplar-filter-wiring-off',
        detectPlatformResources: false,
        metricExporter: MemoryMetricExporter(),
      );

      final transformed =
          MetricTransformer.transformMetric(metricWithUntracedExemplar());

      expect(
        transformed.gauge.dataPoints.first.exemplars,
        isEmpty,
        reason: 'OTEL_METRICS_EXEMPLAR_FILTER=always_off must drop every '
            'exemplar',
      );
    });
  });
}
