// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'data/metric_data.dart';

/// Defines the result of a metric export operation.
enum ExportResult {
  /// The export was successful.
  success,

  /// The export failed.
  failure
}

/// MetricExporter is responsible for sending metrics to a backend.
abstract class MetricExporter {
  /// Export a batch of metrics to the backend.
  ///
  /// Returns true if the export was successful, false otherwise.
  Future<bool> export(MetricData data);

  /// Force flush any pending metrics.
  ///
  /// Returns true if the flush was successful, false otherwise.
  Future<bool> forceFlush();

  /// Shutdown the exporter.
  ///
  /// This should cleanup any resources and perform final exports.
  /// Returns true if the shutdown was successful, false otherwise.
  Future<bool> shutdown();
}

/// ConsoleMetricExporter is a simple exporter that prints metrics to the console.
class ConsoleMetricExporter implements MetricExporter {
  /// Whether the exporter has been shut down.
  bool _isShutdown = false;

  @override
  Future<bool> export(MetricData data) async {
    if (_isShutdown) {
      print('ConsoleMetricExporter: Cannot export after shutdown');
      return false;
    }

    print('ConsoleMetricExporter: Exporting ${data.metrics.length} metrics:');
    for (final metric in data.metrics) {
      print(
          '  - ${metric.name} (${metric.unit ?? "no unit"}): ${metric.description ?? ""}');
      for (final point in metric.points) {
        final String value = point.valueAsString;
        print('    - Value: $value, Attributes: ${point.attributes}');
        if (point.hasExemplars) {
          print('      Exemplars: ${point.exemplars?.length}');
        }
      }
    }

    return true;
  }

  @override
  Future<bool> forceFlush() async {
    // No-op for console exporter
    return true;
  }

  @override
  Future<bool> shutdown() async {
    _isShutdown = true;
    return true;
  }
}
