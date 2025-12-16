// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

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
