// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:collection';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:synchronized/synchronized.dart';

import '../../environment/otel_env.dart';
import '../log_record_processor.dart';
import '../readable_log_record.dart';
import 'log_record_exporter.dart';

/// Configuration for the BatchLogRecordProcessor.
///
/// This class configures how the batch log record processor behaves, including
/// queue size limits, export scheduling, and batch size parameters.
class BatchLogRecordProcessorConfig {
  /// Stand-in for "no limit": `OTEL_BLRP_EXPORT_TIMEOUT=0` means no timeout
  /// per spec, represented as the max milliseconds in a 32-bit integer
  /// (~24.8 days). Web-safe and within Dart timer limits for
  /// `Future.timeout()`.
  static const Duration noLimit = Duration(milliseconds: 0x7FFFFFFF);

  /// The maximum queue size for log records. After this is reached,
  /// log records will be dropped.
  final int maxQueueSize;

  /// The delay between two consecutive exports.
  final Duration scheduleDelay;

  /// The maximum batch size of log records that can be exported at once.
  final int maxExportBatchSize;

  /// The amount of time to wait for an export to complete before timing out.
  final Duration exportTimeout;

  /// Creates a new configuration for a BatchLogRecordProcessor.
  ///
  /// [maxQueueSize] The maximum number of log records that can be queued. Default is 2048.
  /// [scheduleDelay] The time interval between exports. Default is 1 second.
  /// [maxExportBatchSize] The maximum batch size per export. Default is 512.
  /// [exportTimeout] The maximum time to wait for export. Default is 30 seconds.
  const BatchLogRecordProcessorConfig({
    this.maxQueueSize = 2048,
    this.scheduleDelay = const Duration(milliseconds: 1000),
    this.maxExportBatchSize = 512,
    this.exportTimeout = const Duration(seconds: 30),
  });

  /// Creates a configuration by reading `OTEL_BLRP_*` environment variables
  /// via [OTelEnv]. Falls back to standard OTel defaults if variables are
  /// missing or invalid.
  ///
  /// | Environment Variable              | Type     | Default  | Notes                                                    |
  /// |-----------------------------------|----------|----------|----------------------------------------------------------|
  /// | `OTEL_BLRP_SCHEDULE_DELAY`        | Duration | `1000`   | Delay between exports (ms). 0 is valid (export ASAP).    |
  /// | `OTEL_BLRP_EXPORT_TIMEOUT`        | Timeout  | `30000`  | Export timeout (ms). 0 means no limit.                   |
  /// | `OTEL_BLRP_MAX_QUEUE_SIZE`        | Integer  | `2048`   | Maximum log record queue size.                           |
  /// | `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE` | Integer  | `512`    | Maximum batch size. Must be ≤ `MAX_QUEUE_SIZE`.          |
  ///
  /// Invalid or out-of-range values emit an [OTelLog.warn] diagnostic and
  /// fall back to the spec default.
  factory BatchLogRecordProcessorConfig.fromEnvironment() {
    final env = OTelEnv.getBlrpConfig();

    var queueSize = (env['maxQueueSize'] as int?) ?? 2048;
    var batchSize = (env['maxExportBatchSize'] as int?) ?? 512;

    // --- scheduleDelay ---
    // Spec type: Duration. Zero is valid ("export as fast as possible").
    // Negative values MUST warn and fall back to default.
    Duration scheduleDelay;
    if (env['scheduleDelay'] is Duration) {
      final delay = env['scheduleDelay'] as Duration;
      if (delay.inMilliseconds >= 0) {
        scheduleDelay = delay;
      } else {
        if (OTelLog.isWarn()) {
          OTelLog.warn('BatchLogRecordProcessorConfig: Negative '
              'OTEL_BLRP_SCHEDULE_DELAY (${delay.inMilliseconds} ms) is '
              'invalid per spec, using default 1000 ms.');
        }
        scheduleDelay = const Duration(milliseconds: 1000);
      }
    } else {
      scheduleDelay = const Duration(milliseconds: 1000);
    }

    // --- exportTimeout ---
    // Spec type: Timeout. Zero means "no limit" — substitute a very large
    // duration. Negative values MUST warn and fall back to default.
    Duration exportTimeout;
    if (env['exportTimeout'] is Duration) {
      final timeout = env['exportTimeout'] as Duration;
      if (timeout.inMilliseconds == 0) {
        exportTimeout = noLimit;
      } else if (timeout.inMilliseconds > 0) {
        exportTimeout = timeout;
      } else {
        if (OTelLog.isWarn()) {
          OTelLog.warn('BatchLogRecordProcessorConfig: Negative '
              'OTEL_BLRP_EXPORT_TIMEOUT (${timeout.inMilliseconds} ms) is '
              'invalid per spec, using default 30000 ms.');
        }
        exportTimeout = const Duration(milliseconds: 30000);
      }
    } else {
      exportTimeout = const Duration(milliseconds: 30000);
    }

    // --- Validation Logic ---
    if (queueSize <= 0) {
      if (OTelLog.isWarn()) {
        OTelLog.warn('BatchLogRecordProcessorConfig: Non-positive '
            'OTEL_BLRP_MAX_QUEUE_SIZE ($queueSize) is invalid per spec, '
            'using default 2048.');
      }
      queueSize = 2048;
    }
    if (batchSize <= 0) {
      if (OTelLog.isWarn()) {
        OTelLog.warn('BatchLogRecordProcessorConfig: Non-positive '
            'OTEL_BLRP_MAX_EXPORT_BATCH_SIZE ($batchSize) is invalid per '
            'spec, using default 512.');
      }
      batchSize = 512;
    }
    // Spec rule: maxExportBatchSize must be less than or equal to maxQueueSize
    if (batchSize > queueSize) {
      batchSize = queueSize;
    }

    return BatchLogRecordProcessorConfig(
      maxQueueSize: queueSize,
      maxExportBatchSize: batchSize,
      scheduleDelay: scheduleDelay,
      exportTimeout: exportTimeout,
    );
  }
}

