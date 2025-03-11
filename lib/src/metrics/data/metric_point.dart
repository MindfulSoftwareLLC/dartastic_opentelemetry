// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';

import 'exemplar.dart';

/// Represents a metric data point, which consists of a value or set of values,
/// a set of attributes, and possibly exemplars.
///
/// The type of value depends on the instrument type:
class MetricPoint {
  /// The set of attributes associated with this metric point.
  final Attributes attributes;

  /// The start timestamp for this data point.
  final DateTime startTime;

  /// The end timestamp for this data point.
  final DateTime endTime;

  /// The value of the metric point. The type depends on the instrument type:
  /// - For counters: A single sum value as a [num]
  /// - For histograms: A [HistogramValue] object
  final dynamic value;

  /// Optional exemplars for this data point.
  final List<Exemplar>? exemplars;

  /// Creates a new MetricPoint.
  MetricPoint({
    required this.attributes,
    required this.startTime,
    required this.endTime,
    required this.value,
    this.exemplars,
  });

  /// Creates a sum data point.
  factory MetricPoint.sum({
    required Attributes attributes,
    required DateTime startTime,
    required DateTime time,
    required num value,
    bool isMonotonic = true,
    List<Exemplar>? exemplars,
  }) {
    return MetricPoint(
      attributes: attributes,
      startTime: startTime,
      endTime: time,
      value: value,
      exemplars: exemplars,
    );
  }

  /// Creates a gauge data point.
  factory MetricPoint.gauge({
    required Attributes attributes,
    required DateTime startTime,
    required DateTime time,
    required num value,
    List<Exemplar>? exemplars,
  }) {
    return MetricPoint(
      attributes: attributes,
      startTime: startTime,
      endTime: time,
      value: value,
      exemplars: exemplars,
    );
  }

  /// Creates a histogram data point.
  factory MetricPoint.histogram({
    required Attributes attributes,
    required DateTime startTime,
    required DateTime time,
    required int count,
    required num sum,
    required List<int> counts,
    required List<double> boundaries,
    num? min,
    num? max,
    List<Exemplar>? exemplars,
  }) {
    return MetricPoint(
      attributes: attributes,
      startTime: startTime,
      endTime: time,
      value: HistogramValue(
        sum: sum,
        count: count,
        boundaries: boundaries,
        bucketCounts: counts,
        min: min,
        max: max,
      ),
      exemplars: exemplars,
    );
  }

  /// Checks if this point has exemplars.
  bool get hasExemplars => exemplars != null && exemplars!.isNotEmpty;

  /// Creates a string representation of the value.
  String get valueAsString {
    if (value is num) {
      return value.toString();
    } else if (value is HistogramValue) {
      return 'Histogram(sum: ${value.sum}, count: ${value.count})';
    } else {
      return value.toString();
    }
  }

  /// Gets this point as a histogram value. Will throw if this is not a histogram point.
  HistogramValue histogram() {
    if (value is! HistogramValue) {
      throw StateError('This is not a histogram point');
    }
    return value as HistogramValue;
  }
}

/// Represents the value of a histogram metric point.
class HistogramValue {
  /// The sum of all recorded values.
  final num sum;

  /// The count of all recorded values.
  final int count;

  /// The bucket boundaries.
  final List<double> boundaries;

  /// The counts in each bucket.
  final List<int> bucketCounts;

  /// The minimum recorded value (optional).
  final num? min;

  /// The maximum recorded value (optional).
  final num? max;

  /// Creates a new HistogramValue.
  HistogramValue({
    required this.sum,
    required this.count,
    required this.boundaries,
    required this.bucketCounts,
    this.min,
    this.max,
  });
}
