// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Result of an export operation.
///
/// This enum is shared across all telemetry signals (traces, metrics, logs)
/// to provide a consistent export result type.
enum ExportResult {
  /// The export was successful.
  success,

  /// The export failed. The batch may need to be retried or dropped.
  failure,
}
