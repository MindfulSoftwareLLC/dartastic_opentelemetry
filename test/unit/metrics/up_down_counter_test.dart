// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('UpDownCounter Tests', () {
    late MeterProvider meterProvider;
    late Meter meter;

    setUp(() async {
      // Initialize OpenTelemetry with test endpoint to avoid network issues
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        endpoint: 'http://localhost:4317',
        detectPlatformResources: false, // Disable for testing
      );

      // Get a meter provider and create a meter
      meterProvider = OTel.meterProvider();
      meter = meterProvider.getMeter(name: 'test-meter') as Meter;
    });

    tearDown(() async {
      // Clean up
      await meterProvider.shutdown();
      await OTel.reset();
    });

    test('Simple UpDownCounter', () {
      // Create an UpDownCounter with int type
      final counter = meter.createUpDownCounter<int>(
        name: 'test-up-down-counter',
        unit: 'items',
        description: 'A test up-down counter',
      ) as UpDownCounter<int>;

      // Verify initial value is 0
      expect(counter.getValue(), equals(0));

      // Add positive value
      counter.add(10);
      expect(counter.getValue(), equals(10));

      // Add negative value
      counter.add(-4);
      expect(counter.getValue(), equals(6)); // 10 - 4

      // Reset counter
      counter.reset();
      expect(counter.getValue(), equals(0));
    });

    test('UpDownCounter with attributes', () {
      // Create an UpDownCounter with int type
      final counter = meter.createUpDownCounter<int>(
        name: 'attr-up-down-counter',
        unit: 'items',
      ) as UpDownCounter<int>;

      // Create attributes
      final attributes1 = {'service': 'api'}.toAttributes();
      final attributes2 = {'service': 'db'}.toAttributes();

      // Reset counter
      counter.reset();

      // Add values with attributes
      counter.add(10, attributes1);
      counter.add(-4, attributes1);
      counter.add(5, attributes2);

      // Verify values with attributes
      expect(counter.getValue(attributes1), equals(6)); // 10 - 4
      expect(counter.getValue(attributes2), equals(5));
    });
  });
}
