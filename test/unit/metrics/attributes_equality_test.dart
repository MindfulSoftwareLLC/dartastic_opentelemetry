// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

/// Tests to ensure that attributes behave properly as Map keys
void main() {
  group('Attributes as Map keys', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        endpoint: 'http://localhost:4317',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('Attributes equality works for Map lookups', () {
      // Create two separate attribute objects with the same content
      final attrs1 = {'service': 'api'}.toAttributes();
      final attrs2 = {'service': 'api'}.toAttributes();

      // Create a map and store a value with the first attributes as key
      final map = <Attributes, int>{};
      map[attrs1] = 10;

      // Verify both can retrieve the value since they should be equal
      expect(map.containsKey(attrs1), isTrue,
          reason: "Map should contain the exact same key instance");
      expect(map.containsKey(attrs2), isTrue,
          reason: "Map should recognize equivalent keys");
      expect(map[attrs1], equals(10));
      expect(map[attrs2], equals(10));

      // Add a value with the second attributes (should overwrite)
      map[attrs2] = 20;

      // Verify both attrs1 and attrs2 return the updated value
      expect(map[attrs1], equals(20));
      expect(map[attrs2], equals(20));

      // Check that attributes with different content behave correctly
      final attrs3 = {'service': 'db'}.toAttributes();
      expect(map.containsKey(attrs3), isFalse);

      // Add different attributes
      map[attrs3] = 30;

      // Verify we now have two entries
      expect(map.length, equals(2));
      expect(map[attrs1], equals(20));
      expect(map[attrs3], equals(30));
    });

    test('Attributes equality handles empty attributes', () {
      // Two ways to create empty attributes
      final empty1 = <String, Object>{}.toAttributes();
      final empty2 = OTelFactory.otelFactory!.attributes();

      // Create a map with empty attributes as key
      final map = <Attributes, int>{};
      map[empty1] = 5;

      // Verify both empty attribute instances can retrieve the value
      expect(map.containsKey(empty2), isTrue);
      expect(map[empty2], equals(5));

      // Check that null is different from empty attributes
      // We shouldn't really use null as a key, but this is for completeness
      map[empty2] = 10;
      expect(map[empty1], equals(10));
    });

    test('Manual equality check using _findMatchingKey method', () {
      final attrs1 = {'service': 'api'}.toAttributes();
      final attrs2 = {'service': 'api'}.toAttributes();
      final attrs3 = {'service': 'db'}.toAttributes();

      final attributes = [attrs1, attrs3];

      // Simulation of our _findMatchingKey method
      Attributes? findKey(Attributes key) {
        for (final existing in attributes) {
          if (existing == key) {
            return existing;
          }
        }
        return null;
      }

      // Verify our lookup method works correctly
      expect(findKey(attrs1), equals(attrs1));
      expect(findKey(attrs2), equals(attrs1)); // attrs2 should match attrs1
      expect(findKey(attrs3), equals(attrs3));
      expect(findKey(<String, Object>{}.toAttributes()), isNull);
    });
  });
}
