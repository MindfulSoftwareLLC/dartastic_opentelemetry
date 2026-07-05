// Licensed under the Apache License, Version 2.0
// Copyright 2026, Michael Bushe, All rights reserved.

// Regression tests for #50: API-first usage must not wedge SDK initialization.
//
// The API package auto-installs its no-op OTelAPIFactory when API-only code
// runs before OTel.initialize() (per the OTel spec). Previously:
//   - OTel.initialize() then threw "can only be initialized once", and
//   - OTel.tracerProvider() pre-initialize crashed with an opaque
//     "APITracerProvider is not a subtype of TracerProvider" TypeError.
//
// Now initialize() replaces exactly the auto-installed no-op (and nothing
// else), and SDK accessors throw a clear initialize-first StateError.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../testing_utils/in_memory_span_exporter.dart';

void main() {
  group('API-first then SDK initialize (#50)', () {
    tearDown(() async {
      await OTel.reset();
    });

    test('initialize() replaces the auto-installed no-op API factory',
        () async {
      // API-only access auto-installs the no-op factory.
      final apiProvider = OTelAPI.tracerProvider('api-first');
      expect(apiProvider, isA<APITracerProvider>());
      expect(OTelFactory.otelFactory, isNotNull);
      expect(OTelFactory.otelFactory.runtimeType, OTelAPIFactory);

      // SDK initialize must succeed anyway and install the SDK factory.
      await OTel.initialize(
        serviceName: 'api-first-service',
        serviceVersion: '1.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );
      expect(OTelFactory.otelFactory, isA<OTelSDKFactory>());

      // SDK accessor returns the SDK type — the #50 cast site.
      final sdkProvider = OTel.tracerProvider();
      expect(sdkProvider, isA<TracerProvider>());
    });

    test('spans record for real after API-first initialize', () async {
      OTelAPI.tracerProvider('api-first');
      await OTel.initialize(
        serviceName: 'api-first-spans',
        serviceVersion: '1.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );
      final exporter = InMemorySpanExporter();
      OTel.tracerProvider().addSpanProcessor(SimpleSpanProcessor(exporter));

      final span = OTel.tracer().startSpan('recorded');
      span.end();
      await OTel.tracerProvider().forceFlush();

      expect(exporter.spans.map((s) => s.name), contains('recorded'));
    });

    test('initialize() still throws once the SDK factory is installed',
        () async {
      await OTel.initialize(
        serviceName: 'once-service',
        serviceVersion: '1.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );
      expect(
        () => OTel.initialize(
          serviceName: 'twice-service',
          serviceVersion: '1.0.0',
          detectPlatformResources: false,
          enableMetrics: false,
        ),
        throwsStateError,
      );
    });

    test('SDK accessors pre-initialize throw StateError, not TypeError', () {
      expect(OTel.tracerProvider, throwsStateError);
      expect(OTel.meterProvider, throwsStateError);
      expect(OTel.loggerProvider, throwsStateError);
    });

    test(
        'SDK accessors after API-only auto-install throw StateError, '
        'not the #50 cast TypeError', () {
      OTelAPI.tracerProvider('api-only');
      expect(OTel.tracerProvider, throwsStateError);
      expect(OTel.meterProvider, throwsStateError);
      expect(OTel.loggerProvider, throwsStateError);
    });
  });
}
