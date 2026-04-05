// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// A memory-based log record exporter for testing purposes.
/// This exporter stores log records in memory instead of sending them to an endpoint.
class MemoryLogRecordExporter implements LogRecordExporter {
  final List<ReadableLogRecord> _exportedLogRecords = [];
  bool _isShutdown = false;

  /// Get all exported log records.
  List<ReadableLogRecord> get exportedLogRecords =>
      List.unmodifiable(_exportedLogRecords);

  /// Clear all exported log records.
  void clear() {
    _exportedLogRecords.clear();
  }

  /// Get the count of exported log records.
  int get count => _exportedLogRecords.length;

  @override
  Future<ExportResult> export(List<ReadableLogRecord> logRecords) async {
    if (_isShutdown) {
      return ExportResult.failure;
    }

    _exportedLogRecords.addAll(logRecords);
    return ExportResult.success;
  }

  @override
  Future<void> forceFlush() async {
    // No buffering, nothing to flush
  }

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }

  /// Whether the exporter has been shut down.
  bool get isShutdown => _isShutdown;
}
