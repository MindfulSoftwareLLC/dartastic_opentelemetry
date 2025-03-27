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
  /// For synchronous counters, this is a delta that gets added to the existing value.
  /// For asynchronous counters (Observable), this should be the absolute value.
  @override
  void record(T value, [Attributes? attributes]) {
    // Check constraints
    if (isMonotonic && value < 0) {
      print('Warning: Negative value $value provided to monotonic sum storage. '
            'This will be ignored.');
      return;
    }

    // Create a normalized key for lookup
    final key = attributes ?? _emptyAttributes();

    // Find matching attributes or use the new key directly
    var existingKey = _findMatchingKey(key);
    if (existingKey != null) {
      // For synchronous counters, add to the existing value
      // For asynchronous counters, this would replace the value instead
      _points[existingKey]!.add(value);
    } else {
      // Create new point
      _points[key] = _SumPointData(
        value: value,
        lastUpdateTime: DateTime.now(),
      );
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
  /// If no attributes are provided, returns the sum across all attribute sets.
  @override
  T getValue([Attributes? attributes]) {
    if (attributes == null) {
      // Sum across all attribute sets
      final num totalSum = _points.values.fold<num>(0, (sum, data) => sum + data.value);
      
      // Convert to the appropriate generic type
      if (T == int) {
        return totalSum.toInt() as T;
      } else if (T == double) {
        return totalSum.toDouble() as T;
      } else {
        return totalSum as T;
      }
    }
    
    // Find matching attributes
    var existingKey = _findMatchingKey(attributes);
    final num value = existingKey != null ? _points[existingKey]!.value : 0;
    
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
    // Create a normalized key for lookup
    final key = attributes ?? _emptyAttributes();
    
    // Find matching attributes
    var existingKey = _findMatchingKey(key);
    if (existingKey != null) {
      _points[existingKey]!.exemplars.add(exemplar);
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
}
