// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../data/metric_point.dart';
import '../data/exemplar.dart';
import 'point_storage.dart';

/// HistogramStorage is used for storing and accumulating histogram data.
class HistogramStorage<T extends num> extends PointStorage<T> {
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
  void record(T value, [Attributes? attributes]) {
    // Create a normalized key for lookup
    final key = attributes ?? _emptyAttributes();

    // Find matching attributes
    var existingKey = _findMatchingKey(key);
    if (existingKey != null) {
      // Update existing point
      _points[existingKey]!.record(value);
    } else {
      // Create new point
      _points[key] = _HistogramPointData(
        boundaries: boundaries,
        recordMinMax: recordMinMax,
      )..record(value);
    }
  }
  
  /// Helper to get empty attributes safely
  Attributes _emptyAttributes() {
    // If OTelFactory is not initialized yet, create an empty attributes directly
    if (OTelFactory.otelFactory == null) {
      return OTelAPI.attributes(); // Use the API's static method instead
    }
    return OTelFactory.otelFactory!.attributes();
  }
  
  /// Finds a key in the points map that equals the given key
  Attributes? _findMatchingKey(Attributes key) {
    for (final existingKey in _points.keys) {
      if (existingKey == key) { // Using the == operator which should call equals
        return existingKey;
      }
    }
    return null;
  }

  /// Gets the current value for the given attributes.
  /// For histograms, this returns the sum of all recorded values for the attribute set.
  @override
  T getValue([Attributes? attributes]) {
    // Create a normalized key for lookup
    final key = attributes ?? _emptyAttributes();
    
    // Find matching attributes
    var existingKey = _findMatchingKey(key);
    final num value = existingKey != null ? _points[existingKey]!.sum : 0;
    
    // Convert to the appropriate generic type
    if (T == int) {
      return value.toInt() as T;
    } else if (T == double) {
      return value.toDouble() as T;
    } else {
      return value as T;
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
    // Create a normalized key for lookup
    final key = attributes ?? _emptyAttributes();
    
    // Find matching attributes
    var existingKey = _findMatchingKey(key);
    if (existingKey != null) {
      _points[existingKey]!.exemplars.add(exemplar);
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
