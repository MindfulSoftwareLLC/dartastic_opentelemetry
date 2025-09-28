// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../data/metric.dart';
import '../data/metric_point.dart';
import '../meter.dart';
import '../storage/sum_storage.dart';
import 'base_instrument.dart';

/// A synchronous instrument that records monotonically increasing values.
///
/// A Counter is used to measure a non-negative, monotonically increasing value.
/// Counters only allow positive increments and are appropriate for values that
/// never decrease, such as:
/// - Request count
/// - Completed operations
/// - Error count
/// - CPU time used
/// - Bytes sent/received
///
/// If the value can decrease, use an UpDownCounter instead.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/api/#counter
class Counter<T extends num> implements APICounter<T>, SDKInstrument {
  /// The underlying API Counter.
  final APICounter<T> _apiCounter;

  /// The Meter that created this Counter.
  final Meter _meter;

  /// Storage for accumulating counter measurements.
  final SumStorage<T> _storage = SumStorage<T>(isMonotonic: true);

  /// Creates a new Counter instance.
  ///
  /// @param apiCounter The API Counter to delegate API calls to
  /// @param meter The Meter that created this Counter
  Counter({
    required APICounter<T> apiCounter,
    required Meter meter,
  })  : _apiCounter = apiCounter,
        _meter = meter {
    _meter.provider.registerInstrument(_meter.name, this);
  }

  /// Gets the name of this counter.
  @override
  String get name => _apiCounter.name;

  /// Gets the unit of measurement for this counter.
  @override
  String? get unit => _apiCounter.unit;

  /// Gets the description of this counter.
  @override
  String? get description => _apiCounter.description;

  /// Checks if this counter is enabled.
  ///
  /// If false, measurements will be dropped and not recorded.
  @override
  bool get enabled => _meter.enabled;

  /// Gets the meter that created this counter.
  @override
  APIMeter get meter => _meter;

  /// Always true for Counter instruments.
  @override
  bool get isCounter => true;

  /// Always false for Counter instruments.
  @override
  bool get isUpDownCounter => false;

  /// Always false for Counter instruments.
  @override
  bool get isGauge => false;

  /// Always false for Counter instruments.
  @override
  bool get isHistogram => false;

  /// Records a measurement with this counter.
  ///
  /// This method increments the counter by the given value. The value must be
  /// non-negative, or an ArgumentError will be thrown.
  ///
  /// @param value The amount to increment the counter by (must be non-negative)
  /// @param attributes Optional attributes to associate with this measurement
  /// @throws ArgumentError if value is negative
  @override
  void add(T value, [Attributes? attributes]) {
    // First use the API implementation (no-op by default)
    _apiCounter.add(value, attributes);

    // Check for negative values
    if (value < 0) {
      throw ArgumentError('Counter value must be non-negative');
    }

    // Only record if enabled
    if (!enabled) return;

    // Record the measurement in our storage
    _storage.record(value, attributes);
  }

  /// Records a measurement with attributes specified as a map.
  ///
  /// This is a convenience method that converts the map to Attributes
  /// and calls add().
  ///
  /// @param value The amount to increment the counter by (must be non-negative)
  /// @param attributeMap Map of attribute names to values
  @override
  void addWithMap(T value, Map<String, Object> attributeMap) {
    // Just convert to Attributes and call add
    final attributes =
        attributeMap.isEmpty ? null : attributeMap.toAttributes();
    add(value, attributes);
  }

  /// Gets the current value of the counter for a specific set of attributes.
  ///
  /// If no attributes are provided, returns the sum of all values across all attributes.
  ///
  /// @param attributes Optional attributes to filter by
  /// @return The current value of the counter
  T getValue([Attributes? attributes]) {
    return _storage.getValue(attributes);
  }

  /// Gets the current points for this counter.
  ///
  /// This is used by the SDK to collect metrics for export.
  ///
  /// @return A list of metric points containing the current counter values
  List<MetricPoint<T>> collectPoints() {
    return _storage.collectPoints();
  }

  /// Collects metrics for this counter.
  ///
  /// This method is called by the SDK to collect metrics for export.
  ///
  /// @return A list of metrics containing the current counter values
  @override
  List<Metric> collectMetrics() {
    if (!enabled) return [];

    // Get the points from storage
    final points = collectPoints();

    if (points.isEmpty) return [];

    final metric = Metric(
      name: name,
      description: description,
      unit: unit,
      type: MetricType.sum,
      points: points,
    );

    return [metric];
  }

  /// Resets the counter.
  ///
  /// This is only used for Delta temporality and should not be called
  /// by application code.
  void reset() {
    _storage.reset();
  }
}
