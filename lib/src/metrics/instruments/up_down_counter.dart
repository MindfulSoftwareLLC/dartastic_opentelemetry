// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../../otel.dart';
import '../meter.dart';
import '../data/metric_point.dart';
import '../storage/sum_storage.dart';
import '../data/metric.dart';
import 'base_instrument.dart';

/// UpDownCounter is a synchronous instrument that records additive values.
///
/// An UpDownCounter is used to measure a value that increases and decreases.
/// For example, the number of active requests, queue size, pool size.
class UpDownCounter<T extends num> implements APIUpDownCounter<T>, BaseInstrument {
  /// The underlying API UpDownCounter.
  final APIUpDownCounter<T> _apiCounter;

  /// The Meter that created this UpDownCounter.
  final Meter _meter;

  /// Storage for accumulating up-down counter measurements.
  final SumStorage _storage = SumStorage(isMonotonic: false);

  /// Creates a new UpDownCounter instance.
  UpDownCounter({
    required APIUpDownCounter<T> apiCounter,
    required Meter meter,
  }) : _apiCounter = apiCounter,
       _meter = meter {
    // Register this instrument with the meter provider
      _meter.provider.registerInstrument(_meter.name, this);
    }

  @override
  String get name => _apiCounter.name;

  @override
  String? get unit => _apiCounter.unit;

  @override
  String? get description => _apiCounter.description;

  @override
  bool get enabled => _apiCounter.enabled && _meter.enabled;

  @override
  APIMeter get meter => _meter;

  @override
  bool get isCounter => false;

  @override
  bool get isUpDownCounter => true;

  @override
  bool get isGauge => false;

  @override
  bool get isHistogram => false;

  @override
  void add(T value, [Attributes? attributes]) {
    // First use the API implementation (no-op by default)
    _apiCounter.add(value, attributes);

    // Only record if enabled
    if (!enabled) return;

    // Record the measurement in our storage
    _storage.record(value, attributes ?? OTel.attributes());
  }

  @override
  void addWithMap(T value, Map<String, Object> attributeMap) {
    // Just convert to Attributes and call add
    final attributes = attributeMap.isEmpty ? null : attributeMap.toAttributes();
    add(value, attributes);
  }

  /// Gets the current value of the counter for a specific set of attributes.
  /// If no attributes are provided, returns the sum for all attribute combinations.
  T getValue([Attributes? attributes]) {
    final value = _storage.getValue(attributes);
    // Handle the cast to the generic type
    if (T == int) return value.toInt() as T;
    if (T == double) return value.toDouble() as T;
    return value as T;
  }

  /// Gets the current points for this counter.
  /// This is used by the SDK to collect metrics.
  List<MetricPoint> collectPoints() {
    return _storage.collectPoints();
  }

  @override
  List<Metric> collectMetrics() {
    if (!enabled) return [];

    // Get the points from storage
    final points = collectPoints();

    if (points.isEmpty) return [];

    // Create a metric with the collected points
    final metric = Metric(
      name: name,
      description: description,
      unit: unit,
      type: MetricType.sum, // UpDownCounter is still a sum, just not monotonic
      points: points,
    );

    return [metric];
  }

  /// Resets the counter. This is only used for Delta temporality.
  void reset() {
    _storage.reset();
  }
}
