// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'readable_log_record.dart';

/// Interface for log record processors that handle log record lifecycle events.
///
/// Log record processors are invoked when a log record is emitted. They are
/// responsible for performing additional processing on log records, such as
/// filtering, batching, or exporting them.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/logs/sdk/#logrecordprocessor
abstract class LogRecordProcessor {
  /// Called when a log record is emitted.
  ///
  /// This method is called synchronously when a log record is emitted, allowing
  /// for immediate processing of the log record. Implementations should be
  /// lightweight and avoid blocking operations or excessive processing.
  ///
  /// The logRecord parameter is a ReadWriteLogRecord, allowing processors
  /// to modify the log record. Mutations are visible in subsequent processors.
  ///
  /// @param logRecord The log record that was emitted (ReadWriteLogRecord)
  /// @param context The context associated with the log record
  Future<void> onEmit(ReadWriteLogRecord logRecord, Context? context);

  /// Called to determine if the logger is enabled for a given configuration.
  ///
  /// This method supports filtering via Logger.enabled. It helps optimize
  /// performance by allowing early filtering of log records.
  ///
  /// @param context The context (explicit or current)
  /// @param instrumentationScope The instrumentation scope
  /// @param severityNumber The severity number of the potential log
  /// @param eventName The event name, if any
  /// @return false if the log record should be filtered out, true otherwise
  bool enabled({
    Context? context,
    InstrumentationScope? instrumentationScope,
    Severity? severityNumber,
    String? eventName,
  }) {
    // Default implementation returns true (indeterminate state)
    return true;
  }

  /// Shuts down the log record processor.
  ///
  /// This method is called when the logger provider is shut down.
  /// Implementations should release any resources they hold and perform
  /// any final processing of log records.
  Future<void> shutdown();

  /// Forces the log record processor to flush any queued log records.
  ///
  /// This method is called when the logger provider's forceFlush method
  /// is called. Implementations should ensure that any log records that have
  /// been processed but not yet exported are exported immediately.
  Future<void> forceFlush();
}
