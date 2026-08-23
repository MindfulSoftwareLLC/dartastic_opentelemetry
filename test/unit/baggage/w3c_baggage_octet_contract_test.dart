// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// RED contract tests for PR #264 (issue #198), per the wave TDD
// convention: these pin the W3C baggage-octet allowlist contracts the
// review found unmet. They fail on the current branch and turn green
// when the encoder switches from a four-character denylist to encoding
// everything outside the baggage-octet allowlist, extract gains a
// per-entry guard, and metadata is validated.
//
// W3C baggage grammar: value = *baggage-octet where
//   baggage-octet = %x21 / %x23-2B / %x2D-3A / %x3C-5B / %x5D-7E
// (excludes space, DQUOTE, comma, semicolon, backslash, controls, and
// everything non-ASCII; '%' is IN the allowlist but must be escaped by
// any encoder whose decoder percent-decodes, or the codec is not
// injective.)

import 'package:dartastic_opentelemetry/src/context/propagation/w3c_baggage_propagator.dart';
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

class _MapGetter implements TextMapGetter<String> {
  _MapGetter(this._map);
  final Map<String, String> _map;
  @override
  String? get(String key) => _map[key];
  @override
  Iterable<String> keys() => _map.keys;
}

class _MapSetter implements TextMapSetter<String> {
  _MapSetter(this._map);
  final Map<String, String> _map;
  @override
  void set(String key, String value) => _map[key] = value;
}

void main() {
  late W3CBaggagePropagator propagator;

  setUp(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'baggage-octet-contract-test',
      detectPlatformResources: false,
      enableMetrics: false,
    );
    propagator = W3CBaggagePropagator();
  });

  tearDown(() async {
    await OTel.reset();
  });

  String injectValue(String value, {String? metadata}) {
    final baggage = OTel.baggage({'k': OTel.baggageEntry(value, metadata)});
    final context = OTel.context().withBaggage(baggage);
    final carrier = <String, String>{};
    propagator.inject(context, carrier, _MapSetter(carrier));
    return carrier['baggage'] ?? '';
  }

  Baggage? extractHeader(String header) {
    final context = propagator.extract(
      OTel.context(),
      {'baggage': header},
      _MapGetter({'baggage': header}),
    );
    return context.baggage;
  }

  group('encoder is an allowlist over baggage-octet', () {
    // (value, expected wire form) — one row per broken character class.
    const rows = <(String, String, String)>[
      ('literal percent', '100%', '100%25'),
      ('pre-encoded text stays distinct', 'a%2Cb', 'a%252Cb'),
      ('non-ASCII is UTF-8 percent-encoded', 'café', 'caf%C3%A9'),
      ('CR LF are escaped', 'a\r\nb', 'a%0D%0Ab'),
      ('backslash is escaped', r'C:\x', 'C%3A%5Cx'),
    ];

    for (final (label, value, wire) in rows) {
      test(label, () {
        final header = injectValue(value);
        expect(header, 'k=$wire');
      });

      test('$label round-trips through extract', () {
        final header = injectValue(value);
        final baggage = extractHeader(header);
        expect(baggage?.getEntry('k')?.value, value,
            reason: 'inject followed by extract must return the original '
                'value byte-for-byte (codec injectivity)');
      });
    }
  });

  group('extract skips unparsable entries instead of throwing', () {
    // Per W3C: an invalid list member is ignored; the rest of the header
    // and the rest of the request must survive.
    const malformed = <(String, String)>[
      ('truncated escape', 'good=1,bad=100%,ok=2'),
      ('invalid escape', 'good=1,bad=%zz,ok=2'),
      ('invalid utf-8 escape', 'good=1,bad=%FF,ok=2'),
    ];

    for (final (label, header) in malformed) {
      test(label, () {
        late final Baggage? baggage;
        expect(() => baggage = extractHeader(header), returnsNormally);
        expect(baggage?.getEntry('good')?.value, '1');
        expect(baggage?.getEntry('ok')?.value, '2');
      });
    }
  });

  test('extract drops non-token keys, matching inject', () {
    // Asymmetry loses data at a pass-through hop: extract accepted the
    // key, inject silently drops it.
    final baggage = extractHeader('user name=alice,ok=1');
    expect(baggage?.getEntry('ok')?.value, '1');
    expect(baggage?.getEntry('user name'), isNull,
        reason: 'a key that inject would drop must not be extracted');
  });

  test('metadata cannot forge additional entries', () {
    final header = injectValue('v', metadata: 'source=x,evil=hacked');
    // However metadata is handled (encoded or dropped), the wire header
    // must contain exactly one list member: a receiver splitting on ','
    // must not materialize a forged "evil" entry.
    expect(header.split(',').length, 1,
        reason: 'raw metadata is concatenated into the header and a '
            'receiver parses the injected comma as a new entry');
    final baggage = extractHeader(header);
    expect(baggage?.getEntry('evil'), isNull);
  });
}
