// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// PeriodicExportingMetricReader configuration accessors and the failure
// paths around forceFlush and shutdown, which were uncovered.
//
// The reader is documented as swallowing exporter failures and reporting a
// boolean rather than propagating, so these pin that contract: an exporter
// that throws must not take the caller down with it.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// An exporter whose every operation throws.
class _ThrowingExporter implements MetricExporter {
  @override
  Future<bool> export(MetricData data) async =>
      throw StateError('export failed');

  @override
  Future<bool> forceFlush() async => throw StateError('forceFlush failed');

  @override
  Future<bool> shutdown() async => throw StateError('shutdown failed');
}

/// An exporter that records calls and succeeds.
class _RecordingExporter implements MetricExporter {
  int exports = 0;
  int flushes = 0;
  int shutdowns = 0;

  @override
  Future<bool> export(MetricData data) async {
    exports++;
    return true;
  }

  @override
  Future<bool> forceFlush() async {
    flushes++;
    return true;
  }

  @override
  Future<bool> shutdown() async {
    shutdowns++;
    return true;
  }
}

void main() {
  setUp(() async {
    await OTel.reset();
    EnvironmentService.testOverrides = {'OTEL_TRACES_EXPORTER': 'none'};
    await OTel.initialize(
      serviceName: 'periodic-reader-test',
      detectPlatformResources: false,
      enableLogs: false,
      enableMetrics: false,
    );
  });

  tearDown(() async {
    try {
      await OTel.shutdown();
    } catch (_) {}
    await OTel.reset();
    EnvironmentService.testOverrides = null;
  });

  group('PeriodicExportingMetricReader configuration', () {
    test('interval and timeout expose the configured values', () async {
      final reader = PeriodicExportingMetricReader(
        _RecordingExporter(),
        interval: const Duration(seconds: 7),
        timeout: const Duration(seconds: 3),
      );
      addTearDown(reader.shutdown);

      expect(reader.interval, equals(const Duration(seconds: 7)));
      expect(reader.timeout, equals(const Duration(seconds: 3)));
    });

    test('interval and timeout fall back to the spec defaults', () async {
      final reader = PeriodicExportingMetricReader(_RecordingExporter());
      addTearDown(reader.shutdown);

      expect(reader.interval, equals(const Duration(seconds: 60)));
      expect(reader.timeout, equals(const Duration(seconds: 30)));
    });
  });

  group('PeriodicExportingMetricReader failure handling', () {
    test('forceFlush reports false instead of propagating an exporter throw',
        () async {
      final reader = PeriodicExportingMetricReader(
        _ThrowingExporter(),
        interval: const Duration(hours: 1),
      );
      addTearDown(() async {
        try {
          await reader.shutdown();
        } catch (_) {}
      });

      expect(await reader.forceFlush(), isFalse);
    });

    test('shutdown reports false instead of propagating an exporter throw',
        () async {
      final reader = PeriodicExportingMetricReader(
        _ThrowingExporter(),
        interval: const Duration(hours: 1),
      );

      expect(await reader.shutdown(), isFalse);
    });

    test('forceFlush and shutdown reach the exporter when it succeeds',
        () async {
      final exporter = _RecordingExporter();
      final reader = PeriodicExportingMetricReader(
        exporter,
        interval: const Duration(hours: 1),
      );

      expect(await reader.forceFlush(), isTrue);
      expect(exporter.flushes, equals(1));

      expect(await reader.shutdown(), isTrue);
      expect(exporter.shutdowns, equals(1));
    });
  });
}
