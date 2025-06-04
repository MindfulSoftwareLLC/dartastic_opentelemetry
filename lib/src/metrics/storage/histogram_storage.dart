// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../data/exemplar.dart';
import '../data/metric_point.dart';
import 'metric_storage.dart';

/// HistogramStorage is used for storing and accumulating histogram data.
class HistogramStorage<T extends num> extends HistogramStorageBase<T> {
  /// Map of attribute sets to histogram data.
  final Map<Attributes, _HistogramPointData<T>> _points = {};

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
    final existingKey = _findMatchingKey(key);
    if (existingKey != null) {
      // Update existing point
      _points[existingKey]!.record(value);
    } else {
      // Create new point
      _points[key] = _HistogramPointData<T>(
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

  /// Gets the current histogram value for the given attributes.
  /// If no attributes are provided, returns a combined HistogramValue across all attribute sets.
  @override
  HistogramValue getValue([Attributes? attributes]) {
    if (attributes == null) {
      // Combine across all attribute sets
      final num totalSum = _points.values.fold<num>(0, (sum, data) => sum + data.sum);
      final int totalCount = _points.values.fold<int>(0, (count, data) => count + data.count);
      
      // Combine bucket counts
      final List<int> combinedCounts = List<int>.filled(boundaries.length + 1, 0);
      for (final data in _points.values) {
        for (int i = 0; i < data.counts.length; i++) {
          combinedCounts[i] += data.counts[i];
        }
      }
      
      // Find overall min and max
      num? overallMin;
      num? overallMax;
      if (recordMinMax && _points.isNotEmpty) {
        overallMin = _points.values.map((data) => data.min).where((min) => min != double.infinity).isEmpty ? null :
                    _points.values.map((data) => data.min).where((min) => min != double.infinity).reduce((a, b) => a < b ? a : b);
        overallMax = _points.values.map((data) => data.max).where((max) => max != double.negativeInfinity).isEmpty ? null :
                    _points.values.map((data) => data.max).where((max) => max != double.negativeInfinity).reduce((a, b) => a > b ? a : b);
      }
      
      return HistogramValue(
        sum: totalSum,
        count: totalCount,
        boundaries: boundaries,
        bucketCounts: combinedCounts,
        min: overallMin,
        max: overallMax,
      );
    }
    
    // Find matching attributes
    final existingKey = _findMatchingKey(attributes);
    if (existingKey != null) {
      final data = _points[existingKey]!;
      return HistogramValue(
        sum: data.sum,
        count: data.count,
        boundaries: boundaries,
        bucketCounts: data.counts,
        min: recordMinMax && data.min != double.infinity ? data.min : null,
        max: recordMinMax && data.max != double.negativeInfinity ? data.max : null,
      );
    } else {
      // Return empty histogram
      return HistogramValue(
        sum: 0,
        count: 0,
        boundaries: boundaries,
        bucketCounts: List<int>.filled(boundaries.length + 1, 0),
        min: null,
        max: null,
      );
    }
  }

  /// Collects the current set of metric points.
  @override
  List<MetricPoint<HistogramValue>> collectPoints() {
    final now = DateTime.now();

    return _points.entries.map((entry) {
      final data = entry.value;
      
      // Create a HistogramValue directly
      final histogramValue = HistogramValue(
        sum: data.sum,
        count: data.count,
        boundaries: boundaries,
        bucketCounts: data.counts,
        min: recordMinMax && data.min != double.infinity ? data.min : null,
        max: recordMinMax && data.max != double.negativeInfinity ? data.max : null,
      );

      // Create a MetricPoint<HistogramValue> - no type casting needed!
      return MetricPoint<HistogramValue>(
        attributes: entry.key,
        startTime: _startTime,
        endTime: now,
        value: histogramValue,
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
    final existingKey = _findMatchingKey(key);
    if (existingKey != null) {
      _points[existingKey]!.exemplars.add(exemplar);
    }
  }
}

/// Data for a single histogram point.
class _HistogramPointData<T extends num> {
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
  void record(T value) {
    count++;
    sum += value;

    if (recordMinMax) {
      final num numValue = value;
      if (numValue < min) min = numValue;
      if (numValue > max) max = numValue;
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
