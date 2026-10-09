// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// `BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues` domain
/// validation: logs/sdk.md says invalid values fall back to the default
/// and are reported, and that `OTEL_BLRP_EXPORT_TIMEOUT=0` means no limit.
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

BlrpEnvironmentValues _env({
  Duration? scheduleDelay,
  Duration? exportTimeout,
  int? maxQueueSize,
  int? maxExportBatchSize,
}) =>
    (
      scheduleDelay: scheduleDelay,
      exportTimeout: exportTimeout,
      maxQueueSize: maxQueueSize,
      maxExportBatchSize: maxExportBatchSize,
    );

void main() {
  group('BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues', () {
    // The fallbacks log a warning; exercise that path too.
    setUp(OTelLog.enableTraceLogging);

    test('all-null values give the spec defaults', () {
      final config = BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues(
        _env(),
      );
      expect(config.scheduleDelay,
          BatchLogRecordProcessorConfig.defaultScheduleDelay);
      expect(config.exportTimeout,
          BatchLogRecordProcessorConfig.defaultExportTimeout);
      expect(config.maxQueueSize,
          BatchLogRecordProcessorConfig.defaultMaxQueueSize);
      expect(config.maxExportBatchSize,
          BatchLogRecordProcessorConfig.defaultMaxExportBatchSize);
    });

    test('a zero schedule delay is valid (export as fast as possible)', () {
      final config = BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues(
        _env(scheduleDelay: Duration.zero),
      );
      expect(config.scheduleDelay, Duration.zero);
    });

    test('a negative schedule delay falls back to the default', () {
      final config = BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues(
        _env(scheduleDelay: const Duration(milliseconds: -250)),
      );
      expect(config.scheduleDelay,
          BatchLogRecordProcessorConfig.defaultScheduleDelay);
    });

    test('an export timeout of 0 means no limit', () {
      final config = BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues(
        _env(exportTimeout: Duration.zero),
      );
      expect(config.exportTimeout, BatchLogRecordProcessorConfig.noLimit);
    });

    test('a positive export timeout is used as given', () {
      final config = BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues(
        _env(exportTimeout: const Duration(seconds: 7)),
      );
      expect(config.exportTimeout, const Duration(seconds: 7));
    });

    test('a negative export timeout falls back to the default', () {
      final config = BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues(
        _env(exportTimeout: const Duration(milliseconds: -1)),
      );
      expect(config.exportTimeout,
          BatchLogRecordProcessorConfig.defaultExportTimeout);
    });

    test('a non-positive queue size falls back to the default', () {
      for (final bad in [0, -1]) {
        final config = BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues(
          _env(maxQueueSize: bad),
        );
        expect(config.maxQueueSize,
            BatchLogRecordProcessorConfig.defaultMaxQueueSize,
            reason: 'maxQueueSize=$bad');
      }
    });

    test('a non-positive export batch size falls back to the default', () {
      for (final bad in [0, -5]) {
        final config = BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues(
          _env(maxExportBatchSize: bad),
        );
        expect(config.maxExportBatchSize,
            BatchLogRecordProcessorConfig.defaultMaxExportBatchSize,
            reason: 'maxExportBatchSize=$bad');
      }
    });

    test('the export batch size is capped at the queue size', () {
      final config = BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues(
        _env(maxQueueSize: 10, maxExportBatchSize: 100),
      );
      expect(config.maxQueueSize, 10);
      expect(config.maxExportBatchSize, 10);
    });
  });
}
