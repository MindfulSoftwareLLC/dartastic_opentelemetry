// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/context/propagation/w3c_baggage_propagator.dart';
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

class TestTextMapGetter implements TextMapGetter<String> {
  final Map<String, String> _map;

  TestTextMapGetter(this._map);

  @override
  String? get(String key) => _map[key];

  @override
  Iterable<String> keys() {
    return _map.keys;
  }
}

class TestTextMapSetter implements TextMapSetter<String> {
  final Map<String, String> _map;

  TestTextMapSetter(this._map);

  @override
  void set(String key, String value) {
    _map[key] = value;
  }
}

void main() {
  group('W3CBaggagePropagator', () {
    late W3CBaggagePropagator propagator;
    late Context context;

    setUp(() async {
      await OTel.initialize();
      propagator = W3CBaggagePropagator();
      context = OTel.context();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('injects baggage to carrier', () {
      final entries = <String, BaggageEntry>{
        'key1': OTel.baggageEntry('value1'),
        'key2': OTel.baggageEntry('value2', 'metadata2'),
      };

      final baggage = OTel.baggage(entries);
      final contextWithBaggage = context.withBaggage(baggage);

      final carrier = <String, String>{};
      final setter = TestTextMapSetter(carrier);
      propagator.inject(contextWithBaggage, carrier, setter);

      expect(carrier['baggage'], 'key1=value1,key2=value2;metadata2');
    });

    test('extracts baggage from carrier', () {
      final carrier = {'baggage': 'key1=value1,key2=value2;metadata2'};
      final getter = TestTextMapGetter(carrier);

      final extractedContext = propagator.extract(context, carrier, getter);
      final extractedBaggage = extractedContext.baggage;

      expect(extractedBaggage, isNotNull);
      expect(extractedBaggage, isA<Baggage>());

      final baggage = extractedBaggage;
      final key1Entry = baggage!.getEntry('key1');
      final key2Entry = baggage.getEntry('key2');

      expect(key1Entry?.value, equals('value1'));
      expect(key1Entry?.metadata, isNull);
      expect(key2Entry?.value, equals('value2'));
      expect(key2Entry?.metadata, equals('metadata2'));
    });

    test('handles special characters correctly', () {
      final entries = <String, BaggageEntry>{
        'key with spaces': OTel.baggageEntry('value with spaces'),
        'key,with,commas': OTel.baggageEntry('value,with,commas'),
      };

      final baggage = OTel.baggage(entries);
      final contextWithBaggage = context.withBaggage(baggage);

      final carrier = <String, String>{};
      final setter = TestTextMapSetter(carrier);
      propagator.inject(contextWithBaggage, carrier, setter);

      final getter = TestTextMapGetter(carrier);
      final extractedContext = propagator.extract(context, carrier, getter);
      final extractedBaggage = extractedContext.baggage;

      expect(extractedBaggage!.getEntry('key with spaces')?.value,
          equals('value with spaces'));
      expect(extractedBaggage.getEntry('key,with,commas')?.value,
          equals('value,with,commas'));
    });

    test('handles empty baggage', () {
      final baggage = OTel.baggage();
      final contextWithBaggage = context.withBaggage(baggage);

      final carrier = <String, String>{};
      final setter = TestTextMapSetter(carrier);
      propagator.inject(contextWithBaggage, carrier, setter);

      expect(carrier['baggage'], isNull);
    });

    test('handles invalid baggage format', () {
      final carrier = {'baggage': 'invalid format'};
      final getter = TestTextMapGetter(carrier);

      final extractedContext = propagator.extract(context, carrier, getter);
      final extractedBaggage = extractedContext.baggage;

      expect(extractedBaggage, isA<Baggage>());
      expect(extractedBaggage!.getAllEntries(), isEmpty);
    });
  });
}
