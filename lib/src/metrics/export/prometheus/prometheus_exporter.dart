// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show Attribute, OTelLog;
import '../../data/metric.dart';
import '../../data/metric_data.dart';
import '../../data/metric_point.dart';
import '../../metric_exporter.dart';

/// Serializes cumulative metrics in Prometheus text format 0.0.4.
/// Use `OTEL_METRICS_EXPORTER=prometheus` or `OTel.prometheusMetricReader()`
/// for an HTTP pull exporter with collection on each scrape.
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

    try {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport(
          'PrometheusExporter: Exporting ${data.metrics.length} metrics',
        );
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
    final types = <String, String>{};
    final resource = data.resource;
    if (resource != null && resource.attributes.toMap().isNotEmpty) {
      buffer.writeln('# HELP target_info Target metadata');
      buffer.writeln('# TYPE target_info gauge');
      buffer.writeln(
          'target_info${_formatLabels(resource.attributes.toMap())} 1');
      types['target_info'] = 'gauge';
    }

    final families = <String, List<Metric>>{};
    for (final metric in data.metrics) {
      // A pull reader collects cumulative data. Do not misrepresent manually
      // supplied delta points as cumulative Prometheus counters/histograms.
      if (metric.type != MetricType.gauge &&
          metric.temporality == AggregationTemporality.delta) {
        if (OTelLog.isWarn()) {
          OTelLog.warn('Prometheus dropped delta metric ${metric.name}');
        }
        continue;
      }
      final name = _metricName(metric);
      final type = _getPrometheusType(metric);
      final previousType = types[name];
      if (name == 'target_info' ||
          (previousType != null && previousType != type)) {
        if (OTelLog.isWarn()) {
          OTelLog.warn('Prometheus dropped conflicting metric $name');
        }
        continue;
      }
      types[name] = type;
      families.putIfAbsent(name, () => []).add(metric);
    }

    // Keep all samples of a family together, with one HELP/TYPE pair.
    for (final entry in families.entries) {
      final name = entry.key;
      final descriptions = entry.value
          .map((metric) => metric.description)
          .whereType<String>()
          .where((description) => description.isNotEmpty)
          .toList()
        ..sort();
      if (descriptions.isNotEmpty) {
        buffer.writeln('# HELP $name ${_sanitizeComment(descriptions.first)}');
      }
      buffer.writeln('# TYPE $name ${types[name]}');
      for (final metric in entry.value) {
        for (final point in metric.points) {
          _writeMetricPoint(buffer, metric, point);
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Writes a metric point in Prometheus format.
  void _writeMetricPoint(
    StringBuffer buffer,
    Metric metric,
    MetricPoint<dynamic> point,
  ) {
    final metricName = _metricName(metric);
    final attributes = <String, dynamic>{...point.attributes.toMap()};
    final scope = metric.instrumentationScope;
    if (scope != null) {
      attributes['otel_scope_name'] = scope.name;
      if (scope.version != null) {
        attributes['otel_scope_version'] = scope.version;
      }
      if (scope.schemaUrl != null) {
        attributes['otel_scope_schema_url'] = scope.schemaUrl;
      }
      for (final entry in scope.attributes?.toMap().entries ??
          <MapEntry<String, Attribute>>[]) {
        final key = 'otel_scope_${_sanitizeName(entry.key)}';
        if (key != 'otel_scope_name' &&
            key != 'otel_scope_version' &&
            key != 'otel_scope_schema_url') {
          attributes[key] = entry.value;
        }
      }
    }

    // Add labels
    final labels = _formatLabels(attributes);

    if (point.value is HistogramValue) {
      // Histogram metrics require special handling
      final histogram = point.value as HistogramValue;

      // Write sum
      buffer.writeln('${metricName}_sum$labels ${_number(histogram.sum)}');

      // Write count
      buffer.writeln('${metricName}_count$labels ${histogram.count}');

      // Write buckets
      var count = 0;
      for (var i = 0; i < histogram.boundaries.length; i++) {
        final boundary = histogram.boundaries[i];
        count += histogram.bucketCounts[i];
        buffer.writeln(
          '${metricName}_bucket{${_formatLabelsWithLe(attributes, boundary)}} $count',
        );
      }

      // Add +Inf bucket
      buffer.writeln(
        '${metricName}_bucket{${_formatLabelsWithLe(attributes, double.infinity)}} ${histogram.count}',
      );
    } else {
      // Simple metrics (counters, gauges)
      buffer.writeln('$metricName$labels ${_number(point.value as num)}');
    }
  }

  /// Gets the Prometheus metric type from an OTel metric.
  String _getPrometheusType(Metric metric) {
    if (metric.type == MetricType.histogram) {
      return 'histogram';
    } else if (metric.type == MetricType.sum && metric.isMonotonic == true) {
      return 'counter';
    } else {
      return 'gauge';
    }
  }

  String _metricName(Metric metric) {
    final name = _sanitizeName(metric.name);
    return _getPrometheusType(metric) == 'counter' && !name.endsWith('_total')
        ? '${name}_total'
        : name;
  }

  String _number(num value) => value == double.infinity
      ? '+Inf'
      : value == double.negativeInfinity
          ? '-Inf'
          : value.toString();

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
    final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return sanitized.isEmpty || RegExp(r'^[0-9]').hasMatch(sanitized)
        ? '_$sanitized'
        : sanitized;
  }

  /// Sanitizes a comment for HELP.
  String _sanitizeComment(String comment) {
    // Escape backslashes and newlines
    return comment.replaceAll(r'\', r'\\').replaceAll('\n', '\\n');
  }

  /// Sanitizes a label value.
  String _sanitizeValue(dynamic value) {
    if (value is Attribute) value = value.value;
    if (value is List) {
      value = jsonEncode(value.map((element) {
        return element is double && !element.isFinite
            ? element.toString()
            : element;
      }).toList());
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
