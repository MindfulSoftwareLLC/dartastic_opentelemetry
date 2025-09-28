// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;
import '../../data/metric.dart';
import '../../data/metric_data.dart';
import '../../data/metric_point.dart';
import '../../metric_exporter.dart';

/// PrometheusExporter exports metrics in Prometheus format.
/// This can be exposed via an HTTP endpoint or written to a file.
/// This could be used on Dart server but not Flutter clients since
/// Prometheus is a pull model and expects stable http servers and
/// a Flutter client typically can't provide that.
/// Dartastic.io offers Prometheus for OTel by forwarding the OTLP data
/// to use Prometheus.  To forward OTLP to your own Prometheus backend you would
/// configure an OTel collector similar to the following:
/// receivers:
//   otlp:
//     protocols:
//       grpc:
//         endpoint: 0.0.0.0:4317
//
// processors:
//   batch:
//     timeout: 10s
//
// exporters:
//   prometheus:
//     endpoint: "0.0.0.0:8889"  # Endpoint for Prometheus to scrape
//     namespace: "flutter_apps"
//     const_labels:
//       source: "mobile_clients"
//
// service:
//   pipelines:
//     metrics:
//       receivers: [otlp]
//       processors: [batch]
//       exporters: [prometheus]
class PrometheusExporter implements MetricExporter {
  bool _shutdown = false;

  /// The last generated Prometheus text exposition format data.
  String _lastExportData = '';

  /// Creates a new PrometheusExporter.
  PrometheusExporter();

  /// Gets the latest Prometheus exposition format data.
  String get prometheusData => _lastExportData;

  @override
  Future<bool> export(MetricData data) async {
    if (_shutdown) {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport('PrometheusExporter: Cannot export after shutdown');
      }
      return false;
    }

    if (data.metrics.isEmpty) {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport('PrometheusExporter: No metrics to export');
      }
      return true;
    }

    try {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport(
            'PrometheusExporter: Exporting ${data.metrics.length} metrics');
      }

      // Convert metrics to Prometheus format
      _lastExportData = _toPrometheusFormat(data);

      if (OTelLog.isLogExport()) {
        OTelLog.logExport('PrometheusExporter: Export successful');
      }
      return true;
    } catch (e) {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport('PrometheusExporter: Export failed: $e');
      }
      return false;
    }
  }

  /// Converts metric data to Prometheus exposition format.
  String _toPrometheusFormat(MetricData data) {
    final buffer = StringBuffer();

    for (final metric in data.metrics) {
      // Add HELP comment
      if (metric.description != null) {
        buffer.writeln(
            '# HELP ${_sanitizeName(metric.name)} ${_sanitizeComment(metric.description!)}');
      }

      // Add TYPE comment
      buffer.writeln(
          '# TYPE ${_sanitizeName(metric.name)} ${_getPrometheusType(metric)}');

      // Add metric data points
      for (final point in metric.points) {
        _writeMetricPoint(buffer, metric, point);
      }

      // Empty line between metrics
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Writes a metric point in Prometheus format.
  void _writeMetricPoint(
      StringBuffer buffer, Metric metric, MetricPoint<dynamic> point) {
    final metricName = _sanitizeName(metric.name);

    // Add labels
    final labels = _formatLabels(point.attributes.toMap());

    if (point.value is HistogramValue) {
      // Histogram metrics require special handling
      final histogram = point.value as HistogramValue;

      // Write sum
      buffer.writeln('${metricName}_sum$labels ${histogram.sum}');

      // Write count
      buffer.writeln('${metricName}_count$labels ${histogram.count}');

      // Write buckets
      for (int i = 0; i < histogram.boundaries.length; i++) {
        final boundary = histogram.boundaries[i];
        final count = histogram.bucketCounts[i];
        buffer.writeln(
            '${metricName}_bucket{${_formatLabelsWithLe(point.attributes.toMap(), boundary)}} $count');
      }

      // Add +Inf bucket
      buffer.writeln(
          '${metricName}_bucket{${_formatLabelsWithLe(point.attributes.toMap(), double.infinity)}} ${histogram.count}');
    } else {
      // Simple metrics (counters, gauges)
      buffer.writeln('$metricName$labels ${point.value}');
    }
  }

  /// Gets the Prometheus metric type from an OTel metric.
  String _getPrometheusType(Metric metric) {
    if (metric.points.isNotEmpty &&
        metric.points.first.value is HistogramValue) {
      return 'histogram';
    } else if (metric.type == MetricType.sum) {
      return 'counter';
    } else {
      return 'gauge';
    }
  }

  /// Formats attributes as Prometheus labels.
  String _formatLabels(Map<String, dynamic> attributes) {
    if (attributes.isEmpty) {
      return '{}'; // Return empty braces for metrics without attributes
    }

    final labelPairs = attributes.entries.map((entry) {
      return '${_sanitizeName(entry.key)}="${_sanitizeValue(entry.value)}"';
    }).join(',');

    return '{$labelPairs}';
  }

  /// Formats attributes with an added 'le' label for histogram buckets.
  String _formatLabelsWithLe(Map<String, dynamic> attributes, double le) {
    final newAttributes = Map<String, dynamic>.from(attributes);
    if (le == double.infinity) {
      newAttributes['le'] = '+Inf';
    } else if (le == le.truncateToDouble()) {
      // If the number is an integer (no decimal component),
      // format it without the decimal point
      newAttributes['le'] = le.toInt().toString();
    } else {
      newAttributes['le'] = le.toString();
    }

    final labelPairs = newAttributes.entries.map((entry) {
      return '${_sanitizeName(entry.key)}="${_sanitizeValue(entry.value)}"';
    }).join(',');

    return labelPairs;
  }

  /// Sanitizes a metric or label name.
  String _sanitizeName(String name) {
    // Replace invalid characters with underscores
    // Valid characters in Prometheus are: [a-zA-Z0-9_]
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  /// Sanitizes a comment for HELP.
  String _sanitizeComment(String comment) {
    // Escape backslashes and newlines
    return comment.replaceAll(r'\', r'\\').replaceAll('\n', '\\n');
  }

  /// Sanitizes a label value.
  String _sanitizeValue(dynamic value) {
    // Handle AttributeValue objects by extracting the raw value
    if (value.toString().startsWith('AttributeValue(') &&
        value.toString().endsWith(')')) {
      // Extract the value inside AttributeValue(...)
      final rawValue = value
          .toString()
          .substring('AttributeValue('.length, value.toString().length - 1);
      value = rawValue;
    }

    // Escape quotes, backslashes, and newlines
    return value
        .toString()
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', '\\n');
  }

  @override
  Future<bool> forceFlush() async {
    // No-op for this exporter
    return true;
  }

  @override
  Future<bool> shutdown() async {
    _shutdown = true;
    return true;
  }
}
