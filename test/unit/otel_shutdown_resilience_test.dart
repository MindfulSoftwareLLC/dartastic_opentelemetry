// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// `OTel.shutdown()` must complete even when a provider's shutdown throws
/// (error-handling.md: the SDK MUST NOT throw at runtime), and providers
/// added after `initialize` inherit the configured time provider.
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

class _ThrowingReader extends MetricReader {
  bool shutdownCalled = false;

  @override
  Future<MetricData> collect() async => MetricData.empty();

  @override
  Future<bool> forceFlush() async => true;

  @override
  Future<bool> shutdown() async {
    shutdownCalled = true;
    throw StateError('reader shutdown failed');
  }
}

void main() {
  setUp(() async {
    await OTel.reset();
    OTelLog.enableDebugLogging();
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  test('shutdown completes when a metric reader throws on shutdown', () async {
    await OTel.initialize(
      serviceName: 'shutdown-resilience',
      detectPlatformResources: false,
      enableMetrics: true,
    );
    final reader = _ThrowingReader();
    OTel.meterProvider().addMetricReader(reader);

    await expectLater(OTel.shutdown(), completes);
    expect(reader.shutdownCalled, isTrue);
  });

  test(
      'a tracer provider added after initialize gets the configured time '
      'provider', () async {
    const timeProvider = SystemTimeProvider();
    await OTel.initialize(
      serviceName: 'time-provider-inheritance',
      detectPlatformResources: false,
      timeProvider: timeProvider,
    );

    final extra = OTel.addTracerProvider('extra');

    expect(extra.timeProvider, same(timeProvider));
    expect(OTel.tracerProvider().timeProvider, same(timeProvider));
  });
}
