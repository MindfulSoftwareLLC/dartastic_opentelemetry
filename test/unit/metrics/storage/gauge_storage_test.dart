// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/metrics/exemplar_filter.dart';
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
    test('retains sampled exemplar if followed by unsampled record', () {
      final storage =
          GaugeStorage<int>(); // uses default TraceBasedExemplarFilter
      final attributes = Attributes.of({'k': 'v'});

      final tracer = OTel.tracer();
      final span = tracer.startSpan('test-span');
      final sampledContext = Context.current.withSpan(span);
      final unsampledContext = Context.current; // No active span

      // Record a sampled measurement
      storage.record(10, attributes, sampledContext);

      // Record an unsampled measurement
      storage.record(20, attributes, unsampledContext);

      final points = storage.collectPoints();
      expect(points.length, equals(1));

      // Value should be latest (20)
      expect(points.first.value, equals(20));

      // Exemplar should be from the sampled measurement (value 10)
      final exemplars = points.first.exemplars!;
      expect(exemplars.length, equals(1));
      expect(exemplars.first.value, equals(10));
      expect(exemplars.first.traceId, equals(span.spanContext.traceId));

      span.end();
    });

    test('reservoir survives across multiple record calls', () {
      // Create a filter that accepts everything
      final storage = GaugeStorage<int>(exemplarFilter: _AlwaysSampleFilter());
      final attributes = Attributes.of({});
      final context = Context.current;

      // First record
      storage.record(10, attributes, context);

      // Second record (reservoir should be reused, not recreated)
      storage.record(20, attributes, context);

      final points = storage.collectPoints();
      expect(points.length, equals(1));

      // The reservoir size is 1, so it only retains 1 exemplar.
      // Depending on SimpleFixedSizeExemplarReservoir random, it might keep 10 or 20,
      // but it MUST keep at least one. If reservoir was recreated every time, it would
      // always keep the last one.
      expect(points.first.exemplars!.length, equals(1));

      // Collecting points should have called collectAndReset.
      // If we record another value now, the reservoir should have been cleared.
      storage.record(30, attributes, context);
      final nextPoints = storage.collectPoints();
      expect(nextPoints.length, equals(1));
      expect(nextPoints.first.exemplars!.length, equals(1));
      expect(nextPoints.first.exemplars!.first.value, equals(30));
    });
  });
}

class _AlwaysSampleFilter implements ExemplarFilter {
  @override
  bool shouldSample(num value, Attributes attributes, Context context) => true;
}
