// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Pins the invariant that makes splitting the baggage header on ',' (and
// ';') spec-correct: the W3C Baggage grammar's baggage-octet set
// (%x21 / %x23-2B / %x2D-3A / %x3C-5B / %x5D-7E) excludes the raw comma
// (0x2C) and semicolon (0x3B), so they can only appear percent-encoded —
// PROVIDED the split happens before percent-decoding, as extract() does.
// ('=' is 0x3D, inside %x3C-5B, which is why splitting on every '=' was
// a real bug, #199, while the comma split is not. '+' is 0x2B, also a
// legal raw octet — see #198 for the decode-side bug that remains.)

import 'package:dartastic_opentelemetry/src/context/propagation/w3c_baggage_propagator.dart';
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

class _Getter implements TextMapGetter<String> {
  final Map<String, String> _map;
  _Getter(this._map);
  @override
  String? get(String key) => _map[key];
  @override
  Iterable<String> keys() => _map.keys;
}

void main() {
  group('W3CBaggagePropagator list-splitting invariants', () {
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

    Context extract(String header) => propagator.extract(
        context, {'baggage': header}, _Getter({'baggage': header}));

    test('%2C-encoded commas in values survive: split precedes decode', () {
      final result = extract('k1=val%2Cwith%2Ccommas,k2=v2');
      expect(result.baggage?.getEntry('k1')?.value, equals('val,with,commas'));
      expect(result.baggage?.getEntry('k2')?.value, equals('v2'));
    });

    test('%3B-encoded semicolons in values survive the properties split', () {
      final result = extract('k1=a%3Bb;prop=1,k2=v2');
      expect(result.baggage?.getEntry('k1')?.value, equals('a;b'));
      expect(result.baggage?.getEntry('k1')?.metadata, equals('prop=1'));
      expect(result.baggage?.getEntry('k2')?.value, equals('v2'));
    });

    test('OWS around the list separator is tolerated', () {
      final result = extract('k1=v1 , k2=v2');
      expect(result.baggage?.getEntry('k1')?.value, equals('v1'));
      expect(result.baggage?.getEntry('k2')?.value, equals('v2'));
    });
  });
}
