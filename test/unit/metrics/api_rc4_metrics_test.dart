// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//
// Covers the SDK side of API 1.0.0-rc.4's metrics changes (API #113):
// InstrumentAdvisory on every instrument, histogram buckets taken from the
// advisory, the `callbacks` list on observable instruments, and
// Meter.registerBatchCallback with its registration handle.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('API rc.4 metrics', () {
    late MeterProvider meterProvider;
    late Meter meter;
    final reported = <Object>[];

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        endpoint: 'http://localhost:4317',
        detectPlatformResources: false,
      );
      meterProvider = OTel.meterProvider();
      meter = meterProvider.getMeter(name: 'test-meter') as Meter;
      reported.clear();
      OTelErrorHandling.handler = (error, stackTrace) => reported.add(error);
    });

    tearDown(() async {
      OTelErrorHandling.resetToDefault();
      await meterProvider.shutdown();
      await OTel.reset();
    });

    test('every instrument exposes the advisory it was created with', () {
      const advisory = InstrumentAdvisory(attributeKeys: ['k']);
      expect(
        meter.createCounter<int>(name: 'c', advisory: advisory).advisory,
        same(advisory),
      );
      expect(
        meter.createUpDownCounter<int>(name: 'u', advisory: advisory).advisory,
        same(advisory),
      );
      expect(
        meter.createGauge<int>(name: 'g', advisory: advisory).advisory,
        same(advisory),
      );
      expect(
        meter.createHistogram<int>(name: 'h', advisory: advisory).advisory,
        same(advisory),
      );
      expect(
        meter
            .createObservableCounter<int>(name: 'oc', advisory: advisory)
            .advisory,
        same(advisory),
      );
      expect(
        meter
            .createObservableUpDownCounter<int>(name: 'ou', advisory: advisory)
            .advisory,
        same(advisory),
      );
      expect(
        meter
            .createObservableGauge<int>(name: 'og', advisory: advisory)
            .advisory,
        same(advisory),
      );
      expect(meter.createCounter<int>(name: 'c2').advisory, isNull);
    });

    test('histogram buckets come from advisory.explicitBucketBoundaries', () {
      final histogram = meter.createHistogram<double>(
        name: 'h',
        advisory: const InstrumentAdvisory(
          explicitBucketBoundaries: [10.0, 20.0],
        ),
      ) as Histogram<double>;

      histogram.record(5.0);
      histogram.record(15.0);
      histogram.record(25.0);

      final value = histogram.getValue();
      expect(value.boundaries, equals([10.0, 20.0]));
      expect(value.bucketCounts, equals([1, 1, 1]));
    });

    test('deprecated boundaries parameter wins over the advisory', () {
      final histogram = meter.createHistogram<double>(
        name: 'h',
        boundaries: [50.0],
        advisory: const InstrumentAdvisory(
          explicitBucketBoundaries: [10.0, 20.0],
          attributeKeys: ['k'],
        ),
      ) as Histogram<double>;

      histogram.record(5.0);
      histogram.record(75.0);

      final value = histogram.getValue();
      expect(value.boundaries, equals([50.0]));
      expect(value.bucketCounts, equals([1, 1]));
      // The rest of the advisory survives the merge.
      expect(histogram.advisory?.attributeKeys, equals(['k']));
    });

    test('observable instruments take a callbacks list', () {
      final gauge = meter.createObservableGauge<int>(
        name: 'g',
        callbacks: [
          (r) => r.observe(1, {'n': 'a'}.toAttributes()),
          (r) => r.observe(2, {'n': 'b'}.toAttributes()),
        ],
      ) as ObservableGauge<int>;

      final points = gauge.collectMetrics().single.points;
      expect(points.map((p) => p.value), unorderedEquals([1, 2]));
    });

    test('registerBatchCallback observes several instruments per collection',
        () async {
      final counter =
          meter.createObservableCounter<int>(name: 'oc') as ObservableCounter;
      final gauge = meter.createObservableGauge<double>(name: 'og')
          as ObservableGauge<double>;
      final upDown = meter.createObservableUpDownCounter<int>(name: 'ou')
          as ObservableUpDownCounter;

      var fires = 0;
      meter.registerBatchCallback((result) {
        fires++;
        result.observe(counter, 10 * fires);
        result.observe(gauge, 1.5, {'host': 'a'}.toAttributes());
        result.observe(upDown, -3);
      }, {counter, gauge, upDown});

      var metrics = await meterProvider.collectAllMetrics();
      expect(fires, equals(1), reason: 'one collection, one batch fire');

      Metric byName(String name) => metrics.firstWhere((m) => m.name == name);
      expect(byName('oc').points.single.value, equals(10));
      expect(byName('og').points.single.value, equals(1.5));
      expect(
        byName('og').points.single.attributes.getString('host'),
        equals('a'),
      );
      expect(byName('ou').points.single.value, equals(-3));

      metrics = await meterProvider.collectAllMetrics();
      expect(fires, equals(2));
      expect(byName('oc').points.single.value, equals(20));
      expect(reported, isEmpty);
    });

    test('batch and single-instrument callbacks land in the same collection',
        () async {
      final gauge = meter.createObservableGauge<int>(
        name: 'g',
        callbacks: [
          (r) => r.observe(1, {'src': 'single'}.toAttributes())
        ],
      ) as ObservableGauge<int>;
      meter.registerBatchCallback(
        (result) => result.observe(gauge, 2, {'src': 'batch'}.toAttributes()),
        {gauge},
      );

      final metrics = await meterProvider.collectAllMetrics();
      final points = metrics.single.points;
      expect(points.map((p) => p.value), unorderedEquals([1, 2]));
    });

    test('unregister stops a batch callback', () async {
      final gauge =
          meter.createObservableGauge<int>(name: 'g') as ObservableGauge<int>;
      var fires = 0;
      final registration = meter.registerBatchCallback((result) {
        fires++;
        result.observe(gauge, fires);
      }, {gauge});

      await meterProvider.collectAllMetrics();
      expect(fires, equals(1));

      registration.unregister();
      await meterProvider.collectAllMetrics();
      expect(fires, equals(1), reason: 'unregistered callback must not fire');
    });

    test('an instrument from another meter is reported, not thrown', () async {
      final other = meterProvider.getMeter(name: 'other-meter') as Meter;
      final mine =
          meter.createObservableGauge<int>(name: 'mine') as ObservableGauge;
      final theirs =
          other.createObservableGauge<int>(name: 'theirs') as ObservableGauge;

      var fires = 0;
      final registration = meter.registerBatchCallback((result) {
        fires++;
      }, {mine, theirs});

      expect(reported, hasLength(1));
      expect(reported.single, isA<ArgumentError>());
      expect(
        reported.single.toString(),
        contains('theirs'),
      );

      await meterProvider.collectAllMetrics();
      expect(fires, equals(0), reason: 'rejected callback never runs');
      registration.unregister(); // no-op, must not throw
    });

    test('an observation for an unregistered instrument is dropped', () async {
      final registered =
          meter.createObservableGauge<int>(name: 'reg') as ObservableGauge;
      final stray =
          meter.createObservableGauge<int>(name: 'stray') as ObservableGauge;

      meter.registerBatchCallback((result) {
        result.observe(registered, 1);
        result.observe(stray, 2);
      }, {registered});

      final metrics = await meterProvider.collectAllMetrics();
      expect(metrics.map((m) => m.name), equals(['reg']));
      expect(reported, hasLength(1));
      expect(reported.single.toString(), contains('stray'));
    });

    test('a throwing batch callback is reported and others still run',
        () async {
      final gauge =
          meter.createObservableGauge<int>(name: 'g') as ObservableGauge;
      meter.registerBatchCallback((_) => throw StateError('boom'), {gauge});
      meter.registerBatchCallback((r) => r.observe(gauge, 7), {gauge});

      final metrics = await meterProvider.collectAllMetrics();
      expect(metrics.single.points.single.value, equals(7));
      expect(reported.single, isA<StateError>());
    });

    test('MeterProvider owns its configuration and state', () {
      expect(meterProvider.serviceName, equals('test-service'));
      expect(meterProvider.endpoint, equals('http://localhost:4317'));
      expect(meterProvider.enabled, isTrue);
      expect(meterProvider.isShutdown, isFalse);

      meterProvider.enabled = false;
      expect(meter.isEnabled(), isFalse);
      meterProvider.enabled = true;
      expect(meter.isEnabled(), isTrue);
    });

    test('NoopMeter accepts the new parameters and a batch callback', () {
      final noop = NoopMeter(name: 'noop');
      final gauge = noop.createObservableGauge<int>(
        name: 'g',
        advisory: const InstrumentAdvisory(attributeKeys: ['k']),
        callbacks: [(_) {}],
      );
      expect(gauge.advisory?.attributeKeys, equals(['k']));
      expect(gauge.callbacks, hasLength(1));

      final histogram = noop.createHistogram<int>(
        name: 'h',
        boundaries: [1.0],
      );
      expect(histogram.advisory?.explicitBucketBoundaries, equals([1.0]));

      noop.registerBatchCallback((_) {}, {gauge}).unregister();
      expect(reported, isEmpty);
    });
  });
}
