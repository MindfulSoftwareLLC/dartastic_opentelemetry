// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../../../dartastic_opentelemetry.dart';

/// ObservableUpDownCounter is an asynchronous instrument that reports additive
/// values when observed.
///
/// An ObservableUpDownCounter is used to measure a value that increases and
/// decreases where measurements are made by a callback function. For example,
/// number of active requests, queue size, pool size.
class ObservableUpDownCounter<T extends num> implements APIObservableUpDownCounter<T>, SDKInstrument {
  /// The underlying API ObservableUpDownCounter.
  final APIObservableUpDownCounter<T> _apiCounter;

  /// The Meter that created this ObservableUpDownCounter.
  final Meter _meter;

  /// Storage for accumulating counter measurements.
  final SumStorage _storage = SumStorage(isMonotonic: false);

  /// The last observed values, for tracking changes.
  final Map<Attributes, T> _lastValues = {};

  /// Creates a new ObservableUpDownCounter instance.
  ObservableUpDownCounter({
    required APIObservableUpDownCounter<T> apiCounter,
    required Meter meter,
  }) : _apiCounter = apiCounter,
       _meter = meter;

  @override
  String get name => _apiCounter.name;

  @override
  String? get unit => _apiCounter.unit;

  @override
  String? get description => _apiCounter.description;

  @override
  bool get enabled {
    // In the SDK, metrics are enabled based on the meter provider's enabled state
    return _meter.provider.enabled;
  }

  @override
  APIMeter get meter => _meter;

  @override
  List<ObservableCallback<T>> get callbacks => _apiCounter.callbacks;

  @override
  APICallbackRegistration<T> addCallback(ObservableCallback<T> callback) {
    // Register with the API implementation first
    final registration = _apiCounter.addCallback(callback);

    // Return a registration that also unregisters from our list
    return _ObservableUpDownCounterCallbackRegistration(
      apiRegistration: registration,
      counter: this,
      callback: callback,
    );
  }

  @override
  void removeCallback(ObservableCallback<T> callback) {
    _apiCounter.removeCallback(callback);
  }

  /// Gets the current value of the counter for a specific set of attributes.
  /// If no attributes are provided, returns the sum of all recorded values.
  T getValue([Attributes? attributes]) {
    final num value;

    if (attributes == null) {
      // For no attributes, sum all points
      value = _storage.collectPoints().fold<num>(0, (sum, point) => sum + point.value);
    } else {
      // For specific attributes, get that value
      value = _storage.getValue(attributes);
    }

    // Handle the cast to the generic type
    if (T == int) return value.toInt() as T;
    if (T == double) return value.toDouble() as T;
    return value as T;
  }

  /// Collects measurements from all registered callbacks.
  @override
  List<Measurement<T>> collect() {
    if (!enabled) {
      return [];
    }

    final result = <Measurement<T>>[];
    final callbackList = List<ObservableCallback<T>>.from(callbacks);

    // Return early if no callbacks registered
    if (callbackList.isEmpty) {
      return result;
    }

    // First, clear previous values to prepare for fresh collection
    // This is necessary to avoid accumulating values from multiple collections
    _storage.reset();

    // Call all callbacks
    for (final callback in callbackList) {
      try {
        // Create a new observable result for each callback
        final observableResult = ObservableResult<T>();

        // Call the callback with the observable result
        callback(observableResult as APIObservableResult<T>);

        // Process the measurements from the observable result
        for (final measurement in observableResult.measurements) {
          // Type checking for the generic parameter
          final value = measurement.value;
          final attributes = measurement.attributes ?? OTelFactory.otelFactory!.attributes();

          // Per the spec, for ObservableUpDownCounter we record the absolute value
          // directly - not the delta
          _storage.record(value, attributes);

          // Add measurement with the absolute value to the result
          result.add(measurement);

          // Keep track of the last value for debugging and tracking
          _lastValues[attributes] = value;
        }
      } catch (e) {
        print('Error collecting measurements from ObservableUpDownCounter callback: $e');
      }
    }

    return result;
  }

  /// Gets the current points for this counter.
  /// This is used by the SDK to collect metrics.
  List<MetricPoint> collectPoints() {
    if (!enabled) {
      return [];
    }

    // Collect new measurements, which will update storage
    collect();

    // Then return points from storage
    return _storage.collectPoints();
  }

  /// Collects metrics for the SDK metric export.
  ///
  /// This is called by the MeterProvider during metric collection.
  @override
  List<Metric> collectMetrics() {
    if (!enabled) {
      return [];
    }

    // Get the points from storage
    final points = collectPoints();
    if (points.isEmpty) {
      return [];
    }

    // Create the metric to export
    return [
      Metric.sum(
        name: name,
        description: description,
        unit: unit,
        temporality: AggregationTemporality.cumulative,
        points: points,
        isMonotonic: false,  // Up/down counters are non-monotonic
      )
    ];
  }

  /// Resets the counter for testing. This is not typically used in production.
  void reset() {
    _storage.reset();
    _lastValues.clear();
  }
}

/// Wrapper for APICallbackRegistration that also handles our internal state.
class _ObservableUpDownCounterCallbackRegistration<T extends num> implements APICallbackRegistration<T> {
  /// The API registration.
  final APICallbackRegistration<T> apiRegistration;

  /// The counter this registration is for.
  final ObservableUpDownCounter<T> counter;

  /// The callback that was registered.
  final ObservableCallback<T> callback;

  _ObservableUpDownCounterCallbackRegistration({
    required this.apiRegistration,
    required this.counter,
    required this.callback,
  });

  @override
  void unregister() {
    // Unregister from the API implementation
    apiRegistration.unregister();

    // Also remove from our counter directly for redundancy
    counter.removeCallback(callback);
  }
}
