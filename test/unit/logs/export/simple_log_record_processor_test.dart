// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../../testing_utils/memory_log_record_exporter.dart';

void main() {
  group('SimpleLogRecordProcessor Tests', () {
    late MemoryLogRecordExporter exporter;
    late SimpleLogRecordProcessor processor;
    late InstrumentationScope scope;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'simple-processor-test',
        detectPlatformResources: false,
      );

      exporter = MemoryLogRecordExporter();
      processor = SimpleLogRecordProcessor(exporter);
      scope = OTel.instrumentationScope(name: 'test-scope', version: '1.0.0');
    });

    tearDown(() async {
      await processor.shutdown();
      await OTel.shutdown();
      await OTel.reset();
    });

    test('SimpleLogRecordProcessor exports log records immediately', () async {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test message',
      );

      await processor.onEmit(logRecord, null);

      expect(exporter.count, equals(1));
      expect(exporter.exportedLogRecords.first.body, equals('Test message'));
    });

    test('SimpleLogRecordProcessor exports multiple log records', () async {
      for (int i = 0; i < 5; i++) {
        final logRecord = SDKLogRecord(
          instrumentationScope: scope,
          severityNumber: Severity.INFO,
          body: 'Message $i',
        );
        await processor.onEmit(logRecord, null);
      }

      expect(exporter.count, equals(5));
    });

    test('SimpleLogRecordProcessor enabled returns true by default', () {
      expect(processor.enabled(), isTrue);
    });

    test('SimpleLogRecordProcessor shutdown stops processing', () async {
      await processor.shutdown();

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Should not be exported',
      );

      await processor.onEmit(logRecord, null);

      // Should not export after shutdown
      expect(exporter.count, equals(0));
    });

    test('SimpleLogRecordProcessor forceFlush calls exporter forceFlush',
        () async {
      // forceFlush should complete without error
      await expectLater(processor.forceFlush(), completes);
    });

    test('SimpleLogRecordProcessor handles export failure gracefully',
        () async {
      // Create a failing exporter
      final failingExporter = _FailingLogRecordExporter();
      final failingProcessor = SimpleLogRecordProcessor(failingExporter);

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test message',
      );

      // Should not throw
      await expectLater(
        failingProcessor.onEmit(logRecord, null),
        completes,
      );
    });

    test('SimpleLogRecordProcessor passes context to exporter', () async {
      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Test message',
      );

      final context = Context.current;
      await processor.onEmit(logRecord, context);

      expect(exporter.count, equals(1));
    });
  });
}

/// A log record exporter that always fails for testing error handling.
class _FailingLogRecordExporter implements LogRecordExporter {
  @override
  Future<ExportResult> export(List<ReadableLogRecord> logRecords) async {
    return ExportResult.failure;
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}
