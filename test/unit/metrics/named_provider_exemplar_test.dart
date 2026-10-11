// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Regression test for the exemplar filter default on providers that
// MetricsConfiguration never configures.
//
// While MeterProvider.exemplarFilter was nullable and both storages guarded
// on `exemplarFilter != null`, null meant "sample nothing". Only the default
// provider is assigned a filter, by MetricsConfiguration.configureMeterProvider,
// so any provider from addMeterProvider silently produced no exemplars at all.
//
// metrics/sdk.md requires the opposite: "Exemplar sampling SHOULD be turned on
// by default" and "The ExemplarFilter ... default value SHOULD be TraceBased".

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    await OTel.reset();
    EnvironmentService.testOverrides = {'OTEL_TRACES_EXPORTER': 'none'};
    await OTel.initialize(
      serviceName: 'named-provider-exemplar-test',
      detectPlatformResources: false,
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

  /// Records [value] on a counter from [provider] inside a sampled span and
  /// returns the exemplar count collected for it.
  Future<int> exemplarsForCounterIn(MeterProvider provider) async {
    final counter =
        provider.getMeter(name: 'probe').createCounter<int>(name: 'c');

    final tracer = OTel.tracer();
    final span = tracer.startSpan('probe-span');
    await tracer.withSpanAsync(span, () async => counter.add(7));
    span.end();

    var total = 0;
    for (final metric in await provider.collectAllMetrics()) {
      for (final point in metric.points) {
        total += point.exemplars?.length ?? 0;
      }
    }
    return total;
  }

  test('a named provider defaults to TraceBased rather than no filter', () {
    final named = OTel.addMeterProvider('named');

    expect(named.exemplarFilter, isA<TraceBasedExemplarFilter>(),
        reason: 'the spec default is TraceBased, and an unset filter would '
            'silently disable exemplar sampling entirely');
  });

  test('a named provider samples exemplars inside a sampled span', () async {
    final named = OTel.addMeterProvider('named');

    expect(await exemplarsForCounterIn(named), 1);
  });

  test('the default provider still samples exemplars', () async {
    expect(await exemplarsForCounterIn(OTel.meterProvider()), 1);
  });

  test('a named provider honours an explicitly assigned AlwaysOff filter',
      () async {
    final named = OTel.addMeterProvider('named')
      ..exemplarFilter = const AlwaysOffExemplarFilter();

    expect(await exemplarsForCounterIn(named), 0);
  });
}
