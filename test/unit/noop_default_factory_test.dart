// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Tests for the spec-aligned noop-default-factory behavior plus the
// late-binding proxy pattern that holds it together:
//   - `OTel.tracer()` / `OTel.tracerProvider()` and the meter / logger
//     equivalents return SDK-shaped noop providers before `OTel.initialize`
//     is called, instead of throwing a cast `TypeError`.
//   - `OTel.isInitialized` reports `false` pre-init, `true` post-init.
//   - A subsequent `OTel.initialize` legitimately upgrades the noop
//     factory to the real SDK factory (matches Java/JS/Python pattern).
//   - A second `OTel.initialize` still throws `StateError` (per user
//     preference; spec is silent).
//   - The returned providers/tracers are *late-binding proxies*: a
//     reference captured pre-init keeps working post-init (the proxy
//     re-resolves to the now-real SDK provider on every call). This
//     is what makes module-load capture patterns (Genkit-style)
//     correct even when libraries grab references before the user's
//     `main()` calls `OTel.initialize`.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    // Make sure each test starts from a clean slate. `reset` is the
    // only public way to "un-initialize" between tests.
    await OTel.reset();
  });

  tearDown(() async {
    await OTel.reset();
  });

  group('Pre-initialize noop behavior', () {
    test('OTel.isInitialized is false before initialize', () {
      expect(OTel.isInitialized, isFalse);
    });

    test('OTel.tracerProvider() returns an SDK TracerProvider pre-init',
        () {
      final tp = OTel.tracerProvider();
      expect(tp, isA<TracerProvider>(),
          reason: 'Pre-init must return an SDK-shaped TracerProvider, '
              'not throw a cast TypeError.');
    });

    test('OTel.tracer() returns an SDK Tracer pre-init that produces '
        'usable spans (noop semantics, no crashes)', () {
      final tracer = OTel.tracer();
      expect(tracer, isA<Tracer>());
      // Span creation and lifecycle must not throw even pre-init.
      final span = tracer.startSpan('pre-init-span');
      span.setStringAttribute<String>('key', 'value');
      span.end();
    });

    test('OTel.meterProvider() returns an SDK MeterProvider pre-init', () {
      final mp = OTel.meterProvider();
      expect(mp, isA<MeterProvider>());
    });

    test('OTel.loggerProvider() returns an SDK LoggerProvider pre-init',
        () {
      final lp = OTel.loggerProvider();
      expect(lp, isA<LoggerProvider>());
    });

    test('Repeated pre-init calls return the same cached noop provider',
        () {
      final a = OTel.tracerProvider();
      final b = OTel.tracerProvider();
      expect(identical(a, b), isTrue,
          reason: 'Noop SDK wrapper must be cached so identity comparisons '
              'remain stable across calls.');
    });
  });

  group('Upgrade from noop to SDK factory', () {
    test('OTel.initialize upgrades the noop factory and flips '
        'isInitialized to true', () async {
      // Touch the API pre-init so the noop default gets installed.
      OTel.tracer();
      expect(OTel.isInitialized, isFalse);

      await OTel.initialize(
        serviceName: 'noop-upgrade-test',
        endpoint: 'http://localhost:4318',
      );

      expect(OTel.isInitialized, isTrue);
    });

    test('A second OTel.initialize throws StateError (user preference; '
        'spec is silent)', () async {
      await OTel.initialize(
        serviceName: 'double-init-test',
        endpoint: 'http://localhost:4318',
      );

      expect(
        () => OTel.initialize(
          serviceName: 'second-call',
          endpoint: 'http://localhost:4318',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Late-binding proxy: a pre-init tracerProvider() reference is '
        'identical to the post-init one', () async {
      final tpBefore = OTel.tracerProvider();
      await OTel.initialize(
        serviceName: 'post-init-test',
        endpoint: 'http://localhost:4318',
      );
      final tpAfter = OTel.tracerProvider();
      expect(identical(tpBefore, tpAfter), isTrue,
          reason: 'Proxy identity must be stable across initialize so '
              'module-load captures keep working.');
    });

    test('Late-binding proxy: a pre-init Tracer reference produces a real '
        'SDK Span after initialize', () async {
      // Capture the Tracer *before* initialize, exactly like a library
      // that grabs the global tracer at module load.
      final capturedTracer = OTel.tracer();

      // Pre-init: span creation must not throw, but the produced span
      // is a noop (it's the spec-correct outcome — work that's already
      // happening can't retroactively become recorded).
      final preInitSpan = capturedTracer.startSpan('pre-init');
      preInitSpan.end();

      await OTel.initialize(
        serviceName: 'late-binding-test',
        endpoint: 'http://localhost:4318',
      );

      // Post-init: the SAME captured reference must now produce a real
      // SDK span — the proxy re-resolved its underlying tracer to the
      // SDK-backed one installed during initialize.
      final postInitSpan = capturedTracer.startSpan('post-init');
      expect(postInitSpan, isA<Span>(),
          reason: 'Span produced via a pre-init captured Tracer reference '
              'must be a real SDK Span after initialize.');
      postInitSpan.end();
    });
  });
}
