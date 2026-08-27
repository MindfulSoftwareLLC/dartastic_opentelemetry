// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../data/metric_point.dart';
import '../exemplar_filter.dart';
import '../exemplar_reservoir.dart';
import 'metric_storage.dart';

/// GaugeStorage is used for storing the last recorded value for each set of attributes.
class GaugeStorage<T extends num> extends NumericStorage<T>
    with ExemplarSampling<T> {
  /// Map of attribute sets to gauge data.
  final Map<Attributes, _GaugePointData<T>> _points = {};

  /// The exemplar filter used by this storage.
  @override
  final ExemplarFilter exemplarFilter;

  /// Creates a new GaugeStorage instance.
  GaugeStorage({ExemplarFilter? exemplarFilter})
      : exemplarFilter = exemplarFilter ?? const TraceBasedExemplarFilter();

  /// Records a measurement with the given attributes and context.
  @override
  void record(T value,
      [Attributes? attributes, Context? context, DateTime? timestamp]) {
    // Create a normalized key for lookup
    final key = attributes ?? _emptyAttributes();
    final existingKey = _findMatchingKey(key);

    _GaugePointData<T> pointData;
    if (existingKey != null) {
      pointData = _points[existingKey]!;
      pointData.value = value;
      pointData.updateTime = DateTime.now();
    } else {
      pointData = _GaugePointData<T>(
        value: value,
        updateTime: DateTime.now(),
        reservoir:
            SimpleFixedSizeExemplarReservoir(1), // Simple fixed size of 1
      );
      // Always update with the latest value
      _points[key] = pointData;
    }

    maybeOffer(pointData.reservoir, value, key, context ?? Context.current,
        timestamp ?? DateTime.now());
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
    final existingKey = _findMatchingKey(key);

    if (existingKey != null) {
      return _points[existingKey]!.value;
    } else {
      // Convert 0 to the appropriate generic type
      if (T == int) {
        return 0 as T;
      } else if (T == double) {
        return 0.0 as T;
      } else {
        return 0 as T;
      }
    }
  }

  /// Finds a key in the points map that equals the given key
  Attributes? _findMatchingKey(Attributes key) {
    for (final existingKey in _points.keys) {
      if (existingKey == key) {
        // Using the == operator which should call equals
        return existingKey;
      }
    }
    return null;
  }

  /// Collects the current set of metric points.
  @override
  List<MetricPoint<T>> collectPoints() {
    final now = DateTime.now();

    return _points.entries.map((entry) {
      final data = entry.value;

      return MetricPoint<T>.gauge(
        attributes: entry.key,
        startTime: data.updateTime, // For gauges, start time is the update time
        time: now,
        value: data.value,
        exemplars: data.reservoir.collectAndReset(entry.key),
      );
    }).toList();
  }

  /// Resets all points (not typically used for Gauges, but required by interface).
  @override
  void reset() {
    _points.clear();
  }
}

/// Data for a single gauge point.
class _GaugePointData<T extends num> {
  /// The current value.
  T value;

  /// The time this value was recorded.
  DateTime updateTime;

  /// Reservoir for this point.
  final ExemplarReservoir reservoir;

  _GaugePointData(
      {required this.value, required this.updateTime, required this.reservoir});
}
