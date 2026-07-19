// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Regression test for the documented gap in `1.1.0-beta.1`'s fix for
/// issue #33. That release shut down the *default* `LoggerProvider` in
/// `OTel.shutdown()` so short-lived CLIs would exit cleanly, but
/// **named** `LoggerProvider`s created via `OTel.addLoggerProvider(name)`
/// were still leaked: the `BatchLogRecordProcessor`'s `Timer.periodic`
/// stayed alive on the named provider, parking the Dart isolate.
///
/// API `1.0.0-beta.4` adds `OTelAPI.loggerProviders()` (and the
/// underlying `OTelFactory.getLoggerProviders()`), so `OTel.shutdown()`
/// can now iterate named providers the same way it already does for
/// tracer / meter providers. This test pins that behavior.
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OTel.shutdown shuts down named LoggerProviders', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test(
      'OTel.shutdown shuts down both the default and named LoggerProviders',
      () async {
        await OTel.initialize(
          serviceName: 'named-logger-shutdown-test',
          detectPlatformResources: false,
          enableMetrics: false,
          // Avoid the default OTLP exporter creating background work.
          endpoint: 'http://127.0.0.1:1',
        );

        // Touch the default so it exists, then create two named ones.
        final defaultProvider = OTel.loggerProvider();
        final namedA = OTel.addLoggerProvider('named-a');
        final namedB = OTel.addLoggerProvider('named-b');

        expect(defaultProvider.isShutdown, isFalse);
        expect(namedA.isShutdown, isFalse);
        expect(namedB.isShutdown, isFalse);

        await OTel.shutdown();

        expect(
          defaultProvider.isShutdown,
          isTrue,
          reason: 'default LoggerProvider should be shut down (regression: '
              'this was the only one shut down before beta.4)',
        );
        expect(
          namedA.isShutdown,
          isTrue,
          reason: 'named LoggerProvider "named-a" should be shut down — '
              'this is the gap closed by API beta.4 + this fix',
        );
        expect(
          namedB.isShutdown,
          isTrue,
          reason: 'named LoggerProvider "named-b" should be shut down too',
        );
      },
    );

    test(
      'OTel.shutdown is safe when no LoggerProviders have been touched',
      () async {
        await OTel.initialize(
          serviceName: 'no-loggers-test',
          detectPlatformResources: false,
          enableMetrics: false,
          enableLogs: false,
          endpoint: 'http://127.0.0.1:1',
        );

        // No assertion beyond "doesn't throw" — defensive, since the
        // iteration must tolerate an empty provider list.
        await OTel.shutdown();
      },
    );
  });
}
