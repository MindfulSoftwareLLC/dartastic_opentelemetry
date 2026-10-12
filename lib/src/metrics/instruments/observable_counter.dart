// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import '../../../dartastic_opentelemetry.dart';

/// ObservableCounter is an asynchronous instrument that reports monotonically
/// increasing values when observed.
///
/// An ObservableCounter is used to measure monotonically increasing values
/// where measurements are made by a callback function. For example, CPU time,
/// bytes received, or number of operations.
class ObservableCounter<T extends num>
    implements APIObservableCounter<T>, SDKObservableInstrument {
  /// The underlying API ObservableCounter.
  final APIObservableCounter<T> _apiCounter;

  /// The Meter that created this ObservableCounter.
  final Meter _meter;

  /// Storage for accumulating counter measurements.
  final SumStorage<T> _storage;

  /// The last observed values, for tracking and detecting resets.
  final Map<Attributes, T> _lastValues = {};

  /// Observations queued by batch callbacks, drained on the next [collect].
  final List<Measurement<T>> _batchObservations = [];

  /// Creates a new ObservableCounter instance.
  ObservableCounter({
    required APIObservableCounter<T> apiCounter,
    required Meter meter,
  })  : _apiCounter = apiCounter,
        _meter = meter,
        _storage = SumStorage<T>(
          isMonotonic: true,
          exemplarFilter: meter.provider.exemplarFilter,
        );

  @override
  String get name => _apiCounter.name;

  @override
  String? get unit => _apiCounter.unit;

  @override
  String? get description => _apiCounter.description;

  @override
  InstrumentAdvisory? get advisory => _apiCounter.advisory;

  @override
  bool isEnabled() {
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
      value = _storage.collectPoints().fold<num>(
            0,
            (sum, point) => sum + point.value,
          );
    } else {
      // For specific attributes, get that value
      value = _storage.getValue(attributes);
    }

    // Handle the cast to the generic type
    if (T == int) return value.toInt() as T;
    if (T == double) return value.toDouble() as T;
    return value as T;
  }

  @override
  void observeFromBatch(num value, Attributes? attributes) {
    _batchObservations.add(
      OTelFactory.otelFactory!
          .createMeasurement<T>(castNum<T>(value), attributes),
    );
  }

  /// Collects measurements from all registered callbacks and from any
  /// batch callbacks that observed this instrument since the last collection.
  @override
  List<Measurement<T>> collect() {
    if (!isEnabled()) {
      _batchObservations.clear();
      return [];
    }

    final result = <Measurement<T>>[];

    // Get a snapshot of callbacks to avoid concurrent modification issues
    final callbacksSnapshot = List<ObservableCallback<T>>.from(callbacks);

    // Return early if nothing can observe
    if (callbacksSnapshot.isEmpty && _batchObservations.isEmpty) {
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
          if (_record(measurement)) result.add(measurement);
        }
      } catch (e) {
        print(
          'Error collecting measurements from ObservableCounter callback: $e',
        );
      }
    }

    // Batch callbacks ran before this instrument collected; drain what they
    // observed through the same monotonicity logic.
    for (final measurement in _batchObservations) {
      if (_record(measurement)) result.add(measurement);
    }
    _batchObservations.clear();

    return result;
  }

  /// Records one observed absolute value into storage.
  ///
  /// Returns true when the measurement carries a change (a positive delta
  /// or a counter reset) that belongs in the collected result; a zero delta
  /// is still stored for cumulative reporting but not returned.
  bool _record(Measurement<T> measurement) {
    final value = castNum<T>(measurement.value);
    final attributes =
        measurement.attributes ?? OTelFactory.otelFactory!.attributes();

    // Check for monotonicity - current value should be >= last value.
    // A decrease indicates a counter reset; per spec we just record the
    // current value.
    final lastValue = _lastValues[attributes] ?? castNum<T>(0);
    _storage.record(value, attributes, Context.current);

    // Store the latest value for next time
    _lastValues[attributes] = value;

    return value != lastValue;
  }

  /// Collects metrics for the SDK metric export.
  ///
  /// This is called by the MeterProvider during metric collection.
  /// Per the OTel spec, observable instruments must invoke their
  /// registered callbacks on every collection cycle. Drive [collect]
  /// first so the callback runs and storage reflects the latest
  /// absolute counter value before we read it.
  @override
  List<Metric> collectMetrics() {
    if (!isEnabled()) {
      return [];
    }

    collect();

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
      ),
    ];
  }

  /// Gets the current points for this counter.
  /// This is used by the SDK to collect metrics.
  List<MetricPoint<T>> collectPoints() {
    if (!isEnabled()) {
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
