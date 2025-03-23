// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../data/metric_point.dart';
import '../data/exemplar.dart';
import 'point_storage.dart';

/// GaugeStorage is used for storing the last recorded value for each set of attributes.
class GaugeStorage extends PointStorage {
  /// Map of attribute sets to gauge data.
  final Map<Attributes, _GaugePointData> _points = {};

  /// Creates a new GaugeStorage instance.
  GaugeStorage();

  /// Records a measurement with the given attributes.
  @override
  void record(num value, [Attributes? attributes]) {
    // If attributes is null, use an empty map to avoid storing null values
    final key = attributes ?? OTelFactory.otelFactory!.attributes();

    // Always update with the latest value
    _points[key] = _GaugePointData(
      value: value,
      updateTime: DateTime.now(),
    );
  }

  /// Gets the current value for the given attributes.
  /// Returns 0 if no value has been recorded for these attributes.
  num getValue([Attributes? attributes]) {
    if (attributes == null) {
      // For gauges without attributes, we return the average of all values
      // This is a heuristic - you might want to change this behavior based on requirements
      if (_points.isEmpty) return 0;
      return _points.values.fold<num>(0, (sum, point) => sum + point.value) / _points.length;
    }
    return _points[attributes]?.value ?? 0;
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
    // For gauges, we don't clear values on reset
    // since they represent the current state
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
