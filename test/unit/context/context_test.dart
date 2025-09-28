// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('Context', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize();
    });

    group('Basic context operations', () {
      test('creates empty context', () {
        final context = OTel.context();
        expect(context, isA<Context>());
        expect(context.span, isNull);
        expect(context.span?.spanContext, isNull);
        expect(context.baggage, isNull);
      });

      test('stores and retrieves values with typed keys', () {
        final key = OTel.contextKey<String>('test-key');
        final value = 'test-value';
        final context = OTel.context().copyWith(key, value);

        expect(context.get(key), equals(value));
      });

      test('maintains immutability when adding values', () {
        final key1 = OTel.contextKey<String>('key1');
        final key2 = OTel.contextKey<int>('key2');

        final context1 = OTel.context().copyWith(key1, 'value1');
        final context2 = context1.copyWith(key2, 42);

        expect(context1.get(key1), equals('value1'));
        expect(context1.get(key2), isNull);
        expect(context2.get(key1), equals('value1'));
        expect(context2.get(key2), equals(42));
      });
    });

    group('SpanContext handling', () {
      late SpanContext spanContext1;
      late SpanContext spanContext2;

      setUp(() {
        // Create first span context with trace ID 'aaaa...'
        spanContext1 = OTel.spanContext(
          traceId: OTel.traceIdFrom('a' * 32),
          spanId: OTel.spanIdFrom('b' * 16),
          traceFlags: OTel.traceFlags(1),
          traceState: OTel.traceState({}),
          isRemote: false,
        );

        // Create second span context with different trace ID 'cccc...'
        spanContext2 = OTel.spanContext(
          traceId: OTel.traceIdFrom('c' * 32),
          spanId: OTel.spanIdFrom('d' * 16),
          traceFlags: OTel.traceFlags(1),
          traceState: OTel.traceState({}),
          isRemote: false,
        );
      });

      test('prevents changing trace ID via withSpanContext', () {
        final context = OTel.context().withSpanContext(spanContext1);

        expect(() => context.withSpanContext(spanContext2), throwsArgumentError,
            reason: 'Should not allow changing trace ID via withSpanContext');
      });

      test('maintains context immutability when adding span contexts', () {
        // Create initial context with first span context
        final context1 = OTel.context().withSpanContext(spanContext1);

        // Create a new span context with same trace ID but different span ID
        final spanContext1b = OTel.spanContext(
          traceId: spanContext1.traceId, // Same trace ID as spanContext1
          spanId: OTel.spanIdFrom('e' * 16), // Different span ID
          traceFlags: OTel.traceFlags(1),
          traceState: OTel.traceState({}),
          isRemote: false,
        );

        // Create new context with the second span context
        final context2 = context1.withSpanContext(spanContext1b);

        // Verify original context is unchanged
        expect(context1.spanContext, equals(spanContext1),
            reason: 'Original context should be unchanged');

        // Verify new context has the new span context
        expect(context2.spanContext, equals(spanContext1b),
            reason: 'New context should have new span context');

        // Verify both contexts have same trace ID
        expect(context1.spanContext?.traceId,
            equals(context2.spanContext?.traceId),
            reason: 'Both contexts should have same trace ID');
      });
    });

    group('Baggage handling', () {
      test('stores and retrieves baggage', () {
        final baggage = OTel.baggage({
          'key1': OTel.baggageEntry('value1'),
          'key2': OTel.baggageEntry('value2'),
        });

        final context = OTel.context(baggage: baggage);

        print('Context operations debug:');
        print('Original baggage: ${baggage.getAllEntries()}');
        print('Using BaggageContextKey directly: ${context.baggage}');
        print('Using baggage getter: ${context.baggage!.getAllEntries()}');

        expect(context.baggage, equals(baggage));

        final retrievedBaggage = context.baggage;
        expect(retrievedBaggage, isA<Baggage>());

        final entries = baggage.getAllEntries();
        entries.forEach((key, value) {
          final retrievedValue = retrievedBaggage!.getEntry(key);
          expect(retrievedValue, isNotNull,
              reason: 'Missing entry for key: $key');
          expect(retrievedValue?.value, equals(value.value),
              reason: 'Value mismatch for key: $key');
        });
      });

      test('maintains baggage immutability', () {
        final baggage1 = OTel.baggage({
          'key1': OTel.baggageEntry('value1'),
        });

        final baggage2 = OTel.baggage({
          'key2': OTel.baggageEntry('value2'),
        });

        final context1 = OTel.context(baggage: baggage1);

        final context2 = context1.withBaggage(baggage2);

        print('Immutability test debug:');
        print('Context1 baggage: ${context1.baggage!.getAllEntries()}');
        print('Context2 baggage: ${context2.baggage!.getAllEntries()}');
        print('Original baggage1: ${baggage1.getAllEntries()}');
        print('Original baggage2: ${baggage2.getAllEntries()}');

        final retrievedBaggage1 = context1.baggage;
        expect(retrievedBaggage1!.getEntry('key1')?.value, equals('value1'),
            reason: 'Context1 lost its baggage value');

        final retrievedBaggage2 = context2.baggage;
        expect(retrievedBaggage2!.getEntry('key2')?.value, equals('value2'),
            reason: 'Context2 lost its baggage value');
      });
    });

    group('Zone-based context propagation', () {
      test('propagates context through async operations', () async {
        final key = OTel.contextKey<String>('test-key');
        final value = 'test-value';
        final context = OTel.context().copyWith(key, value);

        final result = await context.run(() async {
          await Future<void>.delayed(Duration.zero);
          return Context.current;
        });

        expect(result, isA<Context>());
        expect(
          result.get(key),
          equals(value),
          reason: 'Context not propagated through async operation',
        );
      });

      test('maintains separate contexts in parallel async operations',
          () async {
        final key = OTel.contextKey<String>('key');
        final context1 = OTel.context().copyWith(key, 'value1');
        final context2 = OTel.context().copyWith(key, 'value2');

        final future1 = context1.run(() async {
          await Future<void>.delayed(Duration.zero);
          return Context.current;
        });

        final future2 = context2.run(() async {
          await Future<void>.delayed(Duration.zero);
          return Context.current;
        });

        final results = await Future.wait([future1, future2]);

        expect(results[0].get(key), equals('value1'),
            reason: 'Context1 value was lost or modified');
        expect(results[1].get(key), equals('value2'),
            reason: 'Context2 value was lost or modified');
      });
    });

    group('Context serialization', () {
      test('serializes and deserializes basic context values', () {
        final key = OTel.contextKey<String>('test-key');
        final value = 'test-value';
        final originalContext = OTel.context().copyWith(key, value);

        final serializedData = originalContext.serialize();
        final deserializedContext = Context.deserialize(serializedData);

        expect(deserializedContext.get(key), equals(value));
      });

      test('serializes and deserializes span context', () {
        final spanContext = OTel.spanContext(
          traceId: OTel.traceIdFrom('a' * 32),
          spanId: OTel.spanIdFrom('b' * 16),
          traceFlags: OTel.traceFlags(1),
          traceState: OTel.traceState({'key': 'value'}),
          isRemote: false,
        );

        final originalContext = OTel.context().withSpanContext(spanContext);
        final serializedData = originalContext.serialize();
        final deserializedContext = Context.deserialize(serializedData);

        final deserializedSpanContext = deserializedContext.spanContext;
        expect(deserializedSpanContext, isNotNull);
        expect(deserializedSpanContext?.traceId, equals(spanContext.traceId));
        expect(deserializedSpanContext?.spanId, equals(spanContext.spanId));
        expect(deserializedSpanContext?.traceFlags,
            equals(spanContext.traceFlags));
        expect(
          deserializedSpanContext?.traceState.toString(),
          equals(spanContext.traceState.toString()),
        );
        expect(deserializedSpanContext?.isRemote, equals(spanContext.isRemote));
      });

      test('serializes and deserializes baggage', () {
        final baggage = OTel.baggage({
          'key1': OTel.baggageEntry('value1', 'meta1'),
          'key2': OTel.baggageEntry('value2', 'meta2'),
        });

        final originalContext = OTel.context(baggage: baggage);

        final serializedData = originalContext.serialize();
        final deserializedContext = Context.deserialize(serializedData);

        final deserializedBaggage = deserializedContext.baggage;
        for (final entry in baggage.getAllEntries().entries) {
          final retrievedValue = deserializedBaggage!.getEntry(entry.key);
          expect(retrievedValue, isNotNull,
              reason:
                  'Missing baggage entry after deserialization: ${entry.key}');
          expect(retrievedValue?.value, equals(entry.value.value),
              reason:
                  'Wrong value after deserialization for key: ${entry.key}');
          expect(retrievedValue?.metadata, equals(entry.value.metadata),
              reason:
                  'Wrong metadata after deserialization for key: ${entry.key}');
        }
      });

      test('handles non-serializable values gracefully', () {
        final nonSerializable = Object();
        final key = OTel.contextKey<Object>('non-serializable');

        final context = OTel.context().copyWith(key, nonSerializable);
        final serializedData = context.serialize();
        final deserializedContext = Context.deserialize(serializedData);

        expect(deserializedContext.get(key), isNull);
      });

      test('serializes and deserializes multiple keys with the same name', () {
        // Create two keys with the same name but different uniqueIds
        final key1 = OTel.contextKey<String>('same-name');
        final key2 = OTel.contextKey<String>('same-name');

        // Verify they are different keys despite same name
        expect(key1 == key2, isFalse,
            reason:
                'Keys with same name should be different objects due to different uniqueIds');

        // Create context with both keys
        final originalContext =
            OTel.context().copyWith(key1, 'value1').copyWith(key2, 'value2');

        // Verify both values are accessible with their respective keys
        expect(originalContext.get(key1), equals('value1'));
        expect(originalContext.get(key2), equals('value2'));

        // Serialize and deserialize
        final serializedData = originalContext.serialize();
        final deserializedContext = Context.deserialize(serializedData);

        // Verify both values are still accessible
        expect(deserializedContext.get(key1), equals('value1'));
        expect(deserializedContext.get(key2), equals('value2'));
      });
    });

    group('Isolate context propagation', () {
      test('propagates context to new isolate', () async {
        final key = OTel.contextKey<String>('test-key');
        final baggage = OTel.baggage({
          'baggage-key': OTel.baggageEntry('baggage-value'),
        });

        final originalContext =
            OTel.context(baggage: baggage).copyWith(key, 'test-value');

        await originalContext.run(() async {
          final result = await originalContext.runIsolate(() async {
            final isolateContext = Context.current;
            return {
              'test-key': isolateContext.get(key),
              'baggage-value':
                  isolateContext.baggage!.getEntry('baggage-key')?.value,
            };
          });

          expect(result['test-key'], equals('test-value'),
              reason: 'Context key not propagated to isolate');
          expect(result['baggage-value'], equals('baggage-value'),
              reason: 'Baggage not propagated to isolate');
        });
      });

      test('maintains isolation between different isolates', () async {
        final key = OTel.contextKey<String>('key');
        final context1 = OTel.context().copyWith(key, 'value1');
        final context2 = OTel.context().copyWith(key, 'value2');

        final future1 = context1.run(() async {
          return await context1.runIsolate(() async {
            return Context.current.get(key);
          });
        });

        final future2 = context2.run(() async {
          return await context2.runIsolate(() async {
            return Context.current.get(key);
          });
        });

        final results = await Future.wait([future1, future2]);
        expect(results[0], equals('value1'));
        expect(results[1], equals('value2'));
      });
    });
  });
}
