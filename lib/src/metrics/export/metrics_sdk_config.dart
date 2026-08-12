// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;
import '../../environment/otel_env.dart';

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
  /// The default exemplar filter per spec.
  static const MetricsExemplarFilter defaultExemplarFilter =
      MetricsExemplarFilter.traceBased;

  /// The default periodic export interval per spec.
  static const Duration defaultExportInterval = Duration(seconds: 60);

  /// The default periodic export timeout per spec.
  static const Duration defaultExportTimeout = Duration(seconds: 30);

  /// The exemplar filtering policy.
  ///
  /// Parsed from `OTEL_METRICS_EXEMPLAR_FILTER`.
  final MetricsExemplarFilter exemplarFilter;

  /// Periodic export interval.
  ///
  /// Parsed from `OTEL_METRIC_EXPORT_INTERVAL`.
  final Duration exportInterval;

  /// Periodic export timeout.
  ///
  /// Parsed from `OTEL_METRIC_EXPORT_TIMEOUT`.
  final Duration exportTimeout;

  const MetricsSdkConfig({
    this.exemplarFilter = defaultExemplarFilter,
    this.exportInterval = defaultExportInterval,
    this.exportTimeout = defaultExportTimeout,
  });

  /// Creates a configuration by reading metrics environment variables via [OTelEnv].
  ///
  /// Applies spec defaults and validates inputs, emitting warnings for
  /// unusable values.
  factory MetricsSdkConfig.fromEnvironment(
      [MetricsEnvironmentValues? overrides]) {
    final env = overrides ?? OTelEnv.getMetricsConfig();

    var filter = defaultExemplarFilter;
    if (env.exemplarFilter != null) {
      switch (env.exemplarFilter!.toLowerCase()) {
        case 'always_on':
          filter = MetricsExemplarFilter.alwaysOn;
          break;
        case 'always_off':
          filter = MetricsExemplarFilter.alwaysOff;
          break;
        case 'trace_based':
          filter = MetricsExemplarFilter.traceBased;
          break;
        default:
          if (OTelLog.isWarn()) {
            OTelLog.warn(
                'MetricsSdkConfig: Invalid OTEL_METRICS_EXEMPLAR_FILTER '
                'value "${env.exemplarFilter}", using default (trace_based).');
          }
      }
    }

    var interval = defaultExportInterval;
    if (env.exportInterval != null) {
      final ms = int.tryParse(env.exportInterval!);
      if (ms == null || ms < 0) {
        if (OTelLog.isWarn()) {
          OTelLog.warn('MetricsSdkConfig: Invalid OTEL_METRIC_EXPORT_INTERVAL '
              'value "${env.exportInterval}", using default (${defaultExportInterval.inMilliseconds} ms).');
        }
      } else {
        interval = Duration(milliseconds: ms);
      }
    }

    var timeout = defaultExportTimeout;
    if (env.exportTimeout != null) {
      final ms = int.tryParse(env.exportTimeout!);
      if (ms == null || ms < 0) {
        if (OTelLog.isWarn()) {
          OTelLog.warn('MetricsSdkConfig: Invalid OTEL_METRIC_EXPORT_TIMEOUT '
              'value "${env.exportTimeout}", using default (${defaultExportTimeout.inMilliseconds} ms).');
        }
      } else if (ms == 0) {
        // Spec defines 0 as no limit for timeouts
        timeout = const Duration(days: 365);
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'MetricsSdkConfig: OTEL_METRIC_EXPORT_TIMEOUT set to 0 (no limit). Switched to a large number internally.');
        }
      } else {
        timeout = Duration(milliseconds: ms);
      }
    }

    return MetricsSdkConfig(
      exemplarFilter: filter,
      exportInterval: interval,
      exportTimeout: timeout,
    );
  }
}
