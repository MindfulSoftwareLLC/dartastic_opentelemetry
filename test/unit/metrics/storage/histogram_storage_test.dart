// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('HistogramStorage Tests', () {
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

    test('HistogramStorage with double values', () {
      // Create a histogram with default boundaries
      final storage = HistogramStorage<double>(boundaries: [0.0, 10.0, 100.0, 1000.0]);

      // Create attributes
      final attributes1 = {'service': 'api'}.toAttributes();
      final attributes2 = {'service': 'db'}.toAttributes();

      // Record values with attributes
      storage.record(5.5, attributes1);
      storage.record(10.25, attributes2);
      storage.record(15.75, attributes1);
      storage.record(20.0, attributes2);

      // Record values without attributes
      storage.record(30.0);
      storage.record(40.0);

      // Collect points to verify data
      final points = storage.collectPoints();

      // We should have three points (one for each attribute set, including null)
      expect(points.length, equals(3));

      // Find each point by attributes
      final point1 = points.firstWhere(
        (point) => point.attributes == attributes1,
        orElse: () => throw StateError('Point with attributes1 not found'),
      );
      final point2 = points.firstWhere(
        (point) => point.attributes == attributes2,
        orElse: () => throw StateError('Point with attributes2 not found'),
      );
      final point3 = points.firstWhere(
        (point) => point.attributes == OTelFactory.otelFactory!.attributes(),
        orElse: () => throw StateError('Point with null attributes not found'),
      );

      final histogramValue1 = point1.histogram();
      final histogramValue2 = point2.histogram();
      final histogramValue3 = point3.histogram();

      // Verify histogram data for point1 (attributes1)
      expect(histogramValue1.sum, equals(21.25)); // 5.5 + 15.75
      expect(histogramValue1.count, equals(2));

      // Verify histogram data for point2 (attributes2)
      expect(histogramValue2.sum, equals(30.25)); // 10.25 + 20.0
      expect(histogramValue2.count, equals(2));

      // Verify histogram data for point3 (null attributes)
      expect(histogramValue3.sum, equals(70.0)); // 30.0 + 40.0
      expect(histogramValue3.count, equals(2));
    });

    test('HistogramStorage with custom boundaries', () {
      // Create a histogram with custom boundaries
      final boundaries = [10.0, 20.0, 50.0, 100.0];
      final storage = HistogramStorage<double>(boundaries: boundaries);

      // Record values that fall into different buckets
      storage.record(5.0);   // Bucket 0 (≤10)
      storage.record(15.0);  // Bucket 1 (>10, ≤20)
      storage.record(30.0);  // Bucket 2 (>20, ≤50)
      storage.record(75.0);  // Bucket 3 (>50, ≤100)
      storage.record(120.0); // Bucket 4 (>100)

      // Collect points to verify
      final points = storage.collectPoints();
      expect(points.length, equals(1));

      final point = points.first;

      final histogramValue = point.histogram();

      // Verify sum and count
      expect(histogramValue.sum, equals(245.0)); // 5 + 15 + 30 + 75 + 120
      expect(histogramValue.count, equals(5));

      // Verify bucket counts
      // The buckets should have counts: [1, 1, 1, 1, 1]
      // Bucket 0: 1 value (5.0)
      // Bucket 1: 1 value (15.0)
      // Bucket 2: 1 value (30.0)
      // Bucket 3: 1 value (75.0)
      // Bucket 4: 1 value (120.0)
      expect(histogramValue.bucketCounts.length, equals(boundaries.length + 1));
      expect(histogramValue.bucketCounts[0], equals(1)); // ≤10
      expect(histogramValue.bucketCounts[1], equals(1)); // >10, ≤20
      expect(histogramValue.bucketCounts[2], equals(1)); // >20, ≤50
      expect(histogramValue.bucketCounts[3], equals(1)); // >50, ≤100
      expect(histogramValue.bucketCounts[4], equals(1)); // >100
    });

    test('HistogramStorage reset clears all data', () {
      final storage = HistogramStorage<double>(boundaries: [0.0, 10.0, 100.0]);
      final attributes = {'service': 'api'}.toAttributes();

      // Record some values
      storage.record(5.0, attributes);
      storage.record(10.0, attributes);
      storage.record(15.0);

      // Verify we have data
      expect(storage.collectPoints().length, equals(2));

      // Reset the storage
      storage.reset();

      // Verify the storage is empty
      expect(storage.collectPoints().length, equals(0));
    });

    test('HistogramStorage with integer values', () {
      final storage = HistogramStorage<int>(boundaries: [0.0, 10.0, 20.0]);
      final attributes = {'service': 'api'}.toAttributes();

      // Record integer values
      storage.record(5, attributes);
      storage.record(10, attributes);
      storage.record(15, attributes);

      // Collect points to verify
      final points = storage.collectPoints();
      expect(points.length, equals(1));

      final point = points.first;
      final histogramValue = point.histogram();
      expect(histogramValue.sum, equals(30.0)); // 5 + 10 + 15, but as double
      expect(histogramValue.count, equals(3));
    });

    test('HistogramStorage with exemplars', () {
      final storage = HistogramStorage<double>(boundaries: [0.0, 10.0, 20.0]);
      final attributes = {'service': 'api'}.toAttributes();

      // Record a value
      storage.record(15.0, attributes);

      // Create an exemplar
      final traceId = OTel.traceId();
      final spanId = OTel.spanId();
      final exemplar = Exemplar(
        value: 15.0,
        timestamp: DateTime.now(),
        traceId: traceId,
        spanId: spanId,
        attributes: {'request.id': '123'}.toAttributes(),
        filteredAttributes: OTel.attributes(),
      );

      // Add the exemplar
      storage.addExemplar(exemplar, attributes);

      // Collect points and verify exemplar was added
      final points = storage.collectPoints();
      expect(points.length, equals(1));
      expect(points.first.exemplars!.length, equals(1));
      expect(points.first.exemplars!.first.value, equals(15.0));
      expect(points.first.exemplars!.first.traceId, equals(traceId));
      expect(points.first.exemplars!.first.spanId, equals(spanId));
    });
  });
}
