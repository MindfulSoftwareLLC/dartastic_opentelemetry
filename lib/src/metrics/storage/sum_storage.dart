// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../data/metric_point.dart';
import '../data/exemplar.dart';
import 'point_storage.dart';

/// SumStorage is used for storing and accumulating sum-based metrics
/// like Counter and UpDownCounter.
class SumStorage<T extends num> extends PointStorage {
  /// Map of attribute sets to accumulated values.
  final Map<int, _SumPointData> _points = {};

  /// Map to store attributes by their hash codes for faster lookup
  final Map<int, Attributes> _attributesMap = {};

  /// Whether the sum is monotonic (only increases).
  final bool isMonotonic;

  /// The start time for all points.
  final DateTime _startTime = DateTime.now();

  /// Creates a new SumStorage instance.
  SumStorage({
    required this.isMonotonic,
  });

  /// Records a measurement with the given attributes.
  @override
  void record(num value, Attributes attributes) {
    // Check constraints
    if (isMonotonic && value < 0) {
      print('Warning: Negative value $value provided to monotonic sum storage. '
            'This will be ignored.');
      return;
    }

    // Use hash code for more reliable lookup
    final attributesHash = attributes.hashCode;

    // Store the attributes in our map for later retrieval
    if (!_attributesMap.containsKey(attributesHash)) {
      _attributesMap[attributesHash] = attributes;
    }

    if (_points.containsKey(attributesHash)) {
      // Update existing point
      _points[attributesHash]!.add(value);
    } else {
      // Create new point
      _points[attributesHash] = _SumPointData(
        value: value,
        lastUpdateTime: DateTime.now(),
      );
    }
  }

  /// Gets the current value for the given attributes.
  /// If no attributes are provided, returns the sum of all values.
  T getValue(Attributes attributes) {
    final attributesHash = attributes.hashCode;

    // Get specific point
    return _points[attributesHash]?.value ?? 0;
  }

  /// Collects the current set of metric points.
  @override
  List<MetricPoint> collectPoints() {
    final now = DateTime.now();

    return _points.entries.map((entry) {
      final attributesHash = entry.key;
      final attributes = _attributesMap[attributesHash]!;

      return MetricPoint.sum(
        attributes: attributes,
        startTime: _startTime,
        time: now,
        value: entry.value.value,
        isMonotonic: isMonotonic,
        exemplars: entry.value.exemplars,
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
  void addExemplar(Exemplar exemplar, Attributes attributes) {
    final attributesHash = attributes.hashCode;

    if (_points.containsKey(attributesHash)) {
      _points[attributesHash]!.exemplars.add(exemplar);
    }
  }
}

/// Data for a single sum point.
class _SumPointData {
  /// The accumulated value.
  num value;

  /// The time this point was last updated.
  DateTime lastUpdateTime;

  /// Exemplars for this point.
  final List<Exemplar> exemplars = [];

  _SumPointData({
    required this.value,
    required this.lastUpdateTime,
  });

  /// Adds a value to this point.
  void add(num delta) {
    value += delta;
    lastUpdateTime = DateTime.now();
  }
}
