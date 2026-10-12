// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Failure and edge paths the SDK is documented to absorb rather than
/// propagate: a metric export that hangs or throws inside the periodic
/// reader, baggage metadata that is not valid percent-encoding, a
/// zero-probability sampler, and the always-on exemplar filter.
library;

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

class _MapGetter implements TextMapGetter<String> {
  final Map<String, String> _map;

  _MapGetter(this._map);

  @override
  String? get(String key) => _map[key];

  @override
  Iterable<String> keys() => _map.keys;
}

/// An exporter whose `export` never completes; flush and shutdown succeed.
class _HangingExporter implements MetricExporter {
  int exportCalls = 0;

  @override
  Future<bool> export(MetricData data) {
    exportCalls++;
    return Completer<bool>().future;
  }

  @override
  Future<bool> forceFlush() async => true;

  @override
  Future<bool> shutdown() async => true;
}

/// An exporter whose `export` throws; flush and shutdown succeed.
class _ExportThrowsExporter implements MetricExporter {
  @override
  Future<bool> export(MetricData data) async =>
      throw StateError('export failed');

  @override
  Future<bool> forceFlush() async => true;

  @override
  Future<bool> shutdown() async => true;
}

void main() {
  group('PeriodicExportingMetricReader absorbs exporter failures', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'reader-failure-paths',
        detectPlatformResources: false,
      );
      // Record something so collect() yields a non-empty batch and the
      // reader actually calls export.
      OTel.meter('m').createCounter<int>(name: 'requests').add(1);
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('an export that never completes is abandoned after the timeout',
        () async {
      final exporter = _HangingExporter();
      final reader = PeriodicExportingMetricReader(
        exporter,
        interval: const Duration(hours: 1),
        timeout: const Duration(milliseconds: 20),
      );
      OTel.meterProvider().addMetricReader(reader);

      await expectLater(
        reader.forceFlush().timeout(const Duration(seconds: 5)),
        completion(isTrue),
        reason: 'forceFlush must return once the export timeout elapses',
      );
      expect(exporter.exportCalls, 1);
    });

    test('an export that throws does not fail forceFlush or shutdown',
        () async {
      final reader = PeriodicExportingMetricReader(
        _ExportThrowsExporter(),
        interval: const Duration(hours: 1),
      );
      OTel.meterProvider().addMetricReader(reader);

      expect(await reader.forceFlush(), isTrue);
      expect(await reader.shutdown(), isTrue);
    });
  });

  group('W3CBaggagePropagator', () {
    late W3CBaggagePropagator propagator;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'baggage-edge-paths',
        detectPlatformResources: false,
      );
      propagator = W3CBaggagePropagator();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('fields() names only the baggage header', () {
      expect(propagator.fields(), ['baggage']);
    });

    // Metadata is auxiliary: W3C says an unparsable list member is skipped,
    // but metadata that merely fails percent-decoding must not cost the
    // entry its value, so it is kept verbatim.
    for (final entry in {
      'truncated escape': 'prop=%E0%A4%A',
      'non-hex escape': 'prop=%ZZ',
      'invalid UTF-8': 'prop=%FF',
    }.entries) {
      test('metadata with ${entry.key} is kept raw, value survives', () {
        final carrier = {'baggage': 'key=value;${entry.value}'};

        final extracted =
            propagator.extract(OTel.context(), carrier, _MapGetter(carrier));

        final baggageEntry = extracted.baggage?.getEntry('key');
        expect(baggageEntry, isNotNull);
        expect(baggageEntry!.value, 'value');
        expect(baggageEntry.metadata, entry.value);
      });
    }
  });

  group('sampling and exemplar short circuits', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'sampler-edge-paths',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('ProbabilitySampler(0) drops every span without drawing', () {
      final sampler = ProbabilitySampler(0.0);

      for (var i = 0; i < 20; i++) {
        final result = sampler.shouldSample(
          parentContext: OTel.context(),
          traceId: 'trace$i',
          name: 'op',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );
        expect(result.decision, SamplingDecision.drop);
        expect(result.source, SamplingDecisionSource.tracerConfig);
      }
    });

    test('AlwaysOnExemplarFilter samples every measurement', () {
      const filter = AlwaysOnExemplarFilter();

      expect(
        filter.shouldSample(42, OTel.attributesFromMap({}), OTel.context()),
        isTrue,
      );
      expect(
        filter.shouldSample(
            -1.5, OTel.attributesFromMap({'k': 'v'}), OTel.context()),
        isTrue,
      );
    });
  });
}
