// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../meter.dart';
import '../data/metric_point.dart';
import '../storage/sum_storage.dart';
import '../observe/observable_result.dart';

/// ObservableUpDownCounter is an asynchronous instrument that reports additive
/// values when observed.
///
/// An ObservableUpDownCounter is used to measure a value that increases and
/// decreases where measurements are made by a callback function. For example,
/// number of active requests, queue size, pool size.
class ObservableUpDownCounter<T extends num> implements APIObservableUpDownCounter<T> {
  /// The underlying API ObservableUpDownCounter.
  final APIObservableUpDownCounter<T> _apiCounter;

  /// The Meter that created this ObservableUpDownCounter.
  final Meter _meter;

  /// Storage for accumulating counter measurements.
  final SumStorage _storage = SumStorage(isMonotonic: false);

  /// The last observed values, used for delta calculations.
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
  bool get enabled => _apiCounter.enabled && _meter.enabled && _meter.provider.enabled;

  @override
  APIMeter get meter => _meter;

  @override
  List<ObservableCallback> get callbacks => _apiCounter.callbacks;

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
  /// If no attributes are provided, returns the sum for all attribute combinations.
  T getValue([Attributes? attributes]) {
    final value = _storage.getValue(attributes);
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

    // Call all callbacks
    for (final callback in callbacks) {
      try {
        // Create a new observable result for each callback
        final observableResult = ObservableResult<T>();
        
        // Call the callback with the observable result
        callback(observableResult as APIObservableResult<T>);

        // Process the measurements from the observable result
        for (final measurement in observableResult.measurements) {
          // Type checking for the generic parameter
          final value = measurement.value;
          // For observable up-down counters, we need to calculate deltas
          final key = measurement.attributes ?? OTelFactory.otelFactory!.attributes();
          if (_lastValues.containsKey(key)) {
            // Calculate delta from last observation
            final T lastValue = _lastValues[key]!;
            final T delta = _subtractNumeric(value, lastValue);
            _storage.record(delta, measurement.attributes);
            // Add a new measurement with the delta value
            result.add(OTelFactory.otelFactory!.createMeasurement<T>(delta, measurement.attributes));
          } else {
            // First observation, use the full value
            _storage.record(value, measurement.attributes);
            result.add(measurement);
          }

          // Update last value
          _lastValues[key] = value;
        }
      } catch (e) {
        print('Error collecting measurements from ObservableUpDownCounter callback: $e');
      }
    }

    return result;
  }

  /// Helper method to subtract numeric values while preserving the generic type T.
  /// This properly handles both int and double types.
  T _subtractNumeric(num a, num b) {
    if (T == int) {
      return (a.toInt() - b.toInt()) as T;
    } else if (T == double) {
      return (a.toDouble() - b.toDouble()) as T;
    } else {
      // For any other numeric type, default to the standard subtraction
      // and cast the result to T
      return (a - b) as T;
    }
  }

  /// Gets the current points for this counter.
  /// This is used by the SDK to collect metrics.
  List<MetricPoint> collectPoints() {
    if (!enabled) {
      return [];
    }
    
    // First collect new measurements
    collect();

    // Then return points from storage
    return _storage.collectPoints();
  }

  /// Resets the counter. This is only used for Delta temporality.
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
  }
}
