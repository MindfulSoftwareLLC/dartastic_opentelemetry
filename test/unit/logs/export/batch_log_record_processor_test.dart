// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../../testing_utils/memory_log_record_exporter.dart';

void main() {
  group('BatchLogRecordProcessor Tests', () {
    late MemoryLogRecordExporter exporter;
    late InstrumentationScope scope;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'batch-processor-test',
        detectPlatformResources: false,
      );

      exporter = MemoryLogRecordExporter();
      scope = OTel.instrumentationScope(name: 'test-scope', version: '1.0.0');
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('BatchLogRecordProcessor batches log records', () async {
      const config = BatchLogRecordProcessorConfig(
        maxExportBatchSize: 5,
        scheduleDelay:
            Duration(seconds: 10), // Long delay to prevent auto-export
      );
      final processor = BatchLogRecordProcessor(exporter, config);

      try {
        // Add 3 logs (less than batch size)
        for (int i = 0; i < 3; i++) {
          final logRecord = SDKLogRecord(
            instrumentationScope: scope,
            severityNumber: Severity.INFO,
            body: 'Message $i',
          );
          await processor.onEmit(logRecord, null);
        }

        // Force flush to export
        await processor.forceFlush();

        expect(exporter.count, equals(3));
      } finally {
        await processor.shutdown();
      }
    });

    test('BatchLogRecordProcessor queues logs until flush or timer', () async {
      const config = BatchLogRecordProcessorConfig(
        maxExportBatchSize: 3,
        scheduleDelay: Duration(seconds: 100), // Long delay - won't auto-export
      );
      final processor = BatchLogRecordProcessor(exporter, config);

      try {
        // Add logs to the queue
        for (int i = 0; i < 3; i++) {
          final logRecord = SDKLogRecord(
            instrumentationScope: scope,
            severityNumber: Severity.INFO,
            body: 'Message $i',
          );
          await processor.onEmit(logRecord, null);
        }

        // No export yet since timer hasn't fired
        expect(exporter.count, equals(0));

        // Force flush to trigger export
        await processor.forceFlush();

        expect(exporter.count, equals(3));
      } finally {
        await processor.shutdown();
      }
    });

    test('BatchLogRecordProcessor exports on schedule delay', () async {
      const config = BatchLogRecordProcessorConfig(
        maxExportBatchSize: 100, // Large batch size
        scheduleDelay: Duration(milliseconds: 100), // Short delay for testing
      );
      final processor = BatchLogRecordProcessor(exporter, config);

      try {
        final logRecord = SDKLogRecord(
          instrumentationScope: scope,
          severityNumber: Severity.INFO,
          body: 'Test message',
        );
        await processor.onEmit(logRecord, null);

        // Wait for scheduled export
        await Future<void>.delayed(const Duration(milliseconds: 250));

        expect(exporter.count, equals(1));
      } finally {
        await processor.shutdown();
      }
    });

    test('BatchLogRecordProcessor respects max queue size', () async {
      const config = BatchLogRecordProcessorConfig(
        maxQueueSize: 5,
        maxExportBatchSize: 10,
        scheduleDelay: Duration(seconds: 100), // Long delay
      );
      final processor = BatchLogRecordProcessor(exporter, config);

      try {
        // Add more logs than queue size
        for (int i = 0; i < 10; i++) {
          final logRecord = SDKLogRecord(
            instrumentationScope: scope,
            severityNumber: Severity.INFO,
            body: 'Message $i',
          );
          await processor.onEmit(logRecord, null);
        }

        await processor.forceFlush();

        // Should only have exported up to queue size
        expect(exporter.count, lessThanOrEqualTo(5));
      } finally {
        await processor.shutdown();
      }
    });

    test('BatchLogRecordProcessor shutdown exports remaining logs', () async {
      const config = BatchLogRecordProcessorConfig(
        maxExportBatchSize: 100,
        scheduleDelay: Duration(seconds: 100),
      );
      final processor = BatchLogRecordProcessor(exporter, config);

      // Add some logs
      for (int i = 0; i < 3; i++) {
        final logRecord = SDKLogRecord(
          instrumentationScope: scope,
          severityNumber: Severity.INFO,
          body: 'Message $i',
        );
        await processor.onEmit(logRecord, null);
      }

      // Shutdown should flush remaining
      await processor.shutdown();

      expect(exporter.count, equals(3));
    });

    test('BatchLogRecordProcessor does not accept logs after shutdown',
        () async {
      const config = BatchLogRecordProcessorConfig(
        maxExportBatchSize: 10,
        scheduleDelay: Duration(milliseconds: 100),
      );
      final processor = BatchLogRecordProcessor(exporter, config);

      await processor.shutdown();

      final logRecord = SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'Should not be queued',
      );
      await processor.onEmit(logRecord, null);

      // Force flush should do nothing after shutdown
      await processor.forceFlush();

      expect(exporter.count, equals(0));
    });

    test('BatchLogRecordProcessor enabled returns true by default', () {
      final processor = BatchLogRecordProcessor(exporter);

      expect(processor.enabled(), isTrue);

      processor.shutdown();
    });

    test('BatchLogRecordProcessor forceFlush exports queued logs', () async {
      const config = BatchLogRecordProcessorConfig(
        maxExportBatchSize: 100,
        scheduleDelay: Duration(seconds: 100), // Long delay
      );
      final processor = BatchLogRecordProcessor(exporter, config);

      try {
        // Add some logs
        for (int i = 0; i < 5; i++) {
          final logRecord = SDKLogRecord(
            instrumentationScope: scope,
            severityNumber: Severity.INFO,
            body: 'Message $i',
          );
          await processor.onEmit(logRecord, null);
        }

        // Force flush
        await processor.forceFlush();

        expect(exporter.count, equals(5));
      } finally {
        await processor.shutdown();
      }
    });

    test('BatchLogRecordProcessor handles concurrent emits', () async {
      const config = BatchLogRecordProcessorConfig(
        maxExportBatchSize: 100,
        scheduleDelay: Duration(milliseconds: 100),
      );
      final processor = BatchLogRecordProcessor(exporter, config);

      try {
        // Emit concurrently
        final futures = <Future<void>>[];
        for (int i = 0; i < 20; i++) {
          final logRecord = SDKLogRecord(
            instrumentationScope: scope,
            severityNumber: Severity.INFO,
            body: 'Concurrent message $i',
          );
          futures.add(processor.onEmit(logRecord, null));
        }

        await Future.wait(futures);
        await processor.forceFlush();

        expect(exporter.count, equals(20));
      } finally {
        await processor.shutdown();
      }
    });

    test('BatchLogRecordProcessor uses default values', () async {
      // Create with no explicit config to test defaults
      final processor = BatchLogRecordProcessor(exporter);

      try {
        final logRecord = SDKLogRecord(
          instrumentationScope: scope,
          severityNumber: Severity.INFO,
          body: 'Test message',
        );
        await processor.onEmit(logRecord, null);
        await processor.forceFlush();

        expect(exporter.count, equals(1));
      } finally {
        await processor.shutdown();
      }
    });

    test('BatchLogRecordProcessor handles export failure', () async {
      final failingExporter = _FailingLogRecordExporter();
      const config = BatchLogRecordProcessorConfig(
        maxExportBatchSize: 2,
        scheduleDelay: Duration(milliseconds: 100),
      );
      final processor = BatchLogRecordProcessor(failingExporter, config);

      try {
        // This should not throw even when export fails
        for (int i = 0; i < 3; i++) {
          final logRecord = SDKLogRecord(
            instrumentationScope: scope,
            severityNumber: Severity.INFO,
            body: 'Message $i',
          );
          await processor.onEmit(logRecord, null);
        }

        await expectLater(processor.forceFlush(), completes);
      } finally {
        await processor.shutdown();
      }
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
