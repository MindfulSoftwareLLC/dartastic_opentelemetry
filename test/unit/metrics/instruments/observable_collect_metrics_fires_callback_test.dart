// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.
//
// Regression for #155 — the OTel spec requires observable instruments
// to invoke their registered callbacks on every collection cycle. Pre-
// fix, collectMetrics() read from internal storage without driving the
// callback, so a customer who registered an ObservableGauge with a
// callback and let the metric reader scrape it (the normal usage path)
// got an empty series. These tests pin the post-fix contract: one call
// to collectMetrics() == one callback fire, no manual collect() needed.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('collectMetrics() fires callback per OTel spec (#155 regression)', () {
    late MeterProvider meterProvider;
    late Meter meter;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        endpoint: 'http://localhost:4317',
        detectPlatformResources: false,
      );
      meterProvider = OTel.meterProvider();
      meter = meterProvider.getMeter(name: 'test-meter') as Meter;
    });

    tearDown(() async {
      await meterProvider.shutdown();
      await OTel.reset();
    });

    test('ObservableGauge: one collectMetrics == one callback fire', () {
      var fires = 0;
      final gauge = meter.createObservableGauge<int>(
        name: 'g',
        callback: (APIObservableResult<int> r) {
          fires++;
          r.observe(fires);
        },
      ) as ObservableGauge<int>;

      // No manual collect() — this is the spec-correct usage path.
      final metrics = gauge.collectMetrics();
      expect(fires, equals(1), reason: 'collectMetrics must fire callback');
      expect(metrics.single.points.single.value, equals(1));

      gauge.collectMetrics();
      expect(fires, equals(2));

      gauge.collectMetrics();
      expect(fires, equals(3));
    });

    test('ObservableCounter: one collectMetrics == one callback fire', () {
      var fires = 0;
      var cumulative = 0;
      final counter = meter.createObservableCounter<int>(
        name: 'c',
        callback: (APIObservableResult<int> r) {
          fires++;
          cumulative += 10;
          r.observe(cumulative);
        },
      ) as ObservableCounter<int>;

      final metrics = counter.collectMetrics();
      expect(fires, equals(1));
      expect(metrics.single.points.single.value, equals(10));

      counter.collectMetrics();
      expect(fires, equals(2));
    });

    test('ObservableUpDownCounter: one collectMetrics == one callback fire',
        () {
      var fires = 0;
      final counter = meter.createObservableUpDownCounter<int>(
        name: 'udc',
        callback: (APIObservableResult<int> r) {
          fires++;
          r.observe(fires * 100);
        },
      ) as ObservableUpDownCounter<int>;

      final metrics = counter.collectMetrics();
      expect(fires, equals(1));
      expect(metrics.single.points.single.value, equals(100));

      counter.collectMetrics();
      expect(fires, equals(2));
    });

    test('storage reflects callback value after collectMetrics, not before',
        () {
      // The bug surfaced as "register a gauge, scrape — series stays at
      // zero". Pin that: a fresh gauge whose callback returns a fixed
      // nonzero value should report that value on the FIRST scrape, no
      // warm-up call required.
      final gauge = meter.createObservableGauge<int>(
        name: 'fresh',
        callback: (APIObservableResult<int> r) => r.observe(42),
      ) as ObservableGauge<int>;

      final metrics = gauge.collectMetrics();
      expect(metrics, isNotEmpty,
          reason: 'collectMetrics on a freshly-registered observable '
              'gauge must return data, not an empty list');
      expect(metrics.single.points.single.value, equals(42));
    });
  });
}
