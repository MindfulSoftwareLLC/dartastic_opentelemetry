// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../data/metric.dart';
import '../data/metric_point.dart';
import '../meter.dart';
import '../storage/histogram_storage.dart';
import 'base_instrument.dart';

/// Histogram is a synchronous instrument that records a distribution of values.
///
/// A Histogram is used to measure a distribution of values, such as request durations,
/// response sizes, or latencies.
class Histogram<T extends num> implements APIHistogram<T>, SDKInstrument {
  /// The underlying API Histogram.
  final APIHistogram<T> _apiHistogram;

  /// The Meter that created this Histogram.
  final Meter _meter;

  /// Storage for accumulating histogram measurements.
  final HistogramStorage<T> _storage;

  /// Creates a new Histogram instance.
  Histogram({
    required APIHistogram<T> apiHistogram,
    required Meter meter,
    List<double>? boundaries,
  }) : _apiHistogram = apiHistogram,
       _meter = meter,
       _storage = HistogramStorage(
        boundaries: boundaries ?? _defaultBoundaries,
        recordMinMax: true,
       ) {
      // Register this instrument with the meter provider
      _meter.provider.registerInstrument(_meter.name, this);
    }

  /// Default bucket boundaries.
  static const List<double> _defaultBoundaries = [
    0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000
  ];

  @override
  String get name => _apiHistogram.name;

  @override
  String? get unit => _apiHistogram.unit;

  @override
  String? get description => _apiHistogram.description;

  @override
  bool get enabled => _meter.enabled;

  @override
  APIMeter get meter => _meter;

  @override
  List<double>? get boundaries => _apiHistogram.boundaries;

  @override
  bool get isCounter => false;

  @override
  bool get isUpDownCounter => false;

  @override
  bool get isGauge => false;

  @override
  bool get isHistogram => true;

  @override
  void record(T value, [Attributes? attributes]) {
    // First use the API implementation (no-op by default)
    _apiHistogram.record(value, attributes);

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

  /// Gets the current sum for the given attributes.
  /// If no attributes are provided, returns the sum for the null/empty attribute set.
  T getValue([Attributes? attributes]) {
    return _storage.getValue(attributes);
  }

  /// Gets the current points for this histogram.
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
      type: MetricType.histogram,
      points: points,
    );

    return [metric];
  }

  /// Resets the histogram. This is only used for Delta temporality.
  void reset() {
    _storage.reset();
  }
}
