// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

@TestOn('browser')
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// Web compile + runtime smoke test.
///
/// Validates that the SDK can be:
///   1. Imported via the main entry point on the browser target
///   2. Initialized with `detectPlatformResources: false` (the default
///      ProcessResourceDetector / HostResourceDetector touch `Platform.*`
///      which throws `UnsupportedError` on web — disabling platform
///      resource detection avoids that path).
///   3. Used to construct an SDK Tracer and start/end a span.
///   4. Used to construct each OTLP/HTTP exporter — which now use the
///      platform-conditional `http_client_factory` to get a
///      `BrowserClient` on web instead of `IOClient` + `HttpClient`.
///
/// If `dart:io` accidentally creeps back into any code path reached
/// from this test, the test compile will start emitting runtime
/// `UnsupportedError`s — the assertion catches that.
void main() {
  group('Web compile + runtime smoke', () {
    setUp(OTel.reset);
    tearDown(OTel.reset);

    test('SDK initializes and creates a tracer on web', () async {
      await OTel.initialize(
        serviceName: 'web-smoke',
        detectPlatformResources: false,
      );

      final tracer = OTel.tracer();
      final span = tracer.startSpan('web-test-span');
      span.end();

      expect(span.name, equals('web-test-span'));
    });

    test('OTLP HTTP exporters construct without dart:io', () {
      // Constructors hit the http_client_factory facade — on web that
      // resolves to `BrowserClient`. If the IO path leaked, this would
      // throw at runtime.
      final spanExporter = OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(endpoint: 'http://localhost:4318'),
      );
      final metricExporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: 'http://localhost:4318'),
      );
      final logExporter = OtlpHttpLogRecordExporter(
        OtlpHttpLogRecordExporterConfig(endpoint: 'http://localhost:4318'),
      );

      expect(spanExporter, isNotNull);
      expect(metricExporter, isNotNull);
      expect(logExporter, isNotNull);
    });

    test('PlatformResourceDetector picks the web detector', () async {
      // On web, PlatformResourceDetector.create() composes the env-var
      // detector + the WebResourceDetector. ProcessResourceDetector and
      // HostResourceDetector (which require dart:io) are NOT added, so
      // calling detect() must not throw UnsupportedError.
      await OTel.initialize(
        serviceName: 'web-smoke',
        detectPlatformResources: false,
      );

      final detector = PlatformResourceDetector.create();
      // Should not throw — the composite skips IO detectors on web and
      // catches per-detector errors anyway.
      final resource = await detector.detect();
      expect(resource, isNotNull);
    });
  });
}
