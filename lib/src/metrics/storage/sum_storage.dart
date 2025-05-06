// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../data/exemplar.dart';
import '../data/metric_point.dart';
import 'point_storage.dart';

/// Storage implementation for sum-based metrics like Counter and UpDownCounter.
///
/// SumStorage accumulates measurements for sum-based instruments. It maintains
/// separate accumulated values for each unique set of attributes, and provides
/// methods to collect the current state as metric points.
///
/// This storage implementation supports both monotonic sums (like Counter)
/// and non-monotonic sums (like UpDownCounter).
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/sdk/#the-temporality-of-instruments
class SumStorage<T extends num> extends PointStorage<T> {
  /// Map of attribute sets to accumulated values.
  final Map<Attributes?, _SumPointData<T>> _points = {};

  /// Whether the sum is monotonic (only increases).
  ///
  /// Monotonic sums only accept positive increments and are
  /// appropriate for counters that never decrease.
  final bool isMonotonic;

  /// The start time for all points.
  ///
  /// This is used for cumulative temporality reporting.
  final DateTime _startTime = DateTime.now();

  /// Creates a new SumStorage instance.
  ///
  /// @param isMonotonic Whether this storage is for a monotonic sum
  SumStorage({
    required this.isMonotonic,
  });

  /// Records a measurement with the given attributes.
  ///
  /// For synchronous instruments, this is a delta that gets added to the existing value.
  /// For asynchronous instruments, this should be the absolute value.
  ///
  /// @param value The value to record
  /// @param attributes Optional attributes to associate with this measurement
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
      _points[attributes] = _SumPointData<T>(
        value: value,
        lastUpdateTime: DateTime.now(),
      );
    }
  }

  /// Gets the current value for the given attributes.
  ///
  /// If no attributes are provided, returns the sum across all attribute sets.
  ///
  /// @param attributes Optional attributes to filter by
  /// @return The current accumulated value
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
  ///
  /// This method is used by the instrument to collect all current
  /// sum values as metric points for export.
  ///
  /// @return A list of metric points containing the current values
  @override
  List<MetricPoint<T>> collectPoints() {
    final now = DateTime.now();

    return _points.entries.map((entry) {
      // Convert null attributes to empty attributes for MetricPoint
      final attributes = entry.key ?? OTelFactory.otelFactory!.attributes();
      
      // Convert numeric value to the specific generic type T
      final T typedValue;
      if (T == int) {
        typedValue = entry.value.value.toInt() as T;
      } else if (T == double) {
        typedValue = entry.value.value.toDouble() as T;
      } else {
        typedValue = entry.value.value;
      }
      
      return MetricPoint<T>.sum(
        attributes: attributes,
        startTime: _startTime,
        time: now,
        value: typedValue,
        isMonotonic: isMonotonic,
        exemplars: entry.value.exemplars,
      );
    }).toList();
  }

  /// Resets all points (for delta temporality).
  ///
  /// This method clears all accumulated values. It is used when
  /// reporting with delta temporality to reset the accumulation
  /// after each export.
  @override
  void reset() {
    _points.clear();
  }

  /// Adds an exemplar to a specific point.
  ///
  /// Exemplars are example measurements that provide additional
  /// context about specific observations.
  ///
  /// @param exemplar The exemplar to add
  /// @param attributes The attributes identifying the point to add the exemplar to
  @override
  void addExemplar(Exemplar exemplar, [Attributes? attributes]) {
    if (_points.containsKey(attributes)) {
      _points[attributes]!.exemplars.add(exemplar);
    }
  }
}

/// Internal class representing data for a single sum point.
///
/// This class tracks the accumulated value, last update time,
/// and exemplars for a specific combination of attributes.
class _SumPointData<T extends num> {
  /// The accumulated value.
  T value;

  /// The time this point was last updated.
  DateTime lastUpdateTime;

  /// Exemplars for this point.
  final List<Exemplar> exemplars = [];

  /// Creates a new _SumPointData instance.
  ///
  /// @param value The initial value
  /// @param lastUpdateTime The time of the initial value
  _SumPointData({
    required this.value,
    required this.lastUpdateTime,
  });

  /// Adds a value to this point (for synchronous counters).
  ///
  /// @param delta The value to add to the accumulated value
  void add(T delta) {
    // Handle the addition with proper type conversion
    if (T == int) {
      value = (value + delta).toInt() as T;
    } else if (T == double) {
      value = (value + delta).toDouble() as T;
    } else {
      value = (value + delta) as T;
    }
    
    lastUpdateTime = DateTime.now();
  }
  
  /// Sets the value directly (for asynchronous counters).
  ///
  /// @param newValue The new absolute value to set
  void setValue(T newValue) {
    value = newValue;
    lastUpdateTime = DateTime.now();
  }
  
  @override
  String toString() => 'SumPointData(value: $value)';
}
