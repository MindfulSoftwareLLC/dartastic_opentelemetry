// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'metric_point.dart';

/// Defines the kind of metric point.
enum MetricPointKind {
  /// Sum represents a cumulative or delta sum.
  sum,
  
  /// Gauge represents the last value.
  gauge,
  
  /// Histogram represents a distribution of values.
  histogram,
  
  /// ExponentialHistogram represents a distribution of values using
  /// exponential scale bucket boundaries.
  exponentialHistogram,
}

/// Defines the type of metric.
enum MetricType {
  /// Sum represents a cumulative or delta sum.
  sum,
  
  /// Gauge represents the last value.
  gauge,
  
  /// Histogram represents a distribution of values.
  histogram,
}

/// Defines the aggregation temporality of a metric.
enum AggregationTemporality {
  /// Cumulative aggregation reports the total sum since the start.
  cumulative,
  
  /// Delta aggregation reports the change since the last measurement.
  delta,
}

/// Metric represents a named collection of data points.
class Metric {
  /// The name of the metric.
  final String name;
  
  /// The description of the metric.
  final String? description;
  
  /// The unit of the metric.
  final String? unit;
  
  /// The kind of metric.
  final MetricType type;
  
  /// The aggregation temporality of the metric.
  final AggregationTemporality temporality;
  
  /// The instrumentation scope that created this metric.
  final InstrumentationScope? instrumentationScope;
  
  /// The data points for this metric.
  final List<MetricPoint> points;
  
  /// Creates a new Metric instance.
  Metric({
    required this.name,
    this.description,
    this.unit,
    required this.type,
    this.temporality = AggregationTemporality.cumulative,
    this.instrumentationScope,
    required this.points,
  });
  
  /// Creates a sum metric.
  factory Metric.sum({
    required String name,
    String? description,
    String? unit,
    required List<MetricPoint> points,
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
    );
  }
  
  /// Creates a gauge metric.
  factory Metric.gauge({
    required String name,
    String? description,
    String? unit,
    required List<MetricPoint> points,
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
  factory Metric.histogram({
    required String name,
    String? description,
    String? unit,
    required List<MetricPoint> points,
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
