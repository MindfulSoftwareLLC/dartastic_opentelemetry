// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/src/context/propagation/w3c_baggage_propagator.dart';
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/trace/w3c_trace_context_propagator.dart';
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
      // Keys with spaces or commas are invalid tokens per RFC 7230 and
      // must be dropped on inject.  Values with those characters are
      // percent-encoded and must round-trip correctly.
      final entries = <String, BaggageEntry>{
        'valid-key': OTel.baggageEntry('value with spaces'),
        'also-valid': OTel.baggageEntry('value,with,commas'),
        'key with spaces': OTel.baggageEntry('should be dropped'),
      };

      final baggage = OTel.baggage(entries);
      final contextWithBaggage = context.withBaggage(baggage);

      final carrier = <String, String>{};
      final setter = TestTextMapSetter(carrier);
      propagator.inject(contextWithBaggage, carrier, setter);

      // The invalid key must not appear in the header.
      expect(carrier['baggage'], isNot(contains('key with spaces')));

      final getter = TestTextMapGetter(carrier);
      final extractedContext = propagator.extract(context, carrier, getter);
      final extractedBaggage = extractedContext.baggage;

      expect(
        extractedBaggage!.getEntry('valid-key')?.value,
        equals('value with spaces'),
      );
      expect(
        extractedBaggage.getEntry('also-valid')?.value,
        equals('value,with,commas'),
      );
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
      // Propagators API spec: when no entry survives parsing the
      // implementation MUST NOT store a new value — return original context.
      final carrier = {'baggage': 'invalid format'};
      final getter = TestTextMapGetter(carrier);

      final extractedContext = propagator.extract(context, carrier, getter);

      expect(extractedContext, same(context),
          reason: 'unparseable header must not overwrite existing context');
    });

    test('preserves existing baggage when header is unparseable (#200)',
        () async {
      // Set up a context that already carries valid baggage.
      final existingBaggage =
          OTel.baggage({'existing': OTel.baggageEntry('keep-me')});
      final incoming = context.withBaggage(existingBaggage);

      // An unparseable header that will produce zero valid entries.
      final carrier = {'baggage': '=x'};
      final getter = TestTextMapGetter(carrier);

      final extracted = propagator.extract(incoming, carrier, getter);
      final extractedBaggage = extracted.baggage;

      expect(extractedBaggage, isNotNull);
      expect(extractedBaggage!.getEntry('existing')?.value, 'keep-me',
          reason: 'existing baggage must survive an unparseable header');
    });

    test('preserves existing baggage when all entries are invalid (#200)', () {
      final existingBaggage =
          OTel.baggage({'existing': OTel.baggageEntry('keep-me')});
      final incoming = context.withBaggage(existingBaggage);

      final carrier = {'baggage': 'garbage,,=x,=y'};
      final getter = TestTextMapGetter(carrier);

      final extracted = propagator.extract(incoming, carrier, getter);
      final extractedBaggage = extracted.baggage;

      expect(extractedBaggage, isNotNull);
      expect(extractedBaggage!.getEntry('existing')?.value, 'keep-me',
          reason: 'existing baggage must survive when all entries are invalid');
    });

    test('value containing equals sign is preserved (#199)', () {
      final carrier = {'baggage': 'query=a=b'};
      final getter = TestTextMapGetter(carrier);

      final extracted = propagator.extract(context, carrier, getter);
      final entry = extracted.baggage!.getEntry('query');

      expect(entry, isNotNull);
      expect(entry!.value, 'a=b');
    });

    test('base64-padded value with trailing equals is preserved (#199)', () {
      final carrier = {'baggage': 'token=abc123=='};
      final getter = TestTextMapGetter(carrier);

      final extracted = propagator.extract(context, carrier, getter);
      final entry = extracted.baggage!.getEntry('token');

      expect(entry, isNotNull);
      expect(entry!.value, 'abc123==');
    });

    test('multiple equals in value are all preserved (#199)', () {
      final carrier = {'baggage': 'data=a=b=c&key=1'};
      final getter = TestTextMapGetter(carrier);

      final extracted = propagator.extract(context, carrier, getter);
      final entry = extracted.baggage!.getEntry('data');

      expect(entry, isNotNull);
      expect(entry!.value, 'a=b=c&key=1');
    });

    test('equals in value with metadata is preserved (#199)', () {
      final carrier = {'baggage': 'token=abc=def;prop=foo'};
      final getter = TestTextMapGetter(carrier);

      final extracted = propagator.extract(context, carrier, getter);
      final entry = extracted.baggage!.getEntry('token');

      expect(entry, isNotNull);
      expect(entry!.value, 'abc=def');
      expect(entry.metadata, 'prop=foo');
    });

    // Per-character-class inject/extract contracts (plus, space, semicolon,
    // comma, quote) live in the table-driven
    // w3c_baggage_octet_contract_test.dart, per review.

    test('invalid token keys are dropped on inject', () {
      final entries = <String, BaggageEntry>{
        'valid': OTel.baggageEntry('ok'),
        'has space': OTel.baggageEntry('dropped'),
        'has,comma': OTel.baggageEntry('dropped'),
        'has=equals': OTel.baggageEntry('dropped'),
      };

      final baggage = OTel.baggage(entries);
      final contextWithBaggage = context.withBaggage(baggage);

      final carrier = <String, String>{};
      final setter = TestTextMapSetter(carrier);
      propagator.inject(contextWithBaggage, carrier, setter);

      expect(carrier['baggage'], 'valid=ok');
    });

    test(
        'extract without a baggage header returns the passed context'
        ' unchanged', () {
      // Propagators API spec: extract returns the passed context, updated
      // with extracted values — unchanged when there is nothing to extract.
      final sc = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
      );
      final incoming = OTel.context().withSpanContext(sc);
      final getter = TestTextMapGetter(<String, String>{});

      final extracted = propagator.extract(incoming, {}, getter);

      expect(extracted, same(incoming),
          reason: 'nothing to extract must not replace the context');
      expect(extracted.spanContext, equals(sc),
          reason: 'earlier propagators\' extractions must survive');
    });

    test(
        'composite tracecontext-then-baggage extraction preserves the'
        ' span context when no baggage header is present', () {
      // Regression for #87: the spec-default composite order runs
      // tracecontext first; the baggage stage used to discard its result.
      final composite =
          OTelAPI.compositePropagator<Map<String, String>, String>([
        W3CTraceContextPropagator(),
        W3CBaggagePropagator(),
      ]);
      const traceId = '0af7651916cd43dd8448eb211c80319c';
      final carrier = {
        'traceparent': '00-$traceId-b7ad6b7169203331-01',
      };

      final extracted = composite.extract(
          OTel.context(), carrier, TestTextMapGetter(carrier));

      expect(extracted.spanContext, isNotNull);
      expect(extracted.spanContext!.traceId.hexString, equals(traceId));
    });
  });
}
