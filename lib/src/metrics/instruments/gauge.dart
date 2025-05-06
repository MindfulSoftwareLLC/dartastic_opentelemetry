// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../data/metric.dart';
import '../data/metric_point.dart';
import '../meter.dart';
import '../storage/gauge_storage.dart';
import 'base_instrument.dart';

/// Gauge is a synchronous instrument that records non-additive values.
///
/// A Gauge is used to measure a non-additive value that represents the current
/// state, such as temperature, memory usage, or CPU utilization.
class Gauge<T extends num> implements APIGauge<T>, SDKInstrument {
  /// The underlying API Gauge.
  final APIGauge<T> _apiGauge;

  /// The Meter that created this Gauge.
  final Meter _meter;

  /// Storage for gauge measurements.
  final GaugeStorage<T> _storage = GaugeStorage<T>();

  /// Creates a new Gauge instance.
  Gauge({
    required APIGauge<T> apiGauge,
    required Meter meter,
  }) : _apiGauge = apiGauge,
       _meter = meter {
    // Register this instrument with the meter provider
    _meter.provider.registerInstrument(_meter.name, this);
  }

  @override
  String get name => _apiGauge.name;

  @override
  String? get unit => _apiGauge.unit;

  @override
  String? get description => _apiGauge.description;

  @override
  bool get enabled => _meter.enabled;

  @override
  APIMeter get meter => _meter;

  @override
  bool get isCounter => false;

  @override
  bool get isUpDownCounter => false;

  @override
  bool get isGauge => true;

  @override
  bool get isHistogram => false;

  @override
  void record(T value, [Attributes? attributes]) {
    // First use the API implementation (no-op by default)
    _apiGauge.record(value, attributes);

    // Only record if enabled
    if (!enabled) return;

    // Record the measurement in our storage
    _storage.record(value, attributes);
  }

  @override
  void recordWithMap(T value, Map<String, Object> attributeMap) {
    // Just convert to Attributes and call record
    final attributes = attributeMap.isEmpty ? null : attributeMap.toAttributes();
    record(value, attributes);
  }

  /// Gets the current value of the gauge for a specific set of attributes.
  T getValue(Attributes attributes) {
    final value = _storage.getValue(attributes);
    // Handle the cast to the generic type
    if (T == int) return value.toInt() as T;
    if (T == double) return value.toDouble() as T;
    return value;
  }

  /// Gets the current points for this gauge.
  /// This is used by the SDK to collect metrics.
  List<MetricPoint<T>> collectPoints() {
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
      type: MetricType.gauge,
      points: points,
    );

    return [metric];
  }
}
