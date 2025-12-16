// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpLogRecordTransformer Tests', () {
    late InstrumentationScope scope;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'transformer-test',
        detectPlatformResources: false,
      );

      scope = OTel.instrumentationScope(name: 'test-scope', version: '1.0.0');
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('transforms empty list correctly', () {
      final request = OtlpLogRecordTransformer.transformLogRecords([]);

      expect(request.resourceLogs, isEmpty);
    });

    test('transforms single log record correctly', () {
      final resource = OTel.resource(OTel.attributesFromMap({
        'service.name': 'test-service',
      }));

      final timestamp = Int64(1234567890000000);
      final observedTimestamp = Int64(1234567891000000);

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        resource: resource,
        timestamp: timestamp,
        observedTimestamp: observedTimestamp,
        severityNumber: Severity.INFO,
        severityText: 'INFO',
        body: 'Test message',
        attributes: OTel.attributesFromMap({'key': 'value'}),
        eventName: 'test.event',
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);

      expect(request.resourceLogs.length, equals(1));
      expect(request.resourceLogs.first.scopeLogs.length, equals(1));
      expect(request.resourceLogs.first.scopeLogs.first.logRecords.length,
          equals(1));

      final otlpLog =
          request.resourceLogs.first.scopeLogs.first.logRecords.first;
      expect(otlpLog.timeUnixNano, equals(timestamp));
      expect(otlpLog.observedTimeUnixNano, equals(observedTimestamp));
      expect(otlpLog.severityText, equals('INFO'));
      expect(otlpLog.body.stringValue, equals('Test message'));
    });

    test('transforms severity levels correctly', () {
      final severities = [
        Severity.TRACE,
        Severity.DEBUG,
        Severity.INFO,
        Severity.WARN,
        Severity.ERROR,
        Severity.FATAL,
      ];

      for (final severity in severities) {
        final logRecord = SDKLogRecord(
          instrumentationScope: scope,
          severityNumber: severity,
          body: 'Test',
        );

        final request =
            OtlpLogRecordTransformer.transformLogRecords([logRecord]);
        final otlpLog =
            request.resourceLogs.first.scopeLogs.first.logRecords.first;

        // Verify severity number is set
        expect(otlpLog.severityNumber.value, isNonZero);
      }
    });

    test('transforms attributes correctly', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test',
        attributes: OTel.attributesFromMap({
          'string_attr': 'string_value',
          'int_attr': 42,
          'double_attr': 3.14,
          'bool_attr': true,
        }),
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);
      final otlpLog =
          request.resourceLogs.first.scopeLogs.first.logRecords.first;

      expect(otlpLog.attributes.length, equals(4));

      // Verify each attribute type
      final stringAttr =
          otlpLog.attributes.firstWhere((a) => a.key == 'string_attr');
      expect(stringAttr.value.stringValue, equals('string_value'));

      final intAttr = otlpLog.attributes.firstWhere((a) => a.key == 'int_attr');
      expect(intAttr.value.intValue, equals(Int64(42)));

      final doubleAttr =
          otlpLog.attributes.firstWhere((a) => a.key == 'double_attr');
      expect(doubleAttr.value.doubleValue, equals(3.14));

      final boolAttr =
          otlpLog.attributes.firstWhere((a) => a.key == 'bool_attr');
      expect(boolAttr.value.boolValue, isTrue);
    });

    test('transforms string body correctly', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'String body',
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);
      final otlpLog =
          request.resourceLogs.first.scopeLogs.first.logRecords.first;

      expect(otlpLog.body.stringValue, equals('String body'));
    });

    test('transforms int body correctly', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 42,
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);
      final otlpLog =
          request.resourceLogs.first.scopeLogs.first.logRecords.first;

      expect(otlpLog.body.intValue, equals(Int64(42)));
    });

    test('transforms double body correctly', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 3.14,
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);
      final otlpLog =
          request.resourceLogs.first.scopeLogs.first.logRecords.first;

      expect(otlpLog.body.doubleValue, equals(3.14));
    });

    test('transforms bool body correctly', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: true,
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);
      final otlpLog =
          request.resourceLogs.first.scopeLogs.first.logRecords.first;

      expect(otlpLog.body.boolValue, isTrue);
    });

    test('transforms list body correctly', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: ['a', 'b', 'c'],
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);
      final otlpLog =
          request.resourceLogs.first.scopeLogs.first.logRecords.first;

      expect(otlpLog.body.arrayValue.values.length, equals(3));
    });

    test('transforms map body correctly', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: {'key1': 'value1', 'key2': 'value2'},
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);
      final otlpLog =
          request.resourceLogs.first.scopeLogs.first.logRecords.first;

      expect(otlpLog.body.kvlistValue.values.length, equals(2));
    });

    test('transforms trace context correctly', () {
      final traceId = OTel.traceId();
      final spanId = OTel.spanId();
      final traceFlags = TraceFlags.sampled;

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test',
      );
      logRecord.traceId = traceId;
      logRecord.spanId = spanId;
      logRecord.traceFlags = traceFlags;

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);
      final otlpLog =
          request.resourceLogs.first.scopeLogs.first.logRecords.first;

      expect(otlpLog.traceId, equals(traceId.bytes));
      expect(otlpLog.spanId, equals(spanId.bytes));
      expect(otlpLog.flags, equals(traceFlags.asByte));
    });

    test('transforms dropped attributes count correctly', () {
      final originalLimit = SDKLogRecord.maxAttributeCount;
      SDKLogRecord.maxAttributeCount = 2;

      try {
        final logRecord = SDKLogRecord(
          instrumentationScope: scope,
          severityNumber: Severity.INFO,
          body: 'Test',
          attributes: OTel.attributesFromMap({
            'key1': 'value1',
            'key2': 'value2',
            'key3': 'value3',
            'key4': 'value4',
          }),
        );

        final request =
            OtlpLogRecordTransformer.transformLogRecords([logRecord]);
        final otlpLog =
            request.resourceLogs.first.scopeLogs.first.logRecords.first;

        expect(otlpLog.droppedAttributesCount, equals(2));
      } finally {
        SDKLogRecord.maxAttributeCount = originalLimit;
      }
    });

    test('groups logs by resource', () {
      final resource1 = OTel.resource(OTel.attributesFromMap({
        'service.name': 'service-1',
      }));
      final resource2 = OTel.resource(OTel.attributesFromMap({
        'service.name': 'service-2',
      }));

      final logRecords = [
        SDKLogRecord(
          instrumentationScope: scope,
          resource: resource1,
          severityNumber: Severity.INFO,
          body: 'Service 1 log',
        ),
        SDKLogRecord(
          instrumentationScope: scope,
          resource: resource2,
          severityNumber: Severity.INFO,
          body: 'Service 2 log',
        ),
      ];

      final request = OtlpLogRecordTransformer.transformLogRecords(logRecords);

      // Should have 2 resource logs groups
      expect(request.resourceLogs.length, equals(2));
    });

    test('groups logs by instrumentation scope', () {
      final scope1 =
          OTel.instrumentationScope(name: 'scope-1', version: '1.0.0');
      final scope2 =
          OTel.instrumentationScope(name: 'scope-2', version: '1.0.0');

      final resource = OTel.resource(OTel.attributesFromMap({
        'service.name': 'test-service',
      }));

      final logRecords = [
        SDKLogRecord(
          instrumentationScope: scope1,
          resource: resource,
          severityNumber: Severity.INFO,
          body: 'Scope 1 log',
        ),
        SDKLogRecord(
          instrumentationScope: scope2,
          resource: resource,
          severityNumber: Severity.INFO,
          body: 'Scope 2 log',
        ),
      ];

      final request = OtlpLogRecordTransformer.transformLogRecords(logRecords);

      // Should have 1 resource logs with 2 scope logs
      expect(request.resourceLogs.length, equals(1));
      expect(request.resourceLogs.first.scopeLogs.length, equals(2));
    });

    test('transforms instrumentation scope correctly', () {
      final scopeWithAttrs = OTel.instrumentationScope(
        name: 'my-library',
        version: '2.0.0',
        schemaUrl: 'https://example.com/schema',
      );

      final logRecord = SDKLogRecord(
        instrumentationScope: scopeWithAttrs,
        severityNumber: Severity.INFO,
        body: 'Test',
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);
      final scopeLogs = request.resourceLogs.first.scopeLogs.first;

      expect(scopeLogs.scope.name, equals('my-library'));
      expect(scopeLogs.scope.version, equals('2.0.0'));
    });

    test('transforms resource attributes correctly', () {
      final resource = OTel.resource(OTel.attributesFromMap({
        'service.name': 'test-service',
        'service.version': '1.0.0',
        'deployment.environment': 'production',
      }));

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        resource: resource,
        severityNumber: Severity.INFO,
        body: 'Test',
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);
      final protoResource = request.resourceLogs.first.resource;

      expect(protoResource.attributes.length, equals(3));
    });

    test('handles null body', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: null,
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);

      // Should not throw and should complete
      expect(request.resourceLogs.length, equals(1));
    });

    test('handles missing optional fields', () {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
      );

      final request = OtlpLogRecordTransformer.transformLogRecords([logRecord]);

      // Should not throw
      expect(request.resourceLogs.length, equals(1));
    });
  });
}
