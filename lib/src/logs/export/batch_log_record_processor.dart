// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:collection';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:synchronized/synchronized.dart';

import '../log_record_processor.dart';
import '../readable_log_record.dart';
import 'log_record_exporter.dart';

/// Configuration for the BatchLogRecordProcessor.
///
/// This class configures how the batch log record processor behaves, including
/// queue size limits, export scheduling, and batch size parameters.
class BatchLogRecordProcessorConfig {
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

    final List<ReadableLogRecord> logsToExport = [];

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
    final List<ReadableLogRecord> logsToExport = [];

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
