// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;

import '../data/metric_data.dart';
import '../metric_exporter.dart';

/// A composite metric exporter that delegates to multiple exporters.
///
/// This exporter implements the fan-out pattern, where metrics are exported
/// to multiple backends simultaneously. It forwards all export, flush, and
/// shutdown operations to each of its delegate exporters.
///
/// This is useful for scenarios where you want to send metrics to multiple
/// destinations, such as a local console and a remote collector.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/sdk/#metricexporter
class CompositeMetricExporter implements MetricExporter {
  /// The list of delegate exporters.
  final List<MetricExporter> _exporters;

  /// Whether this exporter has been shut down.
  bool _shutdown = false;

  /// Creates a new CompositeMetricExporter with the given list of exporters.
  ///
  /// @param exporters The list of exporters to which operations will be delegated
  CompositeMetricExporter(this._exporters);

  /// Exports metrics to all delegate exporters.
  ///
  /// This method forwards the export operation to each delegate exporter.
  /// If any exporter fails, the composite exporter will still try to export
  /// to the remaining exporters, but will return false to indicate failure.
  ///
  /// @param data The metric data to export
  /// @return true if all exporters succeeded, false if any exporter failed
  @override
  Future<bool> export(MetricData data) async {
    if (_shutdown) {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport(
            'CompositeMetricExporter: Cannot export after shutdown');
      }
      return false;
    }

    bool success = true;
    for (final exporter in _exporters) {
      try {
        final result = await exporter.export(data);
        success = success && result;
      } catch (e) {
        if (OTelLog.isLogExport()) {
          OTelLog.logExport(
              'CompositeMetricExporter: Export failed for $exporter: $e');
        }
        success = false;
      }
    }

    return success;
  }

  /// Forces a flush of all delegate exporters.
  ///
  /// This method forwards the flush operation to each delegate exporter.
  /// If any exporter fails to flush, the composite exporter will still try
  /// to flush the remaining exporters, but will return false to indicate failure.
  ///
  /// @return true if all exporters were flushed successfully, false otherwise
  @override
  Future<bool> forceFlush() async {
    if (_shutdown) {
      return false;
    }

    bool success = true;
    for (final exporter in _exporters) {
      try {
        final result = await exporter.forceFlush();
        success = success && result;
      } catch (e) {
        success = false;
      }
    }

    return success;
  }

  /// Shuts down all delegate exporters.
  ///
  /// This method forwards the shutdown operation to each delegate exporter.
  /// Once shut down, this exporter will no longer accept export requests.
  ///
  /// @return true if all exporters were shut down successfully, false otherwise
  @override
  Future<bool> shutdown() async {
    if (_shutdown) {
      return true;
    }

    _shutdown = true;
    bool success = true;
    for (final exporter in _exporters) {
      try {
        final result = await exporter.shutdown();
        success = success && result;
      } catch (e) {
        success = false;
      }
    }

    return success;
  }
}
