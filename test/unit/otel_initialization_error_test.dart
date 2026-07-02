// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Regression coverage for the factory-upgrade lifecycle (issue #50).
//
// The API auto-installs a spec-mandated no-op factory the first time any API
// call runs. When that happens before OTel.initialize(), initialize() must
// replace that no-op factory with a real SDK factory rather than refuse to run.
// SDK accessors still require explicit initialization, so they do not hand out
// unconfigured providers before initialize() has applied resources, processors,
// exporters, samplers, and endpoint configuration.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    as api;
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await OTel.reset();
  });

  group('SDK accessors preserve the initialize-first lifecycle', () {
    final throwsInitializeFirst = throwsA(isA<StateError>().having(
      (e) => e.message,
      'message',
      contains('OTel.initialize() must be called first'),
    ));

    test('tracerProvider() throws if no factory exists', () {
      expect(OTel.tracerProvider, throwsInitializeFirst);
      expect(OTelFactory.otelFactory, isNull);
      expect(OTel.isInitialized, isFalse);
    });

    test('SDK tracerProvider() throws clearly after API auto-install', () {
      // API accessor: allowed before SDK initialization; installs the API
      // package's no-op factory.
      final apiProvider = api.OTelAPI.tracerProvider();
      expect(apiProvider, isA<api.APITracerProvider>());
      expect(OTelFactory.otelFactory, isA<api.OTelAPIFactory>());
      expect(OTelFactory.otelFactory, isNot(isA<OTelSDKFactory>()));

      // SDK accessor: still requires OTel.initialize(); should not cast-crash
      // or install an unconfigured temporary SDK provider.
      expect(OTel.tracerProvider, throwsInitializeFirst);
      expect(OTel.isInitialized, isFalse);
      expect(OTelFactory.otelFactory, isA<api.OTelAPIFactory>());
    });

    test('SDK meterProvider() throws clearly after API auto-install', () {
      // API accessor: allowed before SDK initialization; installs the API
      // package's no-op factory.
      api.OTelAPI.meterProvider();
      expect(OTelFactory.otelFactory, isNot(isA<OTelSDKFactory>()));

      // SDK accessor: still requires OTel.initialize(); should not cast-crash
      // or install an unconfigured temporary SDK provider.
      expect(OTel.meterProvider, throwsInitializeFirst);
      expect(OTelFactory.otelFactory, isA<api.OTelAPIFactory>());
    });

    test('SDK loggerProvider() throws clearly after API auto-install', () {
      // API accessor: allowed before SDK initialization; installs the API
      // package's no-op factory.
      api.OTelAPI.loggerProvider();
      expect(OTelFactory.otelFactory, isNot(isA<OTelSDKFactory>()));

      // SDK accessor: still requires OTel.initialize(); should not cast-crash
      // or install an unconfigured temporary SDK provider.
      expect(OTel.loggerProvider, throwsInitializeFirst);
      expect(OTelFactory.otelFactory, isA<api.OTelAPIFactory>());
    });

    test('SDK addTracerProvider() throws clearly after API auto-install', () {
      // API accessor: allowed before SDK initialization; installs the API
      // package's no-op factory.
      api.OTelAPI.tracerProvider();

      // SDK accessor: still requires OTel.initialize(); should not cast-crash
      // or install an unconfigured temporary SDK provider.
      expect(() => OTel.addTracerProvider('named'), throwsInitializeFirst);
      expect(OTelFactory.otelFactory, isA<api.OTelAPIFactory>());
    });
  });

  group('initialize() upgrades an already-installed API no-op factory', () {
    test('initialize() succeeds after API tracerProvider()', () async {
      api.OTelAPI.tracerProvider();
      await OTel.initialize(serviceName: 'svc-a');
      expect(OTel.isInitialized, isTrue);
      expect(OTelFactory.otelFactory, isA<OTelSDKFactory>());
      expect(OTel.tracerProvider(), isA<TracerProvider>());
    });

    test('initialize() succeeds after API meterProvider()', () async {
      api.OTelAPI.meterProvider();
      await OTel.initialize(serviceName: 'svc-b');
      expect(OTel.isInitialized, isTrue);
      expect(OTel.meterProvider(), isA<MeterProvider>());
    });

    test('initialize() succeeds after API loggerProvider()', () async {
      api.OTelAPI.loggerProvider();
      await OTel.initialize(serviceName: 'svc-c');
      expect(OTel.isInitialized, isTrue);
      expect(OTel.loggerProvider(), isA<LoggerProvider>());
    });

    test('initialize() applies configured resource after replacing API no-op',
        () async {
      api.OTelAPI.tracerProvider();

      await OTel.initialize(serviceName: 'configured-service');

      final hasServiceName = OTel.defaultResource!.attributes.toList().any(
            (a) => a.key == 'service.name' && a.value == 'configured-service',
          );
      expect(hasServiceName, isTrue);
      expect(OTel.isInitialized, isTrue);
      expect(OTel.tracerProvider(), isA<TracerProvider>());
    });
  });

  group('re-initialization is keyed on an explicit initialize() call', () {
    test('calling initialize() twice throws a clear StateError', () async {
      await OTel.initialize(serviceName: 'first');
      await expectLater(
        OTel.initialize(serviceName: 'second'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('can only be called once'),
        )),
      );
    });

    test('initialize() works again after reset()', () async {
      await OTel.initialize(serviceName: 'first');
      expect(OTel.isInitialized, isTrue);
      await OTel.reset();
      expect(OTel.isInitialized, isFalse);
      await OTel.initialize(serviceName: 'second');
      expect(OTel.isInitialized, isTrue);
    });
  });
}
