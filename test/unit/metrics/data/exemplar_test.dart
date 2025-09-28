// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  late Attributes attributesWithMultipleEntries;
  late Attributes attributesSubset;

  setUp(() async {
    await OTel.reset();
    await OTel.initialize();

    attributesWithMultipleEntries = Attributes.of({
      'service.name': 'test-service',
      'host.name': 'test-host',
      'region': 'us-west',
      'instance.id': '12345',
      'customer.id': 'abc123',
    });

    attributesSubset = Attributes.of({
      'service.name': 'test-service',
      'host.name': 'test-host',
      'region': 'us-west',
    });
  });

  tearDown(() async {
    await OTel.shutdown();
  });

  group('Exemplar tests', () {
    test('Exemplar constructor sets properties correctly', () {
      // Create mock TraceId and SpanId for testing - using OTel API
      // We'll just use valid IDs from an active span
      final tracer = OTel.tracer();
      final span = tracer.startSpan('test-span');
      final spanContext = span.spanContext;
      final traceId = spanContext.traceId;
      final spanId = spanContext.spanId;

      final timestamp = DateTime.now();
      final attributes = Attributes.of({'key1': 'value1'});
      final filteredAttributes = Attributes.of({'key2': 'value2'});

      // Create the Exemplar
      final exemplar = Exemplar(
        attributes: attributes,
        filteredAttributes: filteredAttributes,
        timestamp: timestamp,
        value: 42.5,
        traceId: traceId,
        spanId: spanId,
      );

      // Verify properties
      expect(exemplar.attributes, equals(attributes));
      expect(exemplar.filteredAttributes, equals(filteredAttributes));
      expect(exemplar.timestamp, equals(timestamp));
      expect(exemplar.value, equals(42.5));
      expect(exemplar.traceId, equals(traceId));
      expect(exemplar.spanId, equals(spanId));

      // End the span
      span.end();
    });

    test('Exemplar.fromMeasurement creates correct exemplar', () {
      // Create trace/span ID from an active span
      final tracer = OTel.tracer();
      final span = tracer.startSpan('test-span');
      final spanContext = span.spanContext;
      final traceId = spanContext.traceId;
      final spanId = spanContext.spanId;

      // Create a measurement using factory
      final value = 123.45;
      final measurement =
          createTestMeasurement(value, attributesWithMultipleEntries);
      final timestamp = DateTime.now();

      // Create exemplar from measurement
      final exemplar = Exemplar.fromMeasurement(
        measurement: measurement,
        timestamp: timestamp,
        aggregationAttributes: attributesSubset,
        traceId: traceId,
        spanId: spanId,
      );

      // Verify basic properties are set correctly
      expect(exemplar.value, equals(123.45));
      expect(exemplar.timestamp, equals(timestamp));
      expect(exemplar.traceId, equals(traceId));
      expect(exemplar.spanId, equals(spanId));
      expect(exemplar.attributes, equals(attributesSubset));

      // Verify filtered attributes contain keys not in the aggregation attributes
      expect(exemplar.filteredAttributes.toList().length, equals(2));

      // The test is checking that the filtered attributes contain the expected attributes
      // but we can't directly access them by key, so we'll check through the list
      final filteredAttrs = exemplar.filteredAttributes.toList();
      bool foundInstanceId = false;
      bool foundCustomerId = false;

      for (var attr in filteredAttrs) {
        if (attr.key == 'instance.id' && attr.value == '12345') {
          foundInstanceId = true;
        }
        if (attr.key == 'customer.id' && attr.value == 'abc123') {
          foundCustomerId = true;
        }
      }

      expect(foundInstanceId, isTrue,
          reason: "instance.id attribute missing or wrong value");
      expect(foundCustomerId, isTrue,
          reason: "customer.id attribute missing or wrong value");

      // End the span
      span.end();
    });

    test('Exemplar._filterAttributes extracts non-aggregation attributes', () {
      // Create attributes with different sets
      final measurementAttributes = Attributes.of({
        'common1': 'value1',
        'common2': 'value2',
        'extra1': 'extraValue1',
        'extra2': 'extraValue2',
      });

      final aggregationAttributes = Attributes.of({
        'common1': 'value1',
        'common2': 'value2',
        'other': 'otherValue',
      });

      // Access the static _filterAttributes method through a factory method
      final measurement = createTestMeasurement(100, measurementAttributes);

      final exemplar = Exemplar.fromMeasurement(
        measurement: measurement,
        timestamp: DateTime.now(),
        aggregationAttributes: aggregationAttributes,
      );

      // Verify filtered attributes contain only the keys not in aggregation
      expect(exemplar.filteredAttributes.toList().length, equals(2));

      // Check filtered attributes through the list
      final filteredAttrs = exemplar.filteredAttributes.toList();
      bool foundExtra1 = false;
      bool foundExtra2 = false;

      for (var attr in filteredAttrs) {
        if (attr.key == 'extra1' && attr.value == 'extraValue1') {
          foundExtra1 = true;
        }
        if (attr.key == 'extra2' && attr.value == 'extraValue2') {
          foundExtra2 = true;
        }
      }

      expect(foundExtra1, isTrue,
          reason: "extra1 attribute missing or wrong value");
      expect(foundExtra2, isTrue,
          reason: "extra2 attribute missing or wrong value");

      // Verify excluded attributes - check they're not in the list
      bool hasCommon1 = false;
      bool hasCommon2 = false;
      bool hasOther = false;

      for (var attr in filteredAttrs) {
        if (attr.key == 'common1') hasCommon1 = true;
        if (attr.key == 'common2') hasCommon2 = true;
        if (attr.key == 'other') hasOther = true;
      }

      expect(hasCommon1, isFalse,
          reason: "common1 shouldn't be in filtered attributes");
      expect(hasCommon2, isFalse,
          reason: "common2 shouldn't be in filtered attributes");
      expect(hasOther, isFalse,
          reason: "other shouldn't be in filtered attributes");
    });

    test('Exemplar._filterAttributes handles empty attributes', () {
      // Empty measurement attributes
      final emptyMeasurementAttrs = OTelFactory.otelFactory!.attributes();
      final someAggregationAttrs = Attributes.of({'key1': 'value1'});

      final measurement1 = createTestMeasurement(100, emptyMeasurementAttrs);

      final exemplar1 = Exemplar.fromMeasurement(
        measurement: measurement1,
        timestamp: DateTime.now(),
        aggregationAttributes: someAggregationAttrs,
      );

      // Empty filtered attributes expected when measurement has no attributes
      expect(exemplar1.filteredAttributes.toList(), isEmpty);

      // Empty aggregation attributes
      final someMeasurementAttrs =
          Attributes.of({'key1': 'value1', 'key2': 'value2'});
      final emptyAggregationAttrs = OTelFactory.otelFactory!.attributes();

      final measurement2 = createTestMeasurement(100, someMeasurementAttrs);

      final exemplar2 = Exemplar.fromMeasurement(
        measurement: measurement2,
        timestamp: DateTime.now(),
        aggregationAttributes: emptyAggregationAttrs,
      );

      // All measurement attributes should be in filtered attributes when aggregation has none
      expect(exemplar2.filteredAttributes.toList().length, equals(2));

      final filteredAttrs = exemplar2.filteredAttributes.toList();
      bool foundKey1 = false;
      bool foundKey2 = false;

      for (var attr in filteredAttrs) {
        if (attr.key == 'key1' && attr.value == 'value1') {
          foundKey1 = true;
        }
        if (attr.key == 'key2' && attr.value == 'value2') {
          foundKey2 = true;
        }
      }

      expect(foundKey1, isTrue);
      expect(foundKey2, isTrue);
    });

    test('Exemplar._filterAttributes handles null measurement attributes', () {
      // Measurement with null attributes (should default to empty)
      final measurement = createTestMeasurement(100, null);

      final aggregationAttributes = Attributes.of({'key1': 'value1'});

      final exemplar = Exemplar.fromMeasurement(
        measurement: measurement,
        timestamp: DateTime.now(),
        aggregationAttributes: aggregationAttributes,
      );

      // Should have empty filtered attributes
      expect(exemplar.filteredAttributes.toList(), isEmpty);
    });

    test('Exemplar fromMeasurement handles all attribute types', () {
      // Create attributes with various types
      final measurementAttributes = Attributes.of({
        'string': 'value',
        'int': 123,
        'double': 123.45,
        'bool': true,
        'stringArray': ['a', 'b', 'c'],
        'intArray': [1, 2, 3],
        'doubleArray': [1.1, 2.2, 3.3],
        'boolArray': [true, false, true],
      });

      final aggregationAttributes = Attributes.of({
        'string': 'value',
        'int': 123,
      });

      // Create measurement and exemplar
      final measurement = createTestMeasurement(100, measurementAttributes);

      final exemplar = Exemplar.fromMeasurement(
        measurement: measurement,
        timestamp: DateTime.now(),
        aggregationAttributes: aggregationAttributes,
      );

      // Verify filtered attributes contain all non-aggregation attributes with correct types
      expect(exemplar.filteredAttributes.toList().length, equals(6));

      // Check for attributes by type
      final filteredAttrs = exemplar.filteredAttributes.toList();
      bool foundDouble = false;
      bool foundBool = false;
      bool foundStringArray = false;
      bool foundIntArray = false;
      bool foundDoubleArray = false;
      bool foundBoolArray = false;

      for (var attr in filteredAttrs) {
        if (attr.key == 'double' && attr.value == 123.45) {
          foundDouble = true;
        }
        if (attr.key == 'bool' && attr.value == true) {
          foundBool = true;
        }
        if (attr.key == 'stringArray' &&
            attr.value is List &&
            listEquals(attr.value as List, ['a', 'b', 'c'])) {
          foundStringArray = true;
        }
        if (attr.key == 'intArray' &&
            attr.value is List &&
            listEquals(attr.value as List, [1, 2, 3])) {
          foundIntArray = true;
        }
        if (attr.key == 'doubleArray' &&
            attr.value is List &&
            listEquals(attr.value as List, [1.1, 2.2, 3.3])) {
          foundDoubleArray = true;
        }
        if (attr.key == 'boolArray' &&
            attr.value is List &&
            listEquals(attr.value as List, [true, false, true])) {
          foundBoolArray = true;
        }
      }

      expect(foundDouble, isTrue);
      expect(foundBool, isTrue);
      expect(foundStringArray, isTrue);
      expect(foundIntArray, isTrue);
      expect(foundDoubleArray, isTrue);
      expect(foundBoolArray, isTrue);
    });
  });
}

// Helper function to create a test Measurement
Measurement createTestMeasurement(num value, Attributes? attributes) {
  final meter = OTel.meter('test-meter');
  final counter = meter.createCounter<int>(name: 'test_counter');

  if (attributes != null) {
    counter.add(value.toInt(), attributes);
  } else {
    counter.add(value.toInt());
  }

  // Access the last recorded measurement (for testing purposes only)
  // In a real implementation, you'd get this from the SDK internals
  return MockMeasurement(
      value: value,
      attributes: attributes ?? OTelFactory.otelFactory!.attributes());
}

// Mock Measurement class for testing
class MockMeasurement implements Measurement {
  @override
  final num value;

  @override
  final Attributes? attributes;

  MockMeasurement({required this.value, this.attributes});

  @override
  // TODO: implement hasAttributes
  bool get hasAttributes => attributes != null && attributes!.length > 0;
}

// Helper for comparing lists
bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
