// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import '../../../dartastic_opentelemetry.dart';

/// ObservableCounter is an asynchronous instrument that reports monotonically
/// increasing values when observed.
///
/// An ObservableCounter is used to measure monotonically increasing values
/// where measurements are made by a callback function. For example, CPU time,
/// bytes received, or number of operations.
class ObservableCounter<T extends num>
    implements APIObservableCounter<T>, SDKInstrument {
  /// The underlying API ObservableCounter.
  final APIObservableCounter<T> _apiCounter;

  /// The Meter that created this ObservableCounter.
  final Meter _meter;

  /// Storage for accumulating counter measurements.
  final SumStorage<T> _storage = SumStorage<T>(isMonotonic: true);

  /// The last observed values, for tracking and detecting resets.
  final Map<Attributes, T> _lastValues = {};

  /// Creates a new ObservableCounter instance.
  ObservableCounter({
    required APIObservableCounter<T> apiCounter,
    required Meter meter,
  })  : _apiCounter = apiCounter,
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
    return _ObservableCounterCallbackRegistration<T>(
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
      value = _storage
          .collectPoints()
          .fold<num>(0, (sum, point) => sum + point.value);
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

    // Get a snapshot of callbacks to avoid concurrent modification issues
    final callbacksSnapshot = List<ObservableCallback<T>>.from(callbacks);

    // Return early if no callbacks registered
    if (callbacksSnapshot.isEmpty) {
      return result;
    }

    // First, clear previous values to prepare for fresh collection
    // This is necessary to avoid accumulating values from multiple collections
    _storage.reset();

    // Call all callbacks
    for (final callback in callbacksSnapshot) {
      try {
        // Create a new observable result for each callback
        final observableResult = ObservableResult<T>();

        // Call the callback with the observable result
        // Cast the parameter to ensure type safety
        try {
          callback(observableResult as APIObservableResult<T>);
        } catch (e) {
          print('Type error in callback: $e');
          continue;
        }

        // Process the measurements from the observable result
        for (final measurement in observableResult.measurements) {
          // Type checking for the generic parameter
          final dynamic rawValue = measurement.value;
          final num value = (rawValue is num)
              ? rawValue
              : num.tryParse(rawValue.toString()) ?? 0;
          final attributes =
              measurement.attributes ?? OTelFactory.otelFactory!.attributes();

          // Check for monotonicity - current value should be >= last value
          final T lastValue =
              (_lastValues[attributes] ?? (T == int ? 0 : 0.0)) as T;

          // If value decreased, it indicates a counter reset
          if (value < lastValue) {
            // Per spec, for a reset we just record the current value
            // For SDK storage, convert the num to the appropriate T type
            if (T == int) {
              _storage.record(value.toInt() as T, attributes);
            } else if (T == double) {
              _storage.record(value.toDouble() as T, attributes);
            } else {
              _storage.record(value as T, attributes);
            }
            result.add(measurement);
          } else if (value > lastValue) {
            // Only add measurements with positive deltas
            // For SDK storage, convert the num to the appropriate T type
            if (T == int) {
              _storage.record(value.toInt() as T, attributes);
            } else if (T == double) {
              _storage.record(value.toDouble() as T, attributes);
            } else {
              _storage.record(value as T, attributes);
            }
            result.add(measurement);
          } else {
            // For zero deltas, we still record the value in storage for cumulative reporting,
            // but don't include it in the returned measurements
            // For SDK storage, convert the num to the appropriate T type
            if (T == int) {
              _storage.record(value.toInt() as T, attributes);
            } else if (T == double) {
              _storage.record(value.toDouble() as T, attributes);
            } else {
              _storage.record(value as T, attributes);
            }
            // Note: The measurement is deliberately not added to the result list
          }

          // Store the latest value for next time
          if (T == int) {
            _lastValues[attributes] = value.toInt() as T;
          } else if (T == double) {
            _lastValues[attributes] = value.toDouble() as T;
          } else {
            _lastValues[attributes] = value as T;
          }
        }
      } catch (e) {
        print(
            'Error collecting measurements from ObservableCounter callback: $e');
      }
    }

    return result;
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
        isMonotonic: true, // Counters are monotonic
      )
    ];
  }

  /// Gets the current points for this counter.
  /// This is used by the SDK to collect metrics.
  List<MetricPoint<T>> collectPoints() {
    if (!enabled) {
      return [];
    }

    // Then return points from storage
    return _storage.collectPoints();
  }

  /// Resets the counter. This is only used for testing.
  void reset() {
    _storage.reset();
    _lastValues.clear();
  }
}

/// Wrapper for APICallbackRegistration that also handles our internal state.
class _ObservableCounterCallbackRegistration<T extends num>
    implements APICallbackRegistration<T> {
  /// The API registration.
  final APICallbackRegistration<T> apiRegistration;

  /// The counter this registration is for.
  final ObservableCounter<T> counter;

  /// The callback that was registered.
  final ObservableCallback<T> callback;

  _ObservableCounterCallbackRegistration({
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
