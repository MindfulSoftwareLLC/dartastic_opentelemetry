// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('TraceContextExtension', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize();
    });

    group('spanContext', () {
      test('gets span context from context', () {
        final spanContext = OTel.spanContext(
          traceId: OTel.traceIdFrom('a' * 32),
          spanId: OTel.spanIdFrom('b' * 16),
          traceFlags: OTel.traceFlags(1),
          traceState: OTel.traceState({}),
          isRemote: false,
        );

        final context =OTel.context()
            .withSpanContext(spanContext);

        expect(context.spanContext, equals(spanContext));
      });

      test('returns null when no span context present', () {
        final context =OTel.context();
        expect(context.spanContext, isNull);
      });
    });

    group('withSpanContext', () {
      test('creates new context with span context', () {
        final spanContext = OTel.spanContext(
          traceId: OTel.traceIdFrom('a' * 32),
          spanId: OTel.spanIdFrom('b' * 16),
          traceFlags: OTel.traceFlags(1),
          traceState: OTel.traceState({}),
          isRemote: false,
        );

        final context =OTel.context();
        final newContext = context.withSpanContext(spanContext);

        expect(newContext.spanContext, equals(spanContext));
        expect(context.spanContext, isNull);
      });
    });

    group('Context serialization', () {
      test('serializes empty context correctly', () {
        final context = OTel.context();
        final serialized = context.serialize();
        final deserialized = Context.deserialize(serialized);
        expect(deserialized.spanContext, isNull);
      });

      group('span context serialization', () {
        test('serializes span context fields correctly', () {
          final spanContext = OTel.spanContext(
            traceId: OTel.traceIdFrom(('a' * 32)),
            spanId: OTel.spanIdFrom('b' * 16),
            traceFlags: OTel.traceFlags(1),
            traceState: OTel.traceState({'key': 'value'}),
            isRemote: false,
          );

          final context = OTel.context()
              .withSpanContext(spanContext);

          final serialized = context.serialize();

          // Verify the structure of serialized data
          expect(serialized['spanContext'], isA<Map<String, dynamic>>());
          final serializedSpanContext = serialized['spanContext'] as Map<String, dynamic>;
          expect(serializedSpanContext['traceId'], equals(spanContext.traceId.hexString));
          expect(serializedSpanContext['spanId'], equals(spanContext.spanId.hexString));
          expect(serializedSpanContext['traceFlags'], equals(spanContext.traceFlags.asByte));
          expect(serializedSpanContext['isRemote'], equals(spanContext.isRemote));
          expect(serializedSpanContext['traceState'], equals({'key': 'value'}));
        });

        test('serializes and deserializes span context correctly', () {
          final originalSpanContext = OTel.spanContext(
            traceId: OTel.traceIdFrom('a' * 32),
            spanId: OTel.spanIdFrom('b' * 16),
            traceFlags: OTel.traceFlags(1),
            traceState: OTel.traceState({'key': 'value'}),
            isRemote: false,
          );

          final originalContext = OTel.context()
              .withSpanContext(originalSpanContext);

          final serializedData = originalContext.serialize();
          final reconstructedContext = Context.deserialize(serializedData);

          expect(reconstructedContext.spanContext, equals(originalSpanContext));
        });

        test('deserializes empty map to empty context', () {
          final context = Context.deserialize({});
          expect(context.spanContext, isNull);
        });

        test('handles missing span context gracefully', () {
          final serializedData = {'someOtherKey': 'someValue'};
          final context = Context.deserialize(serializedData);
          expect(context.spanContext, isNull);
        });
      });
    });
  });
}
