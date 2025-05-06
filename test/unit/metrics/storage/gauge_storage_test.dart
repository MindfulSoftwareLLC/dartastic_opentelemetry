// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('GaugeStorage Tests', () {
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

    test('GaugeStorage with integers', () {
      final storage = GaugeStorage<int>();

      // Create attributes
      final attributes1 = {'service': 'api'}.toAttributes();
      final attributes2 = {'service': 'db'}.toAttributes();

      // Record values with attributes
      storage.record(5, attributes1);
      storage.record(10, attributes2);

      // Verify values are correctly retrieved
      expect(storage.getValue(attributes1), equals(5));
      expect(storage.getValue(attributes2), equals(10));

      // Update values
      storage.record(8, attributes1);

      // Verify values are replaced, not accumulated
      expect(storage.getValue(attributes1), equals(8)); // replaced with 8
      expect(storage.getValue(attributes2), equals(10)); // unchanged

      // Check that null attributes are handled separately
      storage.record(15);
      expect(storage.getValue(), equals(15));
      expect(storage.getValue(attributes1), equals(8)); // unchanged
      expect(storage.getValue(attributes2), equals(10)); // unchanged
    });

    test('GaugeStorage with doubles', () {
      final storage = GaugeStorage<double>();

      // Create attributes
      final attributes1 = {'service': 'api'}.toAttributes();
      final attributes2 = {'service': 'db'}.toAttributes();

      // Record values with attributes
      storage.record(5.5, attributes1);
      storage.record(10.25, attributes2);

      // Verify values are correctly retrieved
      expect(storage.getValue(attributes1), equals(5.5));
      expect(storage.getValue(attributes2), equals(10.25));

      // Update values
      storage.record(8.75, attributes1);

      // Verify values are replaced, not accumulated
      expect(storage.getValue(attributes1), equals(8.75));
      expect(storage.getValue(attributes2), equals(10.25)); // unchanged
    });

    test('GaugeStorage collectPoints returns correct points', () {
      final storage = GaugeStorage<double>();
      final attributes1 = {'service': 'api'}.toAttributes();
      final attributes2 = {'service': 'db'}.toAttributes();

      // Record some values
      storage.record(5.5, attributes1);
      storage.record(10.25, attributes2);

      // Collect points
      final points = storage.collectPoints();

      // Verify the points
      expect(points.length, equals(2));

      // Find point with attributes1
      final point1 = points.firstWhere(
        (point) => point.attributes == attributes1,
        orElse: () => throw StateError('Point with attributes1 not found'),
      );
      expect(point1.value, equals(5.5));

      // Find point with attributes2
      final point2 = points.firstWhere(
        (point) => point.attributes == attributes2,
        orElse: () => throw StateError('Point with attributes2 not found'),
      );
      expect(point2.value, equals(10.25));
    });

    test('GaugeStorage reset clears all points', () {
      final storage = GaugeStorage<double>();
      final attributes1 = {'service': 'api'}.toAttributes();
      final attributes2 = {'service': 'db'}.toAttributes();

      // Record some values
      storage.record(5.5, attributes1);
      storage.record(10.25, attributes2);

      // Verify we have two points
      expect(storage.collectPoints().length, equals(2));

      // Reset the storage
      storage.reset();

      // Verify the storage is empty
      expect(storage.collectPoints().length, equals(0));
      expect(storage.getValue(attributes1), equals(0.0)); // Default value
      expect(storage.getValue(attributes2), equals(0.0)); // Default value
    });

    test('GaugeStorage addExemplar adds exemplars to points', () {
      final storage = GaugeStorage<double>();
      final attributes1 = {'service': 'api'}.toAttributes();

      // Record a value
      storage.record(5.5, attributes1);

      // Create an exemplar
      final traceId = OTel.traceId();
      final spanId = OTel.spanId();
      final exemplar = Exemplar(
        value: 5.5,
        timestamp: DateTime.now(),
        traceId: traceId,
        spanId: spanId,
        attributes: {'request.id': '123'}.toAttributes(),
        filteredAttributes: OTel.attributes(),
      );

      // Add the exemplar
      storage.addExemplar(exemplar, attributes1);

      // Collect points and verify exemplar was added
      final points = storage.collectPoints();
      expect(points.length, equals(1));
      expect(points.first.exemplars!.length, equals(1));
      expect(points.first.exemplars!.first.value, equals(5.5));
      expect(points.first.exemplars!.first.traceId, equals(traceId));
      expect(points.first.exemplars!.first.spanId, equals(spanId));
    });
  });
}
