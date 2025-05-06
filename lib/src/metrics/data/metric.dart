// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'metric_point.dart';

/// Defines the kind of metric point.
///
/// This enumeration represents the different types of metric data points
/// as defined in the OpenTelemetry metrics data model.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/
enum MetricPointKind {
  /// Sum represents a cumulative or delta sum.
  ///
  /// Sum points record a running total of a value that increases or decreases over time.
  sum,
  
  /// Gauge represents the last value.
  ///
  /// Gauge points record the instantaneous value of a measurement at a specific time.
  gauge,
  
  /// Histogram represents a distribution of values.
  ///
  /// Histogram points record a statistical distribution of values, with count, sum,
  /// and frequency counts for different bucket ranges.
  histogram,
  
  /// ExponentialHistogram represents a distribution of values using
  /// exponential scale bucket boundaries.
  ///
  /// This is a more efficient representation of histograms for high-cardinality data.
  exponentialHistogram,
}

/// Defines the type of metric.
///
/// This enumeration represents the different types of metrics
/// that can be collected and exported.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/#metric-points
enum MetricType {
  /// Sum represents a cumulative or delta sum.
  ///
  /// Sum metrics accumulate values over time and are used for counters.
  sum,
  
  /// Gauge represents the last value.
  ///
  /// Gauge metrics record the current value at a specific time.
  gauge,
  
  /// Histogram represents a distribution of values.
  ///
  /// Histogram metrics record statistical distributions of values.
  histogram,
}

/// Defines the aggregation temporality of a metric.
///
/// Aggregation temporality defines how metrics are aggregated over time.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/#temporality
enum AggregationTemporality {
  /// Cumulative aggregation reports the total sum since the start.
  ///
  /// Cumulative temporality means that each data point contains the total sum
  /// of all measurements since the start time.
  cumulative,
  
  /// Delta aggregation reports the change since the last measurement.
  ///
  /// Delta temporality means that each data point contains only the change
  /// since the last reported measurement.
  delta,
}

/// Metric represents a named collection of data points.
///
/// A Metric is a collection of data points that share the same name, description,
/// unit, and other metadata. It is the fundamental unit of telemetry that is
/// exported to backends.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/#metric
class Metric {
  /// The name of the metric.
  ///
  /// This should be unique within the instrumentation scope and should follow
  /// the naming convention recommended by OpenTelemetry.
  final String name;
  
  /// The description of the metric.
  ///
  /// A human-readable description of what the metric measures.
  final String? description;
  
  /// The unit of the metric.
  ///
  /// The unit of measure for the metric values. Should follow
  /// the UCUM convention where possible (e.g., "ms", "bytes").
  final String? unit;
  
  /// The kind of metric.
  ///
  /// Defines whether this metric is a Sum, Gauge, or Histogram.
  final MetricType type;
  
  /// The aggregation temporality of the metric.
  ///
  /// Defines whether the metric values are cumulative or delta.
  final AggregationTemporality temporality;
  
  /// The instrumentation scope that created this metric.
  ///
  /// Identifies the library or component that created this metric.
  final InstrumentationScope? instrumentationScope;
  
  /// The data points for this metric.
  ///
  /// Each data point contains a set of attributes, a value or values,
  /// and timestamps.
  final List<MetricPoint<dynamic>> points;
  
  /// Whether this metric is monotonic (sum metrics only).
  ///
  /// A monotonic metric only increases or only decreases over time.
  /// This is applicable only for sum metrics.
  final bool? isMonotonic;
  
  /// Creates a new Metric instance.
  ///
  /// @param name The name of the metric
  /// @param description Optional description of what the metric measures
  /// @param unit Optional unit of measurement (e.g., "ms", "bytes")
  /// @param type The type of metric (sum, gauge, or histogram)
  /// @param temporality The aggregation temporality (cumulative or delta)
  /// @param instrumentationScope Optional scope that created this metric
  /// @param points The data points for this metric
  /// @param isMonotonic Whether the metric is monotonic (for sum metrics only)
  Metric({
    required this.name,
    this.description,
    this.unit,
    required this.type,
    this.temporality = AggregationTemporality.cumulative,
    this.instrumentationScope,
    required this.points,
    this.isMonotonic,
  });
  
  /// Creates a sum metric.
  ///
  /// Sum metrics represent values that accumulate over time, such as
  /// request counts, bytes sent, or errors encountered.
  ///
  /// @param name The name of the metric
  /// @param description Optional description of what the metric measures
  /// @param unit Optional unit of measurement (e.g., "requests", "bytes")
  /// @param points The data points for this metric
  /// @param temporality The aggregation temporality (default: cumulative)
  /// @param instrumentationScope Optional scope that created this metric
  /// @param isMonotonic Whether the sum can only increase (default: true)
  /// @return A new sum metric
  factory Metric.sum({
    required String name,
    String? description,
    String? unit,
    required List<MetricPoint<dynamic>> points,
    AggregationTemporality temporality = AggregationTemporality.cumulative,
    InstrumentationScope? instrumentationScope,
    bool isMonotonic = true,
  }) {
    return Metric(
      name: name,
      description: description,
      unit: unit,
      type: MetricType.sum,
      temporality: temporality,
      instrumentationScope: instrumentationScope,
      points: points,
      isMonotonic: isMonotonic,
    );
  }
  
  /// Creates a gauge metric.
  ///
  /// Gauge metrics represent current values that can go up and down,
  /// such as CPU usage, memory usage, or queue size.
  ///
  /// @param name The name of the metric
  /// @param description Optional description of what the metric measures
  /// @param unit Optional unit of measurement (e.g., "percent", "bytes")
  /// @param points The data points for this metric
  /// @param instrumentationScope Optional scope that created this metric
  /// @return A new gauge metric
  factory Metric.gauge({
    required String name,
    String? description,
    String? unit,
    required List<MetricPoint<dynamic>> points,
    InstrumentationScope? instrumentationScope,
  }) {
    return Metric(
      name: name,
      description: description,
      unit: unit,
      type: MetricType.gauge,
      temporality: AggregationTemporality.cumulative, // Gauges are always cumulative
      instrumentationScope: instrumentationScope,
      points: points,
    );
  }
  
  /// Creates a histogram metric.
  ///
  /// Histogram metrics represent distributions of values, such as
  /// request durations, response sizes, or latencies.
  ///
  /// @param name The name of the metric
  /// @param description Optional description of what the metric measures
  /// @param unit Optional unit of measurement (e.g., "ms", "bytes")
  /// @param points The data points for this metric
  /// @param temporality The aggregation temporality (default: cumulative)
  /// @param instrumentationScope Optional scope that created this metric
  /// @return A new histogram metric
  factory Metric.histogram({
    required String name,
    String? description,
    String? unit,
    required List<MetricPoint<dynamic>> points,
    AggregationTemporality temporality = AggregationTemporality.cumulative,
    InstrumentationScope? instrumentationScope,
  }) {
    return Metric(
      name: name,
      description: description,
      unit: unit,
      type: MetricType.histogram,
      temporality: temporality,
      instrumentationScope: instrumentationScope,
      points: points,
    );
  }
}
