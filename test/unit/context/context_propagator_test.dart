// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

class TestCarrier {
  final Map<String, String> headers = {};
}

class TestGetter implements TextMapGetter<String> {
  final TestCarrier _carrier;

  TestGetter(this._carrier);

  @override
  String? get(String key) => _carrier.headers[key];

  @override
  Iterable<String> keys() => _carrier.headers.keys;
}

class TestSetter implements TextMapSetter<String> {
  final TestCarrier _carrier;

  TestSetter(this._carrier);

  @override
  void set(String key, String value) {
    _carrier.headers[key] = value;
  }
}

/// A simple propagator for testing
class TestPropagator implements TextMapPropagator<Map<String, String>, String> {
  @override
  List<String> fields() => ['test-field'];

  @override
  void inject(Context context, Map<String, String> carrier, TextMapSetter<String> setter) {
    final span = context.span;
    if (span != null) {
      setter.set('test-field', span.spanContext.traceId.toString());
    }
  }

  @override
  Context extract(Context context, Map<String, String> carrier, TextMapGetter<String> getter) {
    final value = getter.get('test-field');
    if (value != null) {
      // In a real implementation, you would parse the value and create a span
      return context;
    }
    return context;
  }
}

void main() {
  group('Context Propagation', () {
    late TestCarrier carrier;
    late TestGetter getter;
    late TestSetter setter;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        endpoint: 'http://localhost:4317',
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );

      carrier = TestCarrier();
      getter = TestGetter(carrier);
      setter = TestSetter(carrier);
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('propagates context using test propagator', () {
      final tracer = OTel.tracerProvider().getTracer('test-tracer');
      final span = tracer.startSpan('test-span');
      final context = Context.root.withSpan(span);

      final propagator = TestPropagator();
      propagator.inject(context, carrier.headers, setter);

      // Verify test field was set
      expect(carrier.headers['test-field'], isNotNull);

      // Extract and verify context
      final extractedContext = propagator.extract(Context.root, carrier.headers, getter);
      expect(extractedContext, isNotNull);
    });

    test('composite propagator combines multiple propagators', () {
      final context = Context.root;
      final propagator = CompositePropagator([
        TestPropagator(),
        TestPropagator(),
      ]);

      propagator.inject(context, carrier.headers, setter);
      final extractedContext = propagator.extract(Context.root, carrier.headers, getter);

      expect(extractedContext, isNotNull);
    });

    test('returns all fields from propagators', () {
      final propagator = CompositePropagator([
        TestPropagator(),
        TestPropagator(),
      ]);

      final fields = propagator.fields();
      expect(fields, contains('test-field'));
    });
  });
}
