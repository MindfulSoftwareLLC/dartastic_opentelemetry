// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Exemplar filtering policy for metrics export.
enum MetricsExemplarFilter {
  /// Export exemplars only when trace/span context is present.
  traceBased,

  /// Export all exemplars.
  alwaysOn,

  /// Export no exemplars.
  alwaysOff,
}

/// Resolved metrics SDK configuration derived from environment variables.
class MetricsSdkConfig {
  /// The exemplar filtering policy.
  final MetricsExemplarFilter exemplarFilter;

  /// Periodic export interval.
  final Duration exportInterval;

  /// Periodic export timeout.
  final Duration exportTimeout;

  const MetricsSdkConfig({
    required this.exemplarFilter,
    required this.exportInterval,
    required this.exportTimeout,
  });
}
