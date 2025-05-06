// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('Factory Pattern', () {
    setUp(() async {
      await OTel.reset();
    });

    //TODO - this fails all tests
    // tearDown(() async {
    //   await OTel.reset();
    // });

    test('OTel.initialize installs SDK factory', () {
      // Before initialize, factory should be null
      expect(OTelFactory.otelFactory, isNull);

      // Initialize OTel
      OTel.initialize(serviceName: 'test-service');

      // Factory should be installed and be the SDK implementation
      expect(OTelFactory.otelFactory, isNotNull);
      expect(OTelFactory.otelFactory, isA<OTelSDKFactory>());
    });

    test('All objects created through factory are SDK implementations', () {
      // Initialize OTel
      OTel.initialize(serviceName: 'test-service');

      // Create various objects through OTel and check their type
      final tracerProvider = OTel.tracerProvider();
      expect(tracerProvider, isA<TracerProvider>());

      final tracer = OTel.tracer();
      expect(tracer, isA<Tracer>());

      final meterProvider = OTel.meterProvider();
      expect(meterProvider, isA<MeterProvider>());

      final meter = OTel.meter();
      expect(meter, isA<Meter>());

      final span = tracer.startSpan('test-span');
      expect(span, isA<Span>());
    });

    test('Factory creates correct attribute types', () {
      // Initialize OTel
      OTel.initialize(serviceName: 'test-service');

      // Test creating attributes through the factory
      final strAttr = OTel.attributeString('str.key', 'value');
      expect(strAttr.key, equals('str.key'));
      expect(strAttr.value, equals('value'));

      final boolAttr = OTel.attributeBool('bool.key', true);
      expect(boolAttr.key, equals('bool.key'));
      expect(boolAttr.value, isTrue);

      final intAttr = OTel.attributeInt('int.key', 42);
      expect(intAttr.key, equals('int.key'));
      expect(intAttr.value, equals(42));

      final doubleAttr = OTel.attributeDouble('double.key', 3.14);
      expect(doubleAttr.key, equals('double.key'));
      expect(doubleAttr.value, equals(3.14));

      // Create and test attributes collection
      final attrs = OTel.attributes([strAttr, intAttr]);
      expect(attrs.length, equals(2));
      expect(attrs.getString('str.key'), equals('value'));
      expect(attrs.getInt('int.key'), equals(42));
    });

    test('Factory supports named TracerProviders and MeterProviders', () {
      // Initialize OTel
      OTel.initialize(serviceName: 'test-service');

      // Add named providers
      final tp1 = OTel.addTracerProvider('provider1');
      final tp2 = OTel.addTracerProvider('provider2');

      // Verify they're different instances
      expect(tp1, isNot(same(tp2)));

      // Getting the same name should return the same instance
      final tp1Again = OTel.tracerProvider(name: 'provider1');
      expect(tp1, same(tp1Again));

      // Test the same for meter providers
      final mp1 = OTel.addMeterProvider('meter1');
      final mp2 = OTel.addMeterProvider('meter2');

      expect(mp1, isNot(same(mp2)));

      final mp1Again = OTel.meterProvider(name: 'meter1');
      expect(mp1, same(mp1Again));
    });

    test('Factory properly validates initialization parameters', () {
      // Test with invalid parameters
      expect(() => OTel.initialize(serviceName: ''), throwsArgumentError);
      expect(() => OTel.initialize(serviceVersion: ''), throwsArgumentError);
      expect(() => OTel.initialize(endpoint: ''), throwsArgumentError);

      // Valid initialization
      OTel.initialize(serviceName: 'valid-service');

      // Test double initialization
      expect(() => OTel.initialize(serviceName: 'another-service'), throwsStateError);
    });

    test('Resource creation through factory', () {
      // Initialize OTel
      OTel.initialize(serviceName: 'test-service');

      // Create resource with attributes
      final attrs = OTel.attributesFromMap({
        'service.name': 'my-service',
        'service.version': '1.0.0',
      });

      final resource = OTel.resource(attrs);

      expect(resource, isNotNull);
      expect(resource.attributes.getString('service.name'), equals('my-service'));
      expect(resource.attributes.getString('service.version'), equals('1.0.0'));
    });

    test('Span creation through factory pattern', () {
      // Initialize OTel
      OTel.initialize(serviceName: 'test-service');

      final tracer = OTel.tracer();

      // Create a span
      final span = tracer.startSpan('test-span');

      expect(span, isNotNull);
      expect(span.name, equals('test-span'));
      expect(span.isRecording, isTrue);
      expect(span.spanContext.isValid, isTrue);

      // End the span
      span.end();
      expect(span.isRecording, isFalse);
    });
  });
}
