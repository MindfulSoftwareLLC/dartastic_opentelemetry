// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Resource', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        endpoint: 'http://localhost:4317',
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );
    });

    test('creates empty resource', () {
      final resource = OTel.resource(OTel.attributes());
      expect(resource.attributes.isEmpty, isTrue);
    });

    test('creates resource with attributes', () {
      final attributes = {
        'service.name': 'test-service',
        'service.version': '1.0.0',
        'service.instance.id': '12345',
      }.toAttributes();

      final resource = OTel.resource(attributes);
      expect(resource.attributes.getString('service.name'),
          equals('test-service'));
      expect(resource.attributes.getString('service.version'), equals('1.0.0'));
      expect(resource.attributes.getString('service.instance.id'),
          equals('12345'));
    });

    test('creates resource with all attribute types', () {
      final attributes = {
        'string.key': 'value',
        'bool.key': true,
        'int.key': 42,
        'double.key': 3.14,
        'string.list.key': ['a', 'b', 'c'],
        'bool.list.key': [true, false],
        'int.list.key': [1, 2, 3],
        'double.list.key': [1.1, 2.2, 3.3],
      }.toAttributes();

      final resource = OTel.resource(attributes);

      expect(resource.attributes.getString('string.key'), equals('value'));
      expect(resource.attributes.getBool('bool.key'), isTrue);
      expect(resource.attributes.getInt('int.key'), equals(42));
      expect(resource.attributes.getDouble('double.key'), equals(3.14));
      expect(resource.attributes.getStringList('string.list.key'),
          equals(['a', 'b', 'c']));
      expect(resource.attributes.getBoolList('bool.list.key'),
          equals([true, false]));
      expect(resource.attributes.getIntList('int.list.key'), equals([1, 2, 3]));
      expect(resource.attributes.getDoubleList('double.list.key'),
          equals([1.1, 2.2, 3.3]));
    });

    test('merges resources', () {
      final resource1 = OTel.resource({
        'key1': 'value1',
        'key2': 'original',
      }.toAttributes());

      final resource2 = OTel.resource({
        'key2': 'updated',
        'key3': 'value3',
      }.toAttributes());

      final merged = resource1.merge(resource2);

      expect(merged.attributes.getString('key1'), equals('value1'));
      expect(merged.attributes.getString('key2'), equals('updated'));
      expect(merged.attributes.getString('key3'), equals('value3'));
    });

    test('creates immutable resources', () {
      final attributes = {
        'key': 'value',
      }.toAttributes();

      final resource = OTel.resource(attributes);

      // Modifying original attributes should not affect resource
      final newAttributes =
          attributes.copyWithStringAttribute('key', 'new-value');
      expect(resource.attributes.getString('key'), equals('value'));
      expect(newAttributes.getString('key'), equals('new-value'));
    });

    test('returns schema url', () {
      final resource = OTel.resource(
        OTel.attributes(),
      );
      expect(resource.schemaUrl, isNull);
    });

    test('handles empty attributes', () {
      final resource = OTel.resource(OTel.attributes());
      expect(resource.attributes.isEmpty, isTrue);
      expect(resource.schemaUrl, isNull);
    });

    test('preserves attribute order in merged resources', () {
      final resource1 = OTel.resource({
        'a': 1,
        'b': 2,
        'c': 3,
      }.toAttributes());

      final resource2 = OTel.resource({
        'd': 4,
        'e': 5,
        'f': 6,
      }.toAttributes());

      final merged = resource1.merge(resource2);
      final keys = merged.attributes.toMap().keys.toList();

      expect(keys, equals(['a', 'b', 'c', 'd', 'e', 'f']));
    });
  });
}
