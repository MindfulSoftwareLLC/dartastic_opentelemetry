// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Tests for the pluggable TimeProvider abstraction added in 1.1.0-beta.2.
//
// Covers:
//   - SystemTimeProvider returns DateTime.now-style timestamps.
//   - TracerProvider defaults to SystemTimeProvider when none is supplied.
//   - OTel.initialize(timeProvider: ...) wires a custom TimeProvider through
//     to TracerProvider, and Tracer.startSpan / Span.end source their
//     timestamps from it.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// A test TimeProvider that returns a fixed instant. Lets us verify span
/// timestamps were sourced from the provider rather than `DateTime.now()`.
class _FrozenTimeProvider implements TimeProvider {
  _FrozenTimeProvider(this._frozen);

  final DateTime _frozen;
  int callCount = 0;

  @override
  DateTime nowDateTime() {
    callCount++;
    return _frozen;
  }
}

void main() {
  group('SystemTimeProvider', () {
    test('returns a DateTime within a few ms of DateTime.now()', () {
      const provider = SystemTimeProvider();
      final before = DateTime.now();
      final from = provider.nowDateTime();
      final after = DateTime.now();
      expect(
          from.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
      expect(from.isAfter(after.add(const Duration(seconds: 1))), isFalse);
    });
  });

  group('TracerProvider TimeProvider integration', () {
    tearDown(() async {
      await OTel.reset();
    });

    test('TracerProvider defaults to SystemTimeProvider when none supplied',
        () async {
      await OTel.initialize(
        serviceName: 'time-provider-default-test',
        endpoint: 'http://localhost:4318',
      );
      final tp = OTel.tracerProvider();
      expect(tp.timeProvider, isA<SystemTimeProvider>());
    });

    test('OTel.initialize(timeProvider: ...) wires the custom provider through',
        () async {
      final frozen = _FrozenTimeProvider(
        DateTime.utc(2026, 5, 10, 12, 0, 0),
      );
      await OTel.initialize(
        serviceName: 'time-provider-custom-test',
        endpoint: 'http://localhost:4318',
        timeProvider: frozen,
      );
      final tp = OTel.tracerProvider();
      expect(identical(tp.timeProvider, frozen), isTrue);
    });

    test(
        'Tracer.startSpan and Span.end source timestamps from the configured TimeProvider',
        () async {
      final frozen = _FrozenTimeProvider(
        DateTime.utc(2026, 5, 10, 12, 0, 0),
      );
      await OTel.initialize(
        serviceName: 'time-provider-span-test',
        endpoint: 'http://localhost:4318',
        timeProvider: frozen,
      );
      final tracer = OTel.tracer();
      final callsBeforeStart = frozen.callCount;
      final span = tracer.startSpan('frozen-span');
      expect(frozen.callCount, greaterThan(callsBeforeStart),
          reason: 'startSpan should consult the TimeProvider');
      expect(span.startTime, equals(frozen._frozen));

      final callsBeforeEnd = frozen.callCount;
      span.end();
      expect(frozen.callCount, greaterThan(callsBeforeEnd),
          reason: 'span.end() should consult the TimeProvider');
      expect(span.endTime, equals(frozen._frozen));
    });
  });
}
