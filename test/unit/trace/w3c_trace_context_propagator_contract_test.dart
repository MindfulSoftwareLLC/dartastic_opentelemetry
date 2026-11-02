// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

/// W3C Trace Context Level 2 conformance tests for traceparent parsing.
///
/// Covers three spec deviations:
/// - #192 a higher traceparent version must be parsed, not rejected
/// - #193 trace-id and span-id are lowercase hex only
/// - #194 malformed trace-flags invalidate the header
void main() {
  const traceIdHex = '4bf92f3577b34da6a3ce929d0e0e4736';
  const spanIdHex = '00f067aa0ba902b7';

  late W3CTraceContextPropagator propagator;

  setUpAll(() async {
    await OTel.initialize(
      serviceName: 'test-service',
      spanProcessor: SimpleSpanProcessor(InMemorySpanExporter()),
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
        // W3C requires the flags of a higher version to be at the end of the
        // string or followed by a dash. Java, Go and JS all accept a bare trailing dash.
        expect(extract('01-$traceIdHex-$spanIdHex-01-'), isNotNull);
      });

      test('parses tracestate alongside a higher-version traceparent', () {
        // W3C still has tracestate parsed when the traceparent is a higher
        // version.
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
        // The version 00 grammar is closed, so trailing data is malformed.
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

      test('rejects a malformed version in a full-length header', () {
        expect(extract('0 -$traceIdHex-$spanIdHex-01'), isNull);
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

      test('a malformed header is not reported to the error handler', () {
        // A bad incoming header is ignored, not reported as API misuse the
        // way OTel.traceIdFrom reports a malformed argument.
        final reported = <Object>[];
        OTelErrorHandling.handler = (error, stackTrace) => reported.add(error);
        addTearDown(OTelErrorHandling.resetToDefault);

        expect(extract('00-${traceIdHex.toUpperCase()}-$spanIdHex-01'), isNull);
        expect(extract('00-$traceIdHex-${'z' * 16}-01'), isNull);
        expect(reported, isEmpty);
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

      test('accepts reserved trace-flags bits but clears them', () {
        // W3C says reserved bits MUST be set to zero, which is not a reason to
        // reject the header. Sampled and random-trace-id survive.
        final spanContext = extract('00-$traceIdHex-$spanIdHex-ff');

        expect(spanContext, isNotNull);
        expect(spanContext!.traceFlags.asByte, equals(0x03));
        expect(spanContext.traceFlags.isSampled, isTrue);
        expect(spanContext.traceFlags.isRandom, isTrue);
      });

      test('preserves the random-trace-id bit without the sampled bit', () {
        final spanContext = extract('00-$traceIdHex-$spanIdHex-02');

        expect(spanContext, isNotNull);
        expect(spanContext!.traceFlags.asByte, equals(0x02));
        expect(spanContext.traceFlags.isSampled, isFalse);
        expect(spanContext.traceFlags.isRandom, isTrue);
      });
    });

    group('round trip and rejection', () {
      test('round-trips the defined bits of all 256 flags bytes', () {
        for (final version in ['00', 'cc']) {
          for (var flags = 0; flags < 256; flags++) {
            final hex = flags.toRadixString(16).padLeft(2, '0');
            final carrier = {
              'traceparent': '$version-$traceIdHex-$spanIdHex-$hex'
            };
            final context = propagator.extract(
                OTel.context(), carrier, _MapGetter(carrier));
            final defined = flags & 0x03;
            expect(context.spanContext!.traceFlags.asByte, defined);
            final outgoing = <String, String>{};
            propagator.inject(context, outgoing, _MapSetter(outgoing));
            expect(
              outgoing['traceparent'],
              '00-$traceIdHex-$spanIdHex-0$defined',
            );
          }
        }
      });

      test('inject clears reserved bits of locally built flags', () {
        final context = OTel.context().withSpanContext(
          OTel.spanContext(
            traceId: OTel.traceIdFrom(traceIdHex),
            spanId: OTel.spanIdFrom(spanIdHex),
            traceFlags: OTel.traceFlags(0xff),
          ),
        );
        final outgoing = <String, String>{};
        propagator.inject(context, outgoing, _MapSetter(outgoing));

        expect(outgoing['traceparent'], '00-$traceIdHex-$spanIdHex-03');
      });

      test('malformed flags preserve an existing context including tracestate',
          () {
        final parent = OTel.spanContext(
          traceId: OTel.traceIdFrom(traceIdHex),
          spanId: OTel.spanIdFrom(spanIdHex),
          traceFlags: OTel.traceFlags(3),
          traceState: OTel.traceState({'existing': 'state'}),
        );
        final context = OTel.context().withSpanContext(parent);
        for (final flags in ['zz', '+1', '-1', '0A', ' 1']) {
          final carrier = {
            'traceparent': '00-$traceIdHex-$spanIdHex-$flags',
            'tracestate': 'incoming=value'
          };
          expect(propagator.extract(context, carrier, _MapGetter(carrier)),
              same(context));
          expect(context.spanContext, same(parent));
        }
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
