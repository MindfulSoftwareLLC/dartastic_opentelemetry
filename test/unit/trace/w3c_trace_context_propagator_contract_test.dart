// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// W3C Trace Context Level 2 conformance tests for traceparent parsing.
///
/// Covers three spec deviations:
/// - #192 a higher traceparent version must be parsed, not rejected (§3.2.4)
/// - #193 trace-id and span-id are lowercase hex only (§3.2.2.3, §3.2.2.4)
/// - #194 malformed trace-flags invalidate the header (§3.2.2.5)
void main() {
  const traceIdHex = '4bf92f3577b34da6a3ce929d0e0e4736';
  const spanIdHex = '00f067aa0ba902b7';

  late W3CTraceContextPropagator propagator;

  setUpAll(() async {
    await OTel.initialize(
      serviceName: 'test-service',
      endpoint: 'http://localhost:4317',
      detectPlatformResources: false,
    );
  });

  setUp(() {
    propagator = W3CTraceContextPropagator();
  });

  tearDownAll(() async {
    await OTel.reset();
  });

  /// Extracts [traceparent] and returns the resulting SpanContext, or null when
  /// the header was rejected and the incoming Context was returned untouched.
  SpanContext? extract(String traceparent) {
    final carrier = {'traceparent': traceparent};
    return propagator
        .extract(OTel.context(), carrier, _MapGetter(carrier))
        .spanContext;
  }

  group('W3CTraceContextPropagator contract', () {
    group('traceparent version handling', () {
      test('accepts a higher version with the version 00 field layout', () {
        final spanContext = extract('01-$traceIdHex-$spanIdHex-01');

        expect(spanContext, isNotNull);
        expect(spanContext!.traceId.hexString, equals(traceIdHex));
        expect(spanContext.spanId.hexString, equals(spanIdHex));
        expect(spanContext.traceFlags.isSampled, isTrue);
        expect(spanContext.isRemote, isTrue);
      });

      test('injects an extracted higher version as version 00', () {
        final incoming = {
          'traceparent': '01-$traceIdHex-$spanIdHex-01-extradata',
        };
        final context = propagator.extract(
          OTel.context(),
          incoming,
          _MapGetter(incoming),
        );
        final outgoing = <String, String>{};

        propagator.inject(context, outgoing, _MapSetter(outgoing));

        expect(
          outgoing['traceparent'],
          equals('00-$traceIdHex-$spanIdHex-01'),
        );
      });

      test('accepts the version cc example from the issue report', () {
        expect(
          extract('cc-$traceIdHex-$spanIdHex-01')?.traceId.hexString,
          equals(traceIdHex),
        );
      });

      test('accepts fe, the highest legal version', () {
        expect(extract('fe-$traceIdHex-$spanIdHex-01'), isNotNull);
      });

      test('accepts a higher version carrying one additive field', () {
        final spanContext = extract('01-$traceIdHex-$spanIdHex-01-extradata');

        expect(spanContext, isNotNull);
        expect(spanContext!.traceId.hexString, equals(traceIdHex));
        expect(spanContext.spanId.hexString, equals(spanIdHex));
        expect(spanContext.traceFlags.isSampled, isTrue);
      });

      test('accepts a higher version carrying several additive fields', () {
        expect(
          extract('01-$traceIdHex-$spanIdHex-01-aa-bb-cc')?.traceId.hexString,
          equals(traceIdHex),
        );
      });

      test('accepts a higher version whose additive field is empty', () {
        // §3.2.4 requires the flags to be at the end of the string or followed by
        // a dash. Java, Go and JS all accept a bare trailing dash.
        expect(extract('01-$traceIdHex-$spanIdHex-01-'), isNotNull);
      });

      test('parses tracestate alongside a higher-version traceparent', () {
        // §3.3.5: tracestate must still be attempted for a higher version.
        final carrier = {
          'traceparent': '01-$traceIdHex-$spanIdHex-01-extradata',
          'tracestate': 'rojo=00f067aa0ba902b7',
        };

        final spanContext = propagator
            .extract(OTel.context(), carrier, _MapGetter(carrier))
            .spanContext;

        expect(spanContext, isNotNull);
        expect(
          spanContext!.traceState?.entries['rojo'],
          equals('00f067aa0ba902b7'),
        );
      });

      test('rejects version ff', () {
        expect(extract('ff-$traceIdHex-$spanIdHex-01'), isNull);
      });

      test('rejects a version 00 header carrying additive fields', () {
        // §3.2.2.2 closes the version 00 grammar, so trailing data is malformed.
        expect(extract('00-$traceIdHex-$spanIdHex-01-extradata'), isNull);
      });

      test('rejects a higher version whose flags are not followed by a dash',
          () {
        expect(extract('01-$traceIdHex-$spanIdHex-01x'), isNull);
      });

      test('rejects a higher version shorter than 55 characters', () {
        expect(extract('01-$traceIdHex-$spanIdHex-0'), isNull);
      });

      test('rejects a non-hex version', () {
        expect(extract('zz-$traceIdHex-$spanIdHex-01'), isNull);
      });

      test('rejects an uppercase version', () {
        expect(extract('0A-$traceIdHex-$spanIdHex-01'), isNull);
      });

      test('rejects a single-character version', () {
        expect(extract('0-$traceIdHex-$spanIdHex-01'), isNull);
      });

      test('rejects a header whose delimiters are misplaced', () {
        expect(extract('01_$traceIdHex-$spanIdHex-01'), isNull);
      });
    });

    group('trace-id and span-id syntax', () {
      test('rejects an uppercase trace-id', () {
        expect(extract('00-${traceIdHex.toUpperCase()}-$spanIdHex-01'), isNull);
      });

      test('rejects an uppercase span-id', () {
        expect(extract('00-$traceIdHex-${spanIdHex.toUpperCase()}-01'), isNull);
      });

      test('rejects a signed trace-id', () {
        // int.tryParse('+b', radix: 16) returns 11, which silently rewrote the
        // first byte to 0x0b instead of rejecting the header.
        expect(
          extract('00-+bf92f3577b34da6a3ce929d0e0e4736-$spanIdHex-01'),
          isNull,
        );
      });

      test('rejects a negative-signed trace-id', () {
        // A '-' keeps the delimiters at their expected offsets, so this reaches
        // the field check. int.tryParse('-b', radix: 16) returns -11, which wraps
        // to 245 in a Uint8List and corrupted the trace ID rather than failing.
        final signed = traceIdHex.replaceRange(0, 1, '-');

        expect(signed.length, equals(32));
        expect(extract('00-$signed-$spanIdHex-01'), isNull);
      });

      test('rejects a signed span-id', () {
        expect(extract('00-$traceIdHex-+0f067aa0ba902b7-01'), isNull);
      });

      test('rejects a non-hex trace-id', () {
        expect(extract('00-${'z' * 32}-$spanIdHex-01'), isNull);
      });

      test('rejects a non-hex span-id', () {
        expect(extract('00-$traceIdHex-${'z' * 16}-01'), isNull);
      });

      test('rejects a space inside the trace-id', () {
        final spaced = traceIdHex.replaceRange(30, 31, ' ');

        expect(spaced.length, equals(32));
        expect(extract('00-$spaced-$spanIdHex-01'), isNull);
      });

      test('applies lowercase hex validation above version 00 too', () {
        expect(extract('01-${traceIdHex.toUpperCase()}-$spanIdHex-01'), isNull);
      });
    });

    group('trace-flags syntax', () {
      test('rejects non-hex trace-flags instead of coercing them to 00', () {
        expect(extract('00-$traceIdHex-$spanIdHex-zz'), isNull);
      });

      test('rejects partially non-hex trace-flags', () {
        expect(extract('00-$traceIdHex-$spanIdHex-0z'), isNull);
      });

      test('rejects signed trace-flags', () {
        expect(extract('00-$traceIdHex-$spanIdHex-+1'), isNull);
      });

      test('rejects uppercase trace-flags', () {
        expect(extract('00-$traceIdHex-$spanIdHex-0A'), isNull);
      });

      test('preserves every bit of a well-formed trace-flags byte', () {
        // Pass-through, matching opentelemetry-java and opentelemetry-js. Masking
        // to the flags this SDK models would drop the random-trace-id bit, which
        // §3.2.2.5.2 requires to survive; TraceFlags gains that bit in #132.
        final spanContext = extract('00-$traceIdHex-$spanIdHex-ff');

        expect(spanContext, isNotNull);
        expect(spanContext!.traceFlags.asByte, equals(0xff));
        expect(spanContext.traceFlags.isSampled, isTrue);
      });

      test('preserves the random-trace-id bit without the sampled bit', () {
        final spanContext = extract('00-$traceIdHex-$spanIdHex-02');

        expect(spanContext, isNotNull);
        expect(spanContext!.traceFlags.asByte, equals(0x02));
        expect(spanContext.traceFlags.isSampled, isFalse);
      });
    });

    group('baseline traceparent behavior', () {
      test('accepts the canonical version 00 header', () {
        final spanContext = extract('00-$traceIdHex-$spanIdHex-01');

        expect(spanContext, isNotNull);
        expect(spanContext!.traceId.hexString, equals(traceIdHex));
        expect(spanContext.spanId.hexString, equals(spanIdHex));
        expect(spanContext.traceFlags.isSampled, isTrue);
      });

      test('accepts an unsampled version 00 header', () {
        expect(extract('00-$traceIdHex-$spanIdHex-00')?.traceFlags.isSampled,
            isFalse);
      });

      test('rejects an all-zero trace-id', () {
        expect(extract('00-${'0' * 32}-$spanIdHex-01'), isNull);
      });

      test('rejects an all-zero span-id', () {
        expect(extract('00-$traceIdHex-${'0' * 16}-01'), isNull);
      });

      test('rejects a header truncated before the flags', () {
        expect(extract('00-$traceIdHex-$spanIdHex'), isNull);
      });

      test('rejects an empty header', () {
        expect(extract(''), isNull);
      });

      test('returns the incoming Context untouched when the header is rejected',
          () {
        final carrier = {'traceparent': 'ff-$traceIdHex-$spanIdHex-01'};
        final context = OTel.context();

        final extracted = propagator.extract(
          context,
          carrier,
          _MapGetter(carrier),
        );

        expect(extracted, equals(context));
      });
    });
  });
}

class _MapGetter implements TextMapGetter<String> {
  final Map<String, String> _map;

  _MapGetter(this._map);

  @override
  String? get(String key) => _map[key];

  @override
  Iterable<String> keys() => _map.keys;
}

class _MapSetter implements TextMapSetter<String> {
  final Map<String, String> _map;

  _MapSetter(this._map);

  @override
  void set(String key, String value) => _map[key] = value;
}
