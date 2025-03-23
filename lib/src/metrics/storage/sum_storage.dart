// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../data/metric_point.dart';
import '../data/exemplar.dart';
import 'point_storage.dart';

/// SumStorage is used for storing and accumulating sum-based metrics
/// like Counter and UpDownCounter.
class SumStorage<T extends num> extends PointStorage<T> {
  /// Map of attribute sets to accumulated values.
  final Map<Attributes, _SumPointData> _points = {};

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
  void record(T value, [Attributes? attributes]) {
    // Check constraints
    if (isMonotonic && value < 0) {
      print('Warning: Negative value $value provided to monotonic sum storage. '
            'This will be ignored.');
      return;
    }

    // If attributes is null, use an empty map to avoid storing null values
    final key = attributes ?? OTelFactory.otelFactory!.attributes();

    if (_points.containsKey(key)) {
      // Update existing point
      _points[key]!.add(value);
    } else {
      // Create new point
      _points[key] = _SumPointData(
        value: value,
        lastUpdateTime: DateTime.now(),
      );
    }
  }

  /// Gets the current value for the given attributes.
  /// If no attributes are provided, returns the sum of all values.
  @override
  T getValue([Attributes? attributes]) {
    final num value;
    
    if (attributes == null) {
      // Sum all points
      value = _points.values.fold<num>(0, (sum, point) => sum + point.value);
    } else {
      // Get specific point
      value = _points[attributes]?.value ?? 0;
    }
    
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
      return MetricPoint.sum(
        attributes: entry.key,
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
  void addExemplar(Exemplar exemplar, [Attributes? attributes]) {
    // If attributes is null, use an empty map to avoid storing null values
    final key = attributes ?? OTelFactory.otelFactory!.attributes();

    if (_points.containsKey(key)) {
      _points[key]!.exemplars.add(exemplar);
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
