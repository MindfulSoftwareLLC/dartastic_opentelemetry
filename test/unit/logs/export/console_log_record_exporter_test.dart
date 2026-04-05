// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleLogRecordExporter Tests', () {
    late InstrumentationScope scope;
    late List<String> printedLines;
    late ConsoleLogRecordExporter exporter;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'console-exporter-test',
        detectPlatformResources: false,
      );

      scope = OTel.instrumentationScope(name: 'test-scope', version: '1.0.0');
      printedLines = [];
      exporter = ConsoleLogRecordExporter(
        printFunction: (line) => printedLines.add(line),
      );
    });

    tearDown(() async {
      await exporter.shutdown();
      await OTel.shutdown();
      await OTel.reset();
    });

    test('ConsoleLogRecordExporter exports log records', () async {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        severityText: 'INFO',
        body: 'Test message',
        observedTimestamp:
            Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
      );

      final result = await exporter.export([logRecord]);

      expect(result, equals(ExportResult.success));
      expect(printedLines.length, equals(1));
      expect(printedLines.first, contains('Test message'));
    });

    test('ConsoleLogRecordExporter formats timestamp', () async {
      final timestamp = DateTime.utc(2024, 1, 15, 12, 30, 45);
      final timestampNanos =
          Int64(timestamp.microsecondsSinceEpoch) * Int64(1000);

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test',
        observedTimestamp: timestampNanos,
      );

      await exporter.export([logRecord]);

      expect(printedLines.first, contains('2024-01-15'));
    });

    test('ConsoleLogRecordExporter formats severity', () async {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.ERROR,
        severityText: 'ERROR',
        body: 'Error message',
        observedTimestamp:
            Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
      );

      await exporter.export([logRecord]);

      expect(printedLines.first, contains('[ERROR]'));
    });

    test('ConsoleLogRecordExporter formats instrumentation scope', () async {
      final logRecord = SDKLogRecord(
        instrumentationScope: OTel.instrumentationScope(
          name: 'my-library',
          version: '2.0.0',
        ),
        severityNumber: Severity.INFO,
        body: 'Test',
        observedTimestamp:
            Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
      );

      await exporter.export([logRecord]);

      expect(printedLines.first, contains('[my-library:2.0.0]'));
    });

    test('ConsoleLogRecordExporter formats event name', () async {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test',
        eventName: 'user.login',
        observedTimestamp:
            Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
      );

      await exporter.export([logRecord]);

      expect(printedLines.first, contains('{user.login}'));
    });

    test('ConsoleLogRecordExporter formats trace context', () async {
      final traceId = OTel.traceId();
      final spanId = OTel.spanId();

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test',
        observedTimestamp:
            Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
      );
      logRecord.traceId = traceId;
      logRecord.spanId = spanId;

      await exporter.export([logRecord]);

      expect(printedLines.first, contains('trace_id='));
      expect(printedLines.first, contains('span_id='));
    });

    test('ConsoleLogRecordExporter formats attributes', () async {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test',
        attributes: OTel.attributesFromMap({
          'key1': 'value1',
          'key2': 42,
        }),
        observedTimestamp:
            Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
      );

      await exporter.export([logRecord]);

      expect(printedLines.first, contains('key1=value1'));
      expect(printedLines.first, contains('key2=42'));
    });

    test('ConsoleLogRecordExporter formats resource service name', () async {
      final resource = OTel.resource(OTel.attributesFromMap({
        'service.name': 'my-service',
      }));

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        resource: resource,
        severityNumber: Severity.INFO,
        body: 'Test',
        observedTimestamp:
            Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
      );

      await exporter.export([logRecord]);

      expect(printedLines.first, contains('service=my-service'));
    });

    test('ConsoleLogRecordExporter exports multiple log records', () async {
      final logRecords = [
        SDKLogRecord(
          instrumentationScope: scope,
          severityNumber: Severity.INFO,
          body: 'Message 1',
          observedTimestamp:
              Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
        ),
        SDKLogRecord(
          instrumentationScope: scope,
          severityNumber: Severity.WARN,
          body: 'Message 2',
          observedTimestamp:
              Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
        ),
        SDKLogRecord(
          instrumentationScope: scope,
          severityNumber: Severity.ERROR,
          body: 'Message 3',
          observedTimestamp:
              Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
        ),
      ];

      final result = await exporter.export(logRecords);

      expect(result, equals(ExportResult.success));
      expect(printedLines.length, equals(3));
    });

    test('ConsoleLogRecordExporter returns failure after shutdown', () async {
      await exporter.shutdown();

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test',
      );

      final result = await exporter.export([logRecord]);

      expect(result, equals(ExportResult.failure));
      expect(printedLines.isEmpty, isTrue);
    });

    test('ConsoleLogRecordExporter forceFlush completes successfully',
        () async {
      await expectLater(exporter.forceFlush(), completes);
    });

    test('ConsoleLogRecordExporter uses default print function', () async {
      // Create exporter without custom print function
      final defaultExporter = ConsoleLogRecordExporter();

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test',
        observedTimestamp:
            Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
      );

      // This should not throw
      final result = await defaultExporter.export([logRecord]);
      expect(result, equals(ExportResult.success));

      await defaultExporter.shutdown();
    });

    test('ConsoleLogRecordExporter handles null body', () async {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: null,
        observedTimestamp:
            Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000),
      );

      final result = await exporter.export([logRecord]);

      expect(result, equals(ExportResult.success));
      // Should still print something even with null body
      expect(printedLines.length, equals(1));
    });

    test('ConsoleLogRecordExporter handles missing timestamp', () async {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'No timestamp',
      );

      final result = await exporter.export([logRecord]);

      expect(result, equals(ExportResult.success));
      expect(printedLines.length, equals(1));
    });
  });
}
