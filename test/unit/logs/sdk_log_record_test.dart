// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('SDKLogRecord Tests', () {
    late InstrumentationScope scope;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'log-record-test',
        detectPlatformResources: false,
      );

      scope = OTel.instrumentationScope(
        name: 'test-scope',
        version: '1.0.0',
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('SDKLogRecord stores all fields correctly', () {
      final timestamp =
          Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000);
      final observedTimestamp =
          Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000);
      final attributes = OTel.attributesFromMap({'key': 'value'});
      final resource =
          OTel.resource(OTel.attributesFromMap({'service.name': 'test'}));

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        resource: resource,
        timestamp: timestamp,
        observedTimestamp: observedTimestamp,
        severityNumber: Severity.INFO,
        severityText: 'INFO',
        body: 'Test message',
        attributes: attributes,
        eventName: 'test.event',
      );

      expect(logRecord.timestamp, equals(timestamp));
      expect(logRecord.observedTimestamp, equals(observedTimestamp));
      expect(logRecord.severityNumber, equals(Severity.INFO));
      expect(logRecord.severityText, equals('INFO'));
      expect(logRecord.body, equals('Test message'));
      expect(logRecord.attributes, isNotNull);
      expect(logRecord.eventName, equals('test.event'));
      expect(logRecord.instrumentationScope, equals(scope));
      expect(logRecord.resource, equals(resource));
    });

    test('SDKLogRecord allows setting fields after construction', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
      );

      // All fields should be settable
      logRecord.timestamp = Int64(1234567890);
      logRecord.observedTimestamp = Int64(1234567891);
      logRecord.severityNumber = Severity.ERROR;
      logRecord.severityText = 'ERROR';
      logRecord.body = 'Updated body';
      logRecord.eventName = 'updated.event';

      expect(logRecord.timestamp, equals(Int64(1234567890)));
      expect(logRecord.observedTimestamp, equals(Int64(1234567891)));
      expect(logRecord.severityNumber, equals(Severity.ERROR));
      expect(logRecord.severityText, equals('ERROR'));
      expect(logRecord.body, equals('Updated body'));
      expect(logRecord.eventName, equals('updated.event'));
    });

    test('SDKLogRecord addAttribute adds new attribute', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
      );

      logRecord.addAttribute(OTel.attributeString('key1', 'value1'));

      expect(logRecord.attributes, isNotNull);
      final attrs = logRecord.attributes!.toList();
      expect(attrs.length, equals(1));
      expect(attrs.first.key, equals('key1'));
      expect(attrs.first.value, equals('value1'));
    });

    test('SDKLogRecord addAttribute appends to existing attributes', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        attributes: OTel.attributesFromMap({'existing': 'value'}),
      );

      logRecord.addAttribute(OTel.attributeString('new', 'attribute'));

      final attrs = logRecord.attributes!.toList();
      expect(attrs.length, equals(2));
    });

    test('SDKLogRecord removeAttribute removes attribute by key', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        attributes: OTel.attributesFromMap({
          'keep': 'value1',
          'remove': 'value2',
        }),
      );

      logRecord.removeAttribute('remove');

      final attrs = logRecord.attributes!.toList();
      expect(attrs.length, equals(1));
      expect(attrs.first.key, equals('keep'));
    });

    test('SDKLogRecord clone creates deep copy', () {
      final original = SDKLogRecord(
        instrumentationScope: scope,
        timestamp: Int64(12345),
        observedTimestamp: Int64(12346),
        severityNumber: Severity.WARN,
        severityText: 'WARN',
        body: 'Original body',
        attributes: OTel.attributesFromMap({'key': 'value'}),
        eventName: 'original.event',
      );

      final clone = original.clone();

      // Clone should have same values
      expect(clone.timestamp, equals(original.timestamp));
      expect(clone.observedTimestamp, equals(original.observedTimestamp));
      expect(clone.severityNumber, equals(original.severityNumber));
      expect(clone.severityText, equals(original.severityText));
      expect(clone.body, equals(original.body));
      expect(clone.eventName, equals(original.eventName));

      // Modifying clone should not affect original
      clone.body = 'Modified body';
      clone.severityNumber = Severity.ERROR;

      expect(original.body, equals('Original body'));
      expect(original.severityNumber, equals(Severity.WARN));
    });

    test('SDKLogRecord applies attribute limits', () {
      // Set a low limit for testing
      final originalLimit = SDKLogRecord.maxAttributeCount;
      SDKLogRecord.maxAttributeCount = 3;

      try {
        final attributes = OTel.attributesFromMap({
          'key1': 'value1',
          'key2': 'value2',
          'key3': 'value3',
          'key4': 'value4',
          'key5': 'value5',
        });

        final logRecord = SDKLogRecord(
          instrumentationScope: scope,
          attributes: attributes,
        );

        // Should have max 3 attributes
        expect(logRecord.attributes!.length, equals(3));
        expect(logRecord.droppedAttributesCount, equals(2));
      } finally {
        SDKLogRecord.maxAttributeCount = originalLimit;
      }
    });

    test('SDKLogRecord addAttribute respects limits', () {
      final originalLimit = SDKLogRecord.maxAttributeCount;
      SDKLogRecord.maxAttributeCount = 2;

      try {
        final logRecord = SDKLogRecord(
          instrumentationScope: scope,
          attributes: OTel.attributesFromMap({
            'key1': 'value1',
            'key2': 'value2',
          }),
        );

        // At limit, adding should increment dropped count
        logRecord.addAttribute(OTel.attributeString('key3', 'value3'));

        expect(logRecord.attributes!.length, equals(2));
        expect(logRecord.droppedAttributesCount, equals(1));
      } finally {
        SDKLogRecord.maxAttributeCount = originalLimit;
      }
    });

    test('SDKLogRecord extracts trace context from Context', () async {
      // Create a span to get trace context
      final tracer = OTel.tracer();
      final span = tracer.startSpan('test-span');

      try {
        final logRecord = SDKLogRecord(
          instrumentationScope: scope,
          context: Context.current,
        );

        // Should have trace context from the active span
        expect(logRecord.traceId, isNotNull);
        expect(logRecord.spanId, isNotNull);
        expect(logRecord.traceFlags, isNotNull);
      } finally {
        span.end();
      }
    });

    test('SDKLogRecord traceId/spanId/traceFlags are settable', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
      );

      final traceId = OTel.traceId();
      final spanId = OTel.spanId();
      final traceFlags = TraceFlags.sampled;

      logRecord.traceId = traceId;
      logRecord.spanId = spanId;
      logRecord.traceFlags = traceFlags;

      expect(logRecord.traceId, equals(traceId));
      expect(logRecord.spanId, equals(spanId));
      expect(logRecord.traceFlags, equals(traceFlags));
    });

    test('SDKLogRecord toString provides useful output', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test message',
      );

      final str = logRecord.toString();

      expect(str, contains('SDKLogRecord'));
      expect(str, contains('severity'));
      expect(str, contains('body'));
    });

    test('SDKLogRecord handles null body', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        body: null,
      );

      expect(logRecord.body, isNull);
    });

    test('SDKLogRecord handles various body types', () {
      // String body
      var logRecord = SDKLogRecord(
        instrumentationScope: scope,
        body: 'String body',
      );
      expect(logRecord.body, equals('String body'));

      // Int body
      logRecord = SDKLogRecord(
        instrumentationScope: scope,
        body: 42,
      );
      expect(logRecord.body, equals(42));

      // Map body
      logRecord = SDKLogRecord(
        instrumentationScope: scope,
        body: {'key': 'value'},
      );
      expect(logRecord.body, isA<Map<String, String>>());

      // List body
      logRecord = SDKLogRecord(
        instrumentationScope: scope,
        body: [1, 2, 3],
      );
      expect(logRecord.body, isA<List<int>>());
    });
  });
}
