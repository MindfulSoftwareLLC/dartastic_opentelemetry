// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// `BatchLogRecordProcessor.shutdown` drains the queue in batches of
/// `maxExportBatchSize` (logs/sdk.md, Batching processor: Shutdown "MUST
/// include the effects of ForceFlush").
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../../testing_utils/memory_log_record_exporter.dart';

void main() {
  group('BatchLogRecordProcessor.shutdown', () {
    late MemoryLogRecordExporter exporter;
    late InstrumentationScope scope;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'blrp-shutdown-test',
        detectPlatformResources: false,
      );
      exporter = MemoryLogRecordExporter();
      scope = OTel.instrumentationScope(name: 'test-scope', version: '1.0.0');
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('drains a queue larger than maxExportBatchSize in several batches',
        () async {
      const config = BatchLogRecordProcessorConfig(
        maxExportBatchSize: 2,
        scheduleDelay:
            Duration(seconds: 100), // no timer export during the test
      );
      final processor = BatchLogRecordProcessor(exporter, config);

      for (var i = 0; i < 5; i++) {
        await processor.onEmit(
          SDKLogRecord(
            instrumentationScope: scope,
            severityNumber: Severity.INFO,
            body: 'Message $i',
          ),
          null,
        );
      }
      expect(exporter.count, 0, reason: 'nothing exported before shutdown');

      await processor.shutdown();

      expect(exporter.count, 5);
      expect(
        exporter.exportedLogRecords.map((r) => r.body),
        ['Message 0', 'Message 1', 'Message 2', 'Message 3', 'Message 4'],
        reason: 'batches are exported in queue order',
      );
    });

    test('a record emitted after shutdown is dropped', () async {
      final processor = BatchLogRecordProcessor(
        exporter,
        const BatchLogRecordProcessorConfig(
            scheduleDelay: Duration(seconds: 100)),
      );
      await processor.shutdown();

      await processor.onEmit(
        SDKLogRecord(
          instrumentationScope: scope,
          severityNumber: Severity.INFO,
          body: 'late',
        ),
        null,
      );
      await processor.forceFlush();

      expect(exporter.count, 0);
      expect(processor.enabled(), isFalse);
    });
  });
}
