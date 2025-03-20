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
  final Map<Attributes?, _SumPointData> _points = {};

  /// Whether the sum is monotonic (only increases).
  final bool isMonotonic;

  /// The start time for all points.
  final DateTime _startTime = DateTime.now();

  /// Creates a new SumStorage instance.
  SumStorage({
    required this.isMonotonic,
  });

  /// Records a measurement with the given attributes.
  /// For synchronous counters, this is a delta that gets added to the existing value.
  /// For asynchronous counters (Observable), this should be the absolute value.
  @override
  void record(T value, [Attributes? attributes]) {
    // Check constraints for monotonic counters
    if (isMonotonic && value < 0) {
      print('Warning: Negative value $value provided to monotonic sum storage. '
            'This will be ignored.');
      return;
    }

    // Check if we already have an entry for these attributes
    if (_points.containsKey(attributes)) {
      // Add to existing data point
      _points[attributes]!.add(value);
    } else {
      // Create new data point
      _points[attributes] = _SumPointData(
        value: value,
        lastUpdateTime: DateTime.now(),
      );
    }
  }

  /// Gets the current value for the given attributes.
  /// If no attributes are provided, returns the sum across all attribute sets.
  @override
  T getValue([Attributes? attributes]) {
    num result;
    
    if (attributes == null) {
      // Sum of all values across all attribute sets
      result = _points.values.fold<num>(0, (sum, data) => sum + data.value);
    } else if (_points.containsKey(attributes)) {
      // Return the value for the specific attributes
      result = _points[attributes]!.value;
    } else {
      // No entry for these attributes
      result = 0;
    }
    
    // Convert to the appropriate generic type
    if (T == int) {
      return result.toInt() as T;
    } else if (T == double) {
      return result.toDouble() as T;
    } else {
      return result as T;
    }
  }

  /// Collects the current set of metric points.
  @override
  List<MetricPoint> collectPoints() {
    final now = DateTime.now();

    return _points.entries.map((entry) {
      // Convert null attributes to empty attributes for MetricPoint
      final attributes = entry.key ?? OTelFactory.otelFactory!.attributes();
      
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
  void addExemplar(Exemplar exemplar, [Attributes? attributes]) {
    if (_points.containsKey(attributes)) {
      _points[attributes]!.exemplars.add(exemplar);
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

  /// Adds a value to this point (for synchronous counters).
  void add(num delta) {
    value += delta;
    lastUpdateTime = DateTime.now();
  }
  
  /// Sets the value directly (for asynchronous counters).
  void setValue(num newValue) {
    value = newValue;
    lastUpdateTime = DateTime.now();
  }
  
  @override
  String toString() => 'SumPointData(value: $value)';
}
