// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../data/metric_point.dart';
import '../data/exemplar.dart';
import 'point_storage.dart';

/// GaugeStorage is used for storing the last recorded value for each set of attributes.
class GaugeStorage<T extends num> extends PointStorage<T> {
  /// Map of attribute sets to gauge data.
  final Map<Attributes, _GaugePointData> _points = {};

  /// Creates a new GaugeStorage instance.
  GaugeStorage();

  /// Records a measurement with the given attributes.
  @override
  void record(T value, [Attributes? attributes]) {
    // Create a normalized key for lookup
    final key = attributes ?? _emptyAttributes();

    // Always update with the latest value
    _points[key] = _GaugePointData(
      value: value,
      updateTime: DateTime.now(),
    );
  }

  /// Helper to get empty attributes safely
  Attributes _emptyAttributes() {
    // If OTelFactory is not initialized yet, create an empty attributes directly
    if (OTelFactory.otelFactory == null) {
      return OTelAPI.attributes(); // Use the API's static method instead
    }
    return OTelFactory.otelFactory!.attributes();
  }

  /// Gets the current value for the given attributes.
  /// Returns 0 if no value has been recorded for these attributes.
  @override
  T getValue([Attributes? attributes]) {
    // Create a normalized key for lookup
    final key = attributes ?? _emptyAttributes();

    // Find matching attributes
    var existingKey = _findMatchingKey(key);
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

  /// Finds a key in the points map that equals the given key
  Attributes? _findMatchingKey(Attributes key) {
    for (final existingKey in _points.keys) {
      if (existingKey == key) { // Using the == operator which should call equals
        return existingKey;
      }
    }
    return null;
  }

  /// Collects the current set of metric points.
  @override
  List<MetricPoint> collectPoints() {
    final now = DateTime.now();

    return _points.entries.map((entry) {
      final data = entry.value;

      return MetricPoint.gauge(
        attributes: entry.key,
        startTime: data.updateTime, // For gauges, start time is the update time
        time: now,
        value: data.value,
        exemplars: data.exemplars,
      );
    }).toList();
  }

  /// Resets all points (not typically used for Gauges, but required by interface).
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

/// Data for a single gauge point.
class _GaugePointData {
  /// The current value.
  final num value;

  /// The time this value was recorded.
  final DateTime updateTime;

  /// Exemplars for this point.
  final List<Exemplar> exemplars = [];

  _GaugePointData({
    required this.value,
    required this.updateTime,
  });
}
