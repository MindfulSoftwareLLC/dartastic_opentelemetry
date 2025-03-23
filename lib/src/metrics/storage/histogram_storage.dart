// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../data/metric_point.dart';
import '../data/exemplar.dart';
import 'point_storage.dart';

/// HistogramStorage is used for storing and accumulating histogram data.
class HistogramStorage extends PointStorage {
  /// Map of attribute sets to histogram data.
  final Map<Attributes, _HistogramPointData> _points = {};

  /// The bucket boundaries for this histogram.
  final List<double> boundaries;

  /// Whether to record min and max values.
  final bool recordMinMax;

  /// The start time for all points.
  final DateTime _startTime = DateTime.now();

  /// Creates a new HistogramStorage instance.
  HistogramStorage({
    required this.boundaries,
    this.recordMinMax = true,
  });

  /// Records a measurement with the given attributes.
  @override
  void record(num value, [Attributes? attributes]) {
    // If attributes is null, use an empty map to avoid storing null values
    final key = attributes ?? OTelFactory.otelFactory!.attributes();

    if (_points.containsKey(key)) {
      // Update existing point
      _points[key]!.record(value);
    } else {
      // Create new point
      _points[key] = _HistogramPointData(
        boundaries: boundaries,
        recordMinMax: recordMinMax,
      )..record(value);
    }
  }

  /// Collects the current set of metric points.
  @override
  List<MetricPoint> collectPoints() {
    final now = DateTime.now();

    return _points.entries.map((entry) {
      final data = entry.value;

      return MetricPoint.histogram(
        attributes: entry.key,
        startTime: _startTime,
        time: now,
        count: data.count,
        sum: data.sum,
        counts: data.counts,
        boundaries: boundaries,
        min: recordMinMax ? data.min : null,
        max: recordMinMax ? data.max : null,
        exemplars: data.exemplars,
      );
    }).toList();
  }

  /// Resets all points (for delta temporality).
  @override
  void reset() {
    _points.clear();
  }

  /// Adds an exemplar to a specific point.
  @override
  void addExemplar(Exemplar exemplar, [Attributes? attributes]) {
    // If attributes is null, use an empty map to avoid storing null values
    final key = attributes ?? OTelFactory.otelFactory!.attributes();

    if (_points.containsKey(key)) {
      _points[key]!.exemplars.add(exemplar);
    }
  }
}

/// Data for a single histogram point.
class _HistogramPointData {
  /// The total count of measurements.
  int count = 0;

  /// The sum of all measurements.
  num sum = 0;

  /// The minimum value recorded.
  num min = double.infinity;

  /// The maximum value recorded.
  num max = double.negativeInfinity;

  /// The counts per bucket.
  late List<int> counts;

  /// The bucket boundaries.
  final List<double> boundaries;

  /// Whether to record min and max values.
  final bool recordMinMax;

  /// Exemplars for this point.
  final List<Exemplar> exemplars = [];

  _HistogramPointData({
    required this.boundaries,
    required this.recordMinMax,
  }) {
    // Initialize count array with one more than boundaries
    // (for the +Inf bucket)
    counts = List<int>.filled(boundaries.length + 1, 0);
  }

  /// Records a measurement.
  void record(num value) {
    count++;
    sum += value;

    if (recordMinMax) {
      if (value < min) min = value;
      if (value > max) max = value;
    }

    // Find the right bucket
    int bucketIndex = boundaries.length; // Default to the +Inf bucket
    for (int i = 0; i < boundaries.length; i++) {
      if (value <= boundaries[i]) {
        bucketIndex = i;
        break;
      }
    }

    // Increment the bucket count
    counts[bucketIndex]++;
  }
}
