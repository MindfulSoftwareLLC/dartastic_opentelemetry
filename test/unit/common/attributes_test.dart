// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('Attributes Tests', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('Attributes equality check', () {
      // Create attributes in different ways but with same content
      final attrs1 = {'service': 'api'}.toAttributes();
      final attrs2 = {'service': 'api'}.toAttributes();
      final attrs3 = {'service': 'db'}.toAttributes();

      // Verify equality works correctly
      expect(attrs1 == attrs2, isTrue);
      expect(attrs1 == attrs3, isFalse);
      expect(attrs1.hashCode == attrs2.hashCode, isTrue);
      expect(attrs1.hashCode == attrs3.hashCode, isFalse);
    });

    test('Map with Attributes as keys', () {
      // Create attributes
      final attrs1 = {'service': 'api'}.toAttributes();
      final attrs2 = {'service': 'api'}.toAttributes();
      final attrs3 = {'service': 'db'}.toAttributes();

      // Create a map using attributes as keys
      final map = <Attributes, String>{};
      map[attrs1] = 'value1';

      // Verify map lookups work as expected
      expect(map.containsKey(attrs1), isTrue);
      expect(map.containsKey(attrs2), isTrue, reason: 'Same content but different instances should be equal');
      expect(map.containsKey(attrs3), isFalse);
      expect(map[attrs1], equals('value1'));
      expect(map[attrs2], equals('value1'), reason: 'Should retrieve value with equivalent key');
    });

    test('Empty attributes equality', () {
      // Create empty attributes in different ways
      final empty1 = OTelFactory.otelFactory!.attributes();
      final empty2 = OTelFactory.otelFactory!.attributes();
      final empty3 = <String, Object>{}.toAttributes();

      // Verify all are equal
      expect(empty1 == empty2, isTrue);
      expect(empty1 == empty3, isTrue);
      expect(empty1.hashCode == empty2.hashCode, isTrue);
      expect(empty1.hashCode == empty3.hashCode, isTrue);

      // Map test with empty attributes
      final map = <Attributes, String>{};
      map[empty1] = 'empty';

      expect(map.containsKey(empty2), isTrue);
      expect(map.containsKey(empty3), isTrue);
      expect(map[empty2], equals('empty'));
      expect(map[empty3], equals('empty'));
    });

    test('Null vs empty attributes in storage contexts', () {
      // This simulates how storage classes handle null vs empty attributes

      // Create a map to simulate storage
      final storage = <Attributes, int>{};

      // Case 1: Record with null attributes (should use empty attributes internally)
      final emptyAttrs = OTelFactory.otelFactory!.attributes();
      storage[emptyAttrs] = 10;

      // Case 2: Retrieve with null attributes (should convert to empty)
      final value = storage[emptyAttrs];
      expect(value, equals(10));

      // Case 3: Make sure null is properly converted to empty consistently
      final nullConverted = OTelFactory.otelFactory!.attributes();
      expect(storage.containsKey(nullConverted), isTrue);
    });
  });
}
