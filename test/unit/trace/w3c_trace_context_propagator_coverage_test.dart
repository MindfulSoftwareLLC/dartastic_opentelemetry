// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
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

  group('W3CTraceContextPropagator coverage tests', () {
    group('inject()', () {
      test('inject adds traceparent header to carrier', () {
        final traceId = OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
        final spanId = OTel.spanIdFrom('00f067aa0ba902b7');
        final spanContext = OTel.spanContext(
          traceId: traceId,
          spanId: spanId,
          traceFlags: TraceFlags.sampled,
        );
        final context = OTel.context(spanContext: spanContext);
        final carrier = <String, String>{};
        final mapSetter = MapTextMapSetter(carrier);

        propagator.inject(context, carrier, mapSetter);

        expect(carrier.containsKey('traceparent'), isTrue);
        expect(carrier['traceparent'],
            equals('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'));
      });

      test('inject includes tracestate when present', () {
        final traceId = OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
        final spanId = OTel.spanIdFrom('00f067aa0ba902b7');
        final traceState =
            OTel.traceState({'vendor1': 'val1', 'vendor2': 'val2'});
        final spanContext = OTel.spanContext(
          traceId: traceId,
          spanId: spanId,
          traceFlags: TraceFlags.sampled,
          traceState: traceState,
        );
        final context = OTel.context(spanContext: spanContext);
        final carrier = <String, String>{};
        final mapSetter = MapTextMapSetter(carrier);

        propagator.inject(context, carrier, mapSetter);

        expect(carrier.containsKey('tracestate'), isTrue);
        final ts = carrier['tracestate']!;
        expect(ts, contains('vendor1=val1'));
        expect(ts, contains('vendor2=val2'));
      });

      test('inject with sampled flag', () {
        final traceId = OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
        final spanId = OTel.spanIdFrom('00f067aa0ba902b7');
        final spanContext = OTel.spanContext(
          traceId: traceId,
          spanId: spanId,
          traceFlags: TraceFlags.sampled,
        );
        final context = OTel.context(spanContext: spanContext);
        final carrier = <String, String>{};
        final mapSetter = MapTextMapSetter(carrier);

        propagator.inject(context, carrier, mapSetter);

        expect(carrier['traceparent'], endsWith('-01'));
      });

      test('inject with non-sampled flag', () {
        final traceId = OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
        final spanId = OTel.spanIdFrom('00f067aa0ba902b7');
        final spanContext = OTel.spanContext(
          traceId: traceId,
          spanId: spanId,
          traceFlags: TraceFlags.none,
        );
        final context = OTel.context(spanContext: spanContext);
        final carrier = <String, String>{};
        final mapSetter = MapTextMapSetter(carrier);

        propagator.inject(context, carrier, mapSetter);

        expect(carrier['traceparent'], endsWith('-00'));
      });
    });

    group('extract()', () {
      test('extract parses valid traceparent', () {
        final carrier = <String, String>{
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
        };
        final mapGetter = MapTextMapGetter(carrier);
        final context = OTel.context();

        final extracted = propagator.extract(context, carrier, mapGetter);

        final sc = extracted.spanContext;
        expect(sc, isNotNull);
        expect(sc!.isValid, isTrue);
        expect(
            sc.traceId.hexString, equals('4bf92f3577b34da6a3ce929d0e0e4736'));
        expect(sc.spanId.hexString, equals('00f067aa0ba902b7'));
        expect(sc.traceFlags.isSampled, isTrue);
        expect(sc.isRemote, isTrue);
      });

      test('extract handles invalid traceparent (wrong format)', () {
        final carrier = <String, String>{
          'traceparent': 'not-a-valid-traceparent-header-value',
        };
        final mapGetter = MapTextMapGetter(carrier);
        final context = OTel.context();

        final extracted = propagator.extract(context, carrier, mapGetter);

        // Should return original context unchanged
        expect(extracted.spanContext, isNull);
      });

      test('extract handles missing traceparent', () {
        final carrier = <String, String>{};
        final mapGetter = MapTextMapGetter(carrier);
        final context = OTel.context();

        final extracted = propagator.extract(context, carrier, mapGetter);

        expect(extracted.spanContext, isNull);
      });

      test('extract parses tracestate', () {
        final carrier = <String, String>{
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
          'tracestate': 'rojo=00f067aa0ba902b7,congo=t61rcWkgMzE',
        };
        final mapGetter = MapTextMapGetter(carrier);
        final context = OTel.context();

        final extracted = propagator.extract(context, carrier, mapGetter);

        final sc = extracted.spanContext;
        expect(sc, isNotNull);
        expect(sc!.traceState, isNotNull);
        expect(sc.traceState!.entries, hasLength(2));
        expect(sc.traceState!.entries['rojo'], equals('00f067aa0ba902b7'));
        expect(sc.traceState!.entries['congo'], equals('t61rcWkgMzE'));
      });

      test('extract with version 00 traceparent', () {
        final carrier = <String, String>{
          'traceparent':
              '00-abcdef1234567890abcdef1234567890-1234567890abcdef-01',
        };
        final mapGetter = MapTextMapGetter(carrier);
        final context = OTel.context();

        final extracted = propagator.extract(context, carrier, mapGetter);

        final sc = extracted.spanContext;
        expect(sc, isNotNull);
        expect(sc!.isValid, isTrue);
        expect(
            sc.traceId.hexString, equals('abcdef1234567890abcdef1234567890'));
        expect(sc.spanId.hexString, equals('1234567890abcdef'));
      });
    });

    group('roundtrip', () {
      test('inject then extract roundtrip preserves traceId and spanId', () {
        // Create a span context
        final traceId = OTel.traceIdFrom('aabbccdd11223344aabbccdd11223344');
        final spanId = OTel.spanIdFrom('1122334455667788');
        final traceState = OTel.traceState({'myvendor': 'myvalue'});
        final spanContext = OTel.spanContext(
          traceId: traceId,
          spanId: spanId,
          traceFlags: TraceFlags.sampled,
          traceState: traceState,
        );
        final originalContext = OTel.context(spanContext: spanContext);

        // Inject into carrier
        final carrier = <String, String>{};
        final mapSetter = MapTextMapSetter(carrier);
        propagator.inject(originalContext, carrier, mapSetter);

        // Extract from carrier
        final mapGetter = MapTextMapGetter(carrier);
        final extractedContext =
            propagator.extract(OTel.context(), carrier, mapGetter);

        // Verify roundtrip
        final sc = extractedContext.spanContext;
        expect(sc, isNotNull);
        expect(sc!.traceId.hexString, equals(traceId.hexString));
        expect(sc.spanId.hexString, equals(spanId.hexString));
        expect(sc.traceFlags.isSampled, isTrue);
        expect(sc.isRemote, isTrue);
        expect(sc.traceState, isNotNull);
        expect(sc.traceState!.entries['myvendor'], equals('myvalue'));
      });
    });

    group('fields()', () {
      test('fields returns expected field names', () {
        final fields = propagator.fields();
        expect(fields, hasLength(2));
        expect(fields, contains('traceparent'));
        expect(fields, contains('tracestate'));
      });
    });
  });
}

/// Simple implementation of TextMapGetter for `Map<String, String>`.
class MapTextMapGetter implements TextMapGetter<String> {
  final Map<String, String> _map;

  MapTextMapGetter(this._map);

  @override
  String? get(String key) => _map[key];

  @override
  Iterable<String> keys() => _map.keys;
}

/// Simple implementation of TextMapSetter for `Map<String, String>`.
class MapTextMapSetter implements TextMapSetter<String> {
  final Map<String, String> _map;

  MapTextMapSetter(this._map);

  @override
  void set(String key, String value) {
    _map[key] = value;
  }
}
