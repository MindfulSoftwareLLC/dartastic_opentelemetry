// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('ObservableResult Tests', () {
    late ObservableResult<int> intResult;
    late ObservableResult<double> doubleResult;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'observable-result-test-service',
        detectPlatformResources: false,
      );
      
      intResult = ObservableResult<int>();
      doubleResult = ObservableResult<double>();
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('ObservableResult starts with empty measurements', () {
      expect(intResult.measurements, isEmpty);
      expect(doubleResult.measurements, isEmpty);
    });

    test('observe adds a measurement with integer value', () {
      intResult.observe(42);
      
      expect(intResult.measurements.length, equals(1));
      expect(intResult.measurements.first.value, equals(42));
      expect(intResult.measurements.first.attributes, isNotNull);
      expect(intResult.measurements.first.attributes!.toList(), isEmpty);
    });

    test('observe adds a measurement with double value', () {
      doubleResult.observe(42.5);
      
      expect(doubleResult.measurements.length, equals(1));
      expect(doubleResult.measurements.first.value, equals(42.5));
      expect(doubleResult.measurements.first.attributes, isNotNull);
      expect(doubleResult.measurements.first.attributes!.toList(), isEmpty);
    });

    test('observe with attributes adds measurement with attributes', () {
      final attributes = Attributes.of({
        'key1': 'value1',
        'key2': 42,
      });
      
      intResult.observe(100, attributes);
      
      expect(intResult.measurements.length, equals(1));
      expect(intResult.measurements.first.value, equals(100));
      expect(intResult.measurements.first.attributes, equals(attributes));
      
      final attrList = intResult.measurements.first.attributes!.toList();
      expect(attrList.length, equals(2));
      
      final attr1 = attrList.firstWhere((attr) => attr.key == 'key1');
      final attr2 = attrList.firstWhere((attr) => attr.key == 'key2');
      
      expect(attr1.value, equals('value1'));
      expect(attr2.value, equals(42));
    });

    test('observeWithMap adds measurement with map attributes', () {
      final attributesMap = {
        'key1': 'value1',
        'key2': 42,
        'key3': true,
      };
      
      doubleResult.observeWithMap(123.45, attributesMap);
      
      expect(doubleResult.measurements.length, equals(1));
      expect(doubleResult.measurements.first.value, equals(123.45));
      expect(doubleResult.measurements.first.attributes, isNotNull);
      
      final attrList = doubleResult.measurements.first.attributes!.toList();
      expect(attrList.length, equals(3));
      
      final attr1 = attrList.firstWhere((attr) => attr.key == 'key1');
      final attr2 = attrList.firstWhere((attr) => attr.key == 'key2');
      final attr3 = attrList.firstWhere((attr) => attr.key == 'key3');
      
      expect(attr1.value, equals('value1'));
      expect(attr2.value, equals(42));
      expect(attr3.value, equals(true));
    });

    test('multiple observe calls add multiple measurements', () {
      intResult.observe(1);
      intResult.observe(2);
      intResult.observe(3, Attributes.of({'tag': 'value'}));
      
      expect(intResult.measurements.length, equals(3));
      expect(intResult.measurements[0].value, equals(1));
      expect(intResult.measurements[1].value, equals(2));
      expect(intResult.measurements[2].value, equals(3));
      
      // Third measurement should have the attribute
      expect(intResult.measurements[2].attributes!.toList().length, equals(1));
      expect(intResult.measurements[2].attributes!.toList().first.key, equals('tag'));
      expect(intResult.measurements[2].attributes!.toList().first.value, equals('value'));
    });

    test('measurements returns unmodifiable list', () {
      intResult.observe(1);
      intResult.observe(2);
      
      final measurements = intResult.measurements;
      expect(measurements.length, equals(2));
      
      // Try to modify the list - this should throw
      expect(() => (measurements as List<dynamic>).add(null), throwsUnsupportedError);
    });

    test('observe with null OTelFactory does not add measurement', () {
      // First make observations with valid factory
      intResult.observe(1);
      expect(intResult.measurements.length, equals(1));
      
      // Save current factory and set to null
      final savedFactory = OTelFactory.otelFactory;
      OTelFactory.otelFactory = null;
      
      // Try to observe with null factory
      intResult.observe(2);
      
      // Should still have just one measurement
      expect(intResult.measurements.length, equals(1));
      
      // Restore factory
      OTelFactory.otelFactory = savedFactory;
    });

    test('observeWithMap with null OTelFactory does not add measurement', () {
      // First make observations with valid factory
      intResult.observeWithMap(1, {'key': 'value'});
      expect(intResult.measurements.length, equals(1));
      
      // Save current factory and set to null
      final savedFactory = OTelFactory.otelFactory;
      OTelFactory.otelFactory = null;
      
      // Try to observe with null factory
      intResult.observeWithMap(2, {'key': 'value'});
      
      // Should still have just one measurement
      expect(intResult.measurements.length, equals(1));
      
      // Restore factory
      OTelFactory.otelFactory = savedFactory;
    });
  });
}
