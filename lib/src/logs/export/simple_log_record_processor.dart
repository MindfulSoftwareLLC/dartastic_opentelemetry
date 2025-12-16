// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../log_record_processor.dart';
import '../readable_log_record.dart';
import 'log_record_exporter.dart';

/// A simple LogRecordProcessor that exports log records immediately.
///
/// This processor passes finished log records to the configured LogRecordExporter
/// as soon as they are emitted.
///
/// Use this processor for debugging or when immediate export is required.
/// For production use, consider BatchLogRecordProcessor for better performance.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/logs/sdk/#simple-processor
class SimpleLogRecordProcessor implements LogRecordProcessor {
  /// The exporter used to send log records to the backend.
  final LogRecordExporter exporter;

  /// Whether the processor has been shut down.
  bool _isShutdown = false;

  /// Creates a new SimpleLogRecordProcessor with the specified exporter.
  ///
  /// @param exporter The LogRecordExporter to use for exporting log records
  SimpleLogRecordProcessor(this.exporter);

  @override
  Future<void> onEmit(ReadWriteLogRecord logRecord, Context? context) async {
    if (_isShutdown) {
      return;
    }

    try {
      final result = await exporter.export([logRecord]);
      if (result == ExportResult.failure && OTelLog.isError()) {
        OTelLog.error('SimpleLogRecordProcessor: Export failed');
      }
    } catch (e) {
      if (OTelLog.isError()) {
        OTelLog.error('SimpleLogRecordProcessor: Error exporting log: $e');
      }
    }
  }

  @override
  bool enabled({
    Context? context,
    InstrumentationScope? instrumentationScope,
    Severity? severityNumber,
    String? eventName,
  }) {
    // Default to true - simple processor doesn't do filtering
    return !_isShutdown;
  }

  @override
  Future<void> forceFlush() async {
    if (_isShutdown) {
      return;
    }

    await exporter.forceFlush();
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }

    _isShutdown = true;

    // Flush any pending exports
    await forceFlush();

    // Shutdown the exporter
    await exporter.shutdown();
  }
}
