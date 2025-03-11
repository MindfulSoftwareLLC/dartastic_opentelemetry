// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import '../../util/otel_log.dart';
import '../data/metric_data.dart';
import '../metric_exporter.dart';

/// Composite implementation of [MetricExporter] that forwards all methods
/// to a list of delegate exporters.
class CompositeMetricExporter implements MetricExporter {
  final List<MetricExporter> _exporters;
  bool _shutdown = false;

  /// Creates a new CompositeMetricExporter with the given list of exporters.
  CompositeMetricExporter(this._exporters);

  @override
  Future<bool> export(MetricData data) async {
    if (_shutdown) {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport('CompositeMetricExporter: Cannot export after shutdown');
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
          OTelLog.logExport('CompositeMetricExporter: Export failed for $exporter: $e');
        }
        success = false;
      }
    }

    return success;
  }

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
