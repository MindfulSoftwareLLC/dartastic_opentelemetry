// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import '../../export/export_result.dart';
import '../readable_log_record.dart';

export '../../export/export_result.dart';

/// A LogRecordExporter exports log records.
///
/// LogRecordExporters handle the protocol-specific details of exporting
/// log records to a backend. They should be simple encoders and transmitters.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/logs/sdk/#logrecordexporter
abstract class LogRecordExporter {
  /// Exports a batch of log records.
  ///
  /// This method typically serializes and transmits data to a destination.
  /// It should NOT be called concurrently with other Export calls.
  /// It must NOT block indefinitely and should have a reasonable timeout.
  /// It must NOT retry on failure (that's the processor's responsibility).
  ///
  /// @param logRecords The batch of log records to export
  /// @return The result of the export operation
  Future<ExportResult> export(List<ReadableLogRecord> logRecords);

  /// Forces the exporter to flush any pending log records.
  ///
  /// This method is a hint to ensure export of any log records the exporter
  /// received before this call. Should be completed ASAP.
  Future<void> forceFlush();

  /// Shuts down the exporter.
  ///
  /// This method is called when the SDK is shut down. Implementations
  /// should release any resources they hold. After shutdown, subsequent
  /// Export calls should return Failure.
  Future<void> shutdown();
}
