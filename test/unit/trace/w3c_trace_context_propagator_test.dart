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
    );
  });

  setUp(() {
    propagator = W3CTraceContextPropagator();
  });

  tearDownAll(() async {
    await OTel.reset();
  });

  group('W3CTraceContextPropagator', () {
    group('fields()', () {
      test('returns correct field names', () {
        final fields = propagator.fields();
        expect(fields, hasLength(2));
        expect(fields, contains('traceparent'));
        expect(fields, contains('tracestate'));
      });
    });

    group('extract()', () {
      test('extracts valid traceparent header', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        final spanContext = extracted.spanContext;
        expect(spanContext, isNotNull);
        expect(spanContext!.isValid, isTrue);
        expect(spanContext.traceId.hexString,
            equals('4bf92f3577b34da6a3ce929d0e0e4736'));
        expect(spanContext.spanId.hexString, equals('00f067aa0ba902b7'));
        expect(spanContext.traceFlags.isSampled, isTrue);
        expect(spanContext.isRemote, isTrue);
      });

      test('extracts traceparent with tracestate', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
          'tracestate': 'rojo=00f067aa0ba902b7,congo=t61rcWkgMzE'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        final spanContext = extracted.spanContext;
        expect(spanContext, isNotNull);
        expect(spanContext!.traceState, isNotNull);
        expect(spanContext.traceState!.entries, hasLength(2));
        expect(spanContext.traceState!.entries['rojo'],
            equals('00f067aa0ba902b7'));
        expect(spanContext.traceState!.entries['congo'], equals('t61rcWkgMzE'));
      });

      test('extracts traceparent with non-sampled flag', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        final spanContext = extracted.spanContext;
        expect(spanContext, isNotNull);
        expect(spanContext!.traceFlags.isSampled, isFalse);
      });

      test('handles missing traceparent', () {
        // Arrange
        final carrier = <String, String>{};
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        expect(extracted, equals(context));
      });

      test('handles empty traceparent', () {
        // Arrange
        final carrier = {'traceparent': ''};
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        expect(extracted, equals(context));
      });

      test('rejects traceparent with wrong length', () {
        // Arrange
        final carrier = {
          'traceparent': '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        expect(extracted, equals(context));
      });

      test('rejects traceparent with wrong number of parts', () {
        // Arrange
        final carrier = {
          'traceparent': '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        expect(extracted, equals(context));
      });

      test('rejects unsupported version', () {
        // Arrange
        final carrier = {
          'traceparent':
              '01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        expect(extracted, equals(context));
      });

      test('rejects traceparent with invalid trace ID (all zeros)', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-00000000000000000000000000000000-00f067aa0ba902b7-01'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        expect(extracted, equals(context));
      });

      test('rejects traceparent with invalid span ID (all zeros)', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-0000000000000000-01'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        expect(extracted, equals(context));
      });

      test('rejects traceparent with invalid trace ID length', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e473-00f067aa0ba902b7-01'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        expect(extracted, equals(context));
      });

      test('rejects traceparent with invalid span ID length', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b-01'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        expect(extracted, equals(context));
      });

      test('rejects traceparent with invalid trace flags length', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-1'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        expect(extracted, equals(context));
      });

      test('handles malformed tracestate gracefully', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
          'tracestate': 'invalid-format'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        final spanContext = extracted.spanContext;
        expect(spanContext, isNotNull);
        expect(spanContext!.isValid, isTrue);
        // Tracestate should be null or empty since it was malformed
        expect(
            spanContext.traceState == null ||
                spanContext.traceState!.entries.isEmpty,
            isTrue);
      });

      test('handles tracestate with empty entries', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
          'tracestate': 'key1=value1,,key2=value2'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        final spanContext = extracted.spanContext;
        expect(spanContext, isNotNull);
        expect(spanContext!.traceState, isNotNull);
        expect(spanContext.traceState!.entries, hasLength(2));
        expect(spanContext.traceState!.entries['key1'], equals('value1'));
        expect(spanContext.traceState!.entries['key2'], equals('value2'));
      });

      test('handles tracestate with whitespace', () {
        // Arrange
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
          'tracestate': ' key1 = value1 , key2 = value2 '
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        // Act
        final extracted = propagator.extract(context, carrier, getter);

        // Assert
        final spanContext = extracted.spanContext;
        expect(spanContext, isNotNull);
        expect(spanContext!.traceState, isNotNull);
        expect(spanContext.traceState!.entries, hasLength(2));
        expect(spanContext.traceState!.entries['key1'], equals('value1'));
        expect(spanContext.traceState!.entries['key2'], equals('value2'));
      });
    });

    group('inject()', () {
      test('injects valid span context', () {
        // Arrange
        final traceId = OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
        final spanId = OTel.spanIdFrom('00f067aa0ba902b7');
        final traceFlags = TraceFlags.sampled;
        final spanContext = OTel.spanContext(
          traceId: traceId,
          spanId: spanId,
          traceFlags: traceFlags,
        );
        final context = OTel.context(spanContext: spanContext);
        final carrier = <String, String>{};
        final setter = MapTextMapSetter(carrier);

        // Act
        propagator.inject(context, carrier, setter);

        // Assert
        expect(carrier['traceparent'],
            equals('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'));
      });

      test('injects span context with tracestate', () {
        // Arrange
        final traceId = OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
        final spanId = OTel.spanIdFrom('00f067aa0ba902b7');
        final traceFlags = TraceFlags.sampled;
        final traceState = OTel.traceState(
            {'rojo': '00f067aa0ba902b7', 'congo': 't61rcWkgMzE'});
        final spanContext = OTel.spanContext(
          traceId: traceId,
          spanId: spanId,
          traceFlags: traceFlags,
          traceState: traceState,
        );
        final context = OTel.context(spanContext: spanContext);
        final carrier = <String, String>{};
        final setter = MapTextMapSetter(carrier);

        // Act
        propagator.inject(context, carrier, setter);

        // Assert
        expect(carrier['traceparent'], isNotNull);
        expect(carrier['tracestate'], isNotNull);
        expect(
            carrier['tracestate'],
            anyOf(
              equals('rojo=00f067aa0ba902b7,congo=t61rcWkgMzE'),
              equals('congo=t61rcWkgMzE,rojo=00f067aa0ba902b7'),
            ));
      });

      test('injects non-sampled span context', () {
        // Arrange
        final traceId = OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
        final spanId = OTel.spanIdFrom('00f067aa0ba902b7');
        final traceFlags = TraceFlags.none;
        final spanContext = OTel.spanContext(
          traceId: traceId,
          spanId: spanId,
          traceFlags: traceFlags,
        );
        final context = OTel.context(spanContext: spanContext);
        final carrier = <String, String>{};
        final setter = MapTextMapSetter(carrier);

        // Act
        propagator.inject(context, carrier, setter);

        // Assert
        expect(carrier['traceparent'],
            equals('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00'));
      });

      test('does not inject invalid span context', () {
        // Arrange
        final traceId = OTel.traceIdInvalid();
        final spanId = OTel.spanIdInvalid();
        final traceFlags = TraceFlags.none;
        final spanContext = OTel.spanContext(
          traceId: traceId,
          spanId: spanId,
          traceFlags: traceFlags,
        );
        final context = OTel.context(spanContext: spanContext);
        final carrier = <String, String>{};
        final setter = MapTextMapSetter(carrier);

        // Act
        propagator.inject(context, carrier, setter);

        // Assert
        expect(carrier, isEmpty);
      });

      test('does not inject when context has no span context', () {
        // Arrange
        final context = OTel.context();
        final carrier = <String, String>{};
        final setter = MapTextMapSetter(carrier);

        // Act
        propagator.inject(context, carrier, setter);

        // Assert
        expect(carrier, isEmpty);
      });

      test('does not inject empty tracestate', () {
        // Arrange
        final traceId = OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
        final spanId = OTel.spanIdFrom('00f067aa0ba902b7');
        final traceFlags = TraceFlags.sampled;
        final traceState = OTel.traceState({});
        final spanContext = OTel.spanContext(
          traceId: traceId,
          spanId: spanId,
          traceFlags: traceFlags,
          traceState: traceState,
        );
        final context = OTel.context(spanContext: spanContext);
        final carrier = <String, String>{};
        final setter = MapTextMapSetter(carrier);

        // Act
        propagator.inject(context, carrier, setter);

        // Assert
        expect(carrier['traceparent'], isNotNull);
        expect(carrier['tracestate'], isNull);
      });
    });

    group('round-trip', () {
      test('can extract what was injected', () {
        // Arrange
        final originalTraceId =
            OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
        final originalSpanId = OTel.spanIdFrom('00f067aa0ba902b7');
        final originalTraceFlags = TraceFlags.sampled;
        final originalTraceState =
            OTel.traceState({'vendor1': 'value1', 'vendor2': 'value2'});
        final originalSpanContext = OTel.spanContext(
          traceId: originalTraceId,
          spanId: originalSpanId,
          traceFlags: originalTraceFlags,
          traceState: originalTraceState,
        );
        final originalContext = OTel.context(spanContext: originalSpanContext);
        final carrier = <String, String>{};
        final setter = MapTextMapSetter(carrier);
        final getter = MapTextMapGetter(carrier);

        // Act - Inject
        propagator.inject(originalContext, carrier, setter);

        // Act - Extract
        final extractedContext =
            propagator.extract(OTel.context(), carrier, getter);

        // Assert
        final extractedSpanContext = extractedContext.spanContext;
        expect(extractedSpanContext, isNotNull);
        expect(extractedSpanContext!.traceId.hexString,
            equals(originalTraceId.hexString));
        expect(extractedSpanContext.spanId.hexString,
            equals(originalSpanId.hexString));
        expect(extractedSpanContext.traceFlags.isSampled,
            equals(originalTraceFlags.isSampled));
        expect(extractedSpanContext.isRemote, isTrue);
        expect(extractedSpanContext.traceState, isNotNull);
        expect(extractedSpanContext.traceState!.entries,
            equals(originalTraceState.entries));
      });

      test('preserves trace context through multiple hops', () {
        // Arrange
        final originalTraceId =
            OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
        final originalSpanId = OTel.spanIdFrom('00f067aa0ba902b7');
        final originalTraceFlags = TraceFlags.sampled;
        final originalSpanContext = OTel.spanContext(
          traceId: originalTraceId,
          spanId: originalSpanId,
          traceFlags: originalTraceFlags,
        );
        final originalContext = OTel.context(spanContext: originalSpanContext);

        // Act - First hop
        final carrier1 = <String, String>{};
        final setter1 = MapTextMapSetter(carrier1);
        propagator.inject(originalContext, carrier1, setter1);
        final getter1 = MapTextMapGetter(carrier1);
        final context1 = propagator.extract(OTel.context(), carrier1, getter1);

        // Act - Second hop
        final carrier2 = <String, String>{};
        final setter2 = MapTextMapSetter(carrier2);
        propagator.inject(context1, carrier2, setter2);
        final getter2 = MapTextMapGetter(carrier2);
        final context2 = propagator.extract(OTel.context(), carrier2, getter2);

        // Act - Third hop
        final carrier3 = <String, String>{};
        final setter3 = MapTextMapSetter(carrier3);
        propagator.inject(context2, carrier3, setter3);
        final getter3 = MapTextMapGetter(carrier3);
        final context3 = propagator.extract(OTel.context(), carrier3, getter3);

        // Assert - TraceId should be preserved through all hops
        final finalSpanContext = context3.spanContext;
        expect(finalSpanContext, isNotNull);
        expect(finalSpanContext!.traceId.hexString,
            equals(originalTraceId.hexString));
        expect(finalSpanContext.isRemote, isTrue);
      });
    });

    group('W3C spec examples', () {
      test('handles W3C example 1', () {
        // Example from W3C spec
        final carrier = {
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        final extracted = propagator.extract(context, carrier, getter);

        expect(extracted.spanContext, isNotNull);
        expect(extracted.spanContext!.isValid, isTrue);
        expect(extracted.spanContext!.traceFlags.isSampled, isTrue);
      });

      test('handles minimal valid traceId and spanId', () {
        // Smallest non-zero values
        final carrier = {
          'traceparent':
              '00-00000000000000000000000000000001-0000000000000001-01'
        };
        final getter = MapTextMapGetter(carrier);
        final context = OTel.context();

        final extracted = propagator.extract(context, carrier, getter);

        expect(extracted.spanContext, isNotNull);
        expect(extracted.spanContext!.isValid, isTrue);
      });
    });
  });
}

/// Simple implementation of TextMapGetter for Map\<String, String>
class MapTextMapGetter implements TextMapGetter<String> {
  final Map<String, String> _map;

  MapTextMapGetter(this._map);

  @override
  String? get(String key) => _map[key];

  @override
  Iterable<String> keys() => _map.keys;
}

/// Simple implementation of TextMapSetter for Map\<String, String>
class MapTextMapSetter implements TextMapSetter<String> {
  final Map<String, String> _map;

  MapTextMapSetter(this._map);

  @override
  void set(String key, String value) {
    _map[key] = value;
  }
}
