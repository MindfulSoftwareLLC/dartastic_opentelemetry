// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('SumStorage Tests', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        endpoint: 'http://localhost:4317',
        detectPlatformResources: false, // Disable for testing
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('SumStorage with integers', () {
      final storage = SumStorage<int>(isMonotonic: true);

      // Create attributes
      final attributes1 = {'service': 'api'}.toAttributes();
      final attributes2 = {'service': 'db'}.toAttributes();

      // Record values with attributes
      storage.record(5, attributes1);
      storage.record(10, attributes2);

      // Verify values are correctly retrieved
      expect(storage.getValue(attributes1), equals(5));
      expect(storage.getValue(attributes2), equals(10));

      // Add more to the same attributes
      storage.record(3, attributes1);

      // Verify accumulated values
      expect(storage.getValue(attributes1), equals(8)); // 5 + 3
      expect(storage.getValue(attributes2), equals(10)); // unchanged

      // Create empty attributes for specific testing
      final emptyAttributes = OTel.attributes();

      // Check that empty attributes are handled correctly
      storage.record(15, emptyAttributes);
      expect(storage.getValue(emptyAttributes), equals(15));
      expect(storage.getValue(attributes1), equals(8)); // unchanged
      expect(storage.getValue(attributes2), equals(10)); // unchanged

      // Verify the sum across all attribute sets
      expect(storage.getValue(), equals(33)); // 8 + 10 + 15
    });

    test('SumStorage with doubles', () {
      final storage = SumStorage<double>(isMonotonic: true);

      // Create attributes
      final attributes1 = {'service': 'api'}.toAttributes();
      final attributes2 = {'service': 'db'}.toAttributes();

      // Record values with attributes
      storage.record(5.5, attributes1);
      storage.record(10.25, attributes2);

      // Verify values are correctly retrieved
      expect(storage.getValue(attributes1), equals(5.5));
      expect(storage.getValue(attributes2), equals(10.25));

      // Add more to the same attributes
      storage.record(3.25, attributes1);

      // Verify accumulated values
      expect(storage.getValue(attributes1), equals(8.75)); // 5.5 + 3.25
      expect(storage.getValue(attributes2), equals(10.25)); // unchanged
    });

    test('SumStorage non-monotonic (UpDownCounter)', () {
      final storage = SumStorage<int>(isMonotonic: false);

      // Create attributes
      final attributes1 = {'service': 'api'}.toAttributes();

      // Record positive value
      storage.record(10, attributes1);
      expect(storage.getValue(attributes1), equals(10));

      // Record negative value
      storage.record(-4, attributes1);
      expect(storage.getValue(attributes1), equals(6)); // 10 - 4
    });
  });
}