/// A LogRecordProcessor that batches log records before export.
///
/// This processor collects log records in a queue and exports them in batches
/// at regular intervals, improving efficiency compared to exporting each log
/// individually.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/logs/sdk/#batching-processor
class BatchLogRecordProcessor implements LogRecordProcessor {
  /// The exporter used to send log records to the backend.
  final LogRecordExporter exporter;

  /// Configuration for the batch processor behavior.
  final BatchLogRecordProcessorConfig _config;

  /// Queue of log records waiting to be exported.
  final Queue<ReadableLogRecord> _logQueue = Queue<ReadableLogRecord>();

  /// Whether the processor has been shut down.
  bool _isShutdown = false;

  /// Timer for scheduling periodic exports.
  Timer? _timer;

  /// Lock for synchronizing queue access.
  final _lock = Lock();

  /// Creates a new BatchLogRecordProcessor with the specified exporter and configuration.
  ///
  /// A timer is started to trigger periodic batch exports.
  ///
  /// @param exporter The LogRecordExporter to use for exporting batches
  /// @param config Optional configuration for the batch processor
  BatchLogRecordProcessor(this.exporter,
      [BatchLogRecordProcessorConfig? config])
      : _config = config ?? const BatchLogRecordProcessorConfig() {
    _timer = Timer.periodic(_config.scheduleDelay, (_) async {
      try {
        await _exportBatch();
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'BatchLogRecordProcessor: Error in batch export timer: $e');
        }
      }
    });
  }

  @override
  Future<void> onEmit(ReadWriteLogRecord logRecord, Context? context) async {
    if (_isShutdown) {
      return;
    }

    await _lock.synchronized(() {
      if (_logQueue.length >= _config.maxQueueSize) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'BatchLogRecordProcessor: Queue full - dropping log record');
        }
        return;
      }
      // Clone the log record to avoid race conditions
      _logQueue.add(logRecord.clone());
    });
  }

  @override
  bool enabled({
    Context? context,
    InstrumentationScope? instrumentationScope,
    Severity? severityNumber,
    String? eventName,
  }) {
    // Default to true - batch processor doesn't do filtering
    return !_isShutdown;
  }

  /// Exports a batch of log records from the queue to the configured exporter.
  Future<void> _exportBatch() async {
    if (_isShutdown) {
      return;
    }

    final logsToExport = <ReadableLogRecord>[];

    await _lock.synchronized(() {
      final batchSize = _logQueue.length > _config.maxExportBatchSize
          ? _config.maxExportBatchSize
          : _logQueue.length;

      for (var i = 0; i < batchSize; i++) {
        if (_logQueue.isEmpty) break;
        logsToExport.add(_logQueue.removeFirst());
      }
    });

    if (logsToExport.isEmpty) {
      return;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'BatchLogRecordProcessor: Exporting ${logsToExport.length} log records');
    }

    try {
      final result = await exporter.export(logsToExport).timeout(
        _config.exportTimeout,
        onTimeout: () {
          if (OTelLog.isError()) {
            OTelLog.error('BatchLogRecordProcessor: Export timed out');
          }
          return ExportResult.failure;
        },
      );

      if (result == ExportResult.failure && OTelLog.isError()) {
        OTelLog.error('BatchLogRecordProcessor: Export failed');
      }
    } catch (e) {
      if (OTelLog.isError()) {
        OTelLog.error('BatchLogRecordProcessor: Error exporting batch: $e');
      }
    }
  }

  @override
  Future<void> forceFlush() async {
    if (_isShutdown) {
      return;
    }

    // Export all remaining batches
    while (_logQueue.isNotEmpty) {
      await _exportBatch();
    }

    await exporter.forceFlush();
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }

    // Cancel the timer first
    _timer?.cancel();

    // Export any remaining log records BEFORE setting _isShutdown
    // so that forceFlush and _exportBatch will still work
    while (_logQueue.isNotEmpty) {
      await _exportBatchForShutdown();
    }
    await exporter.forceFlush();

    // Now mark as shutdown
    _isShutdown = true;

    // Shutdown the exporter
    await exporter.shutdown();
  }

  /// Internal export batch method for shutdown that doesn't check _isShutdown.
  Future<void> _exportBatchForShutdown() async {
    final logsToExport = <ReadableLogRecord>[];

    await _lock.synchronized(() {
      final batchSize = _logQueue.length > _config.maxExportBatchSize
          ? _config.maxExportBatchSize
          : _logQueue.length;

      for (var i = 0; i < batchSize; i++) {
        if (_logQueue.isEmpty) break;
        logsToExport.add(_logQueue.removeFirst());
      }
    });

    if (logsToExport.isEmpty) {
      return;
    }

    try {
      await exporter.export(logsToExport).timeout(
        _config.exportTimeout,
        onTimeout: () {
          if (OTelLog.isError()) {
            OTelLog.error(
                'BatchLogRecordProcessor: Export timed out during shutdown');
          }
          return ExportResult.failure;
        },
      );
    } catch (e) {
      if (OTelLog.isError()) {
        OTelLog.error(
            'BatchLogRecordProcessor: Error exporting batch during shutdown: $e');
      }
    }
  }
}
