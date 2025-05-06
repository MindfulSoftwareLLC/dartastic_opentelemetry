// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('SpanContext', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize();
    });

    test('creates valid context', () {
      final context = OTel.spanContext();
      expect(context.isValid, isTrue);
      expect(context.isRemote, isFalse);
      expect(context.traceFlags, equals(OTel.traceFlags()));
      expect(context.traceState, isNull);
    });

    test('creates invalid context', () {
      final context = OTel.spanContextInvalid();
      expect(context.isValid, isFalse);
      expect(context.isRemote, isFalse);
    });

    test('creates from parent', () {
      final parent = OTel.spanContext();
      final child = OTel.spanContextFromParent(parent);

      expect(child.traceId, equals(parent.traceId));
      expect(child.spanId, isNot(equals(parent.spanId)));
      expect(child.traceFlags, equals(parent.traceFlags));
      expect(child.traceState, equals(parent.traceState));
      expect(child.isRemote, isFalse);
    });

    test('updates trace flags', () {
      final context = OTel.spanContext();
      final newFlags = OTel.traceFlags(TraceFlags.SAMPLED_FLAG);
      final updated = context.withTraceFlags(newFlags);

      expect(updated.traceFlags, equals(newFlags));
      expect(updated.traceId, equals(context.traceId));
      expect(updated.spanId, equals(context.spanId));
      expect(updated.traceState, equals(context.traceState));
    });

    test('updates trace state', () {
      final context = OTel.spanContext();
      final newState = OTel.traceState({'key': 'value'});
      final updated = context.withTraceState(newState);

      expect(updated.traceState, equals(newState));
      expect(updated.traceId, equals(context.traceId));
      expect(updated.spanId, equals(context.spanId));
      expect(updated.traceFlags, equals(context.traceFlags));
    });

    test('equals and hashCode', () {
      final traceId = OTel.traceId();
      final spanId = OTel.spanId();
      final flags = OTel.traceFlags(TraceFlags.SAMPLED_FLAG);
      final state = OTel.traceState({'key': 'value'});

      final context1 = OTel.spanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: flags,
        traceState: state,
      );

      final context2 = OTel.spanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: flags,
        traceState: state,
      );

      expect(context1, equals(context2));
      expect(context1.hashCode, equals(context2.hashCode));
    });
  });
}
