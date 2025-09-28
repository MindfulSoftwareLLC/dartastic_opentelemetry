// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import '../../../dartastic_opentelemetry.dart';

/// ObservableGauge is an asynchronous instrument which reports non-additive value(s)
/// when the instrument is being observed.
///
/// An ObservableGauge is used to asynchronously measure a non-additive current value
/// that cannot be calculated synchronously.
class ObservableGauge<T extends num>
    implements APIObservableGauge<T>, SDKInstrument {
  /// The underlying API ObservableGauge.
  final APIObservableGauge<T> _apiGaugeDelegate;

  /// The Meter that created this ObservableGauge.
  final Meter _meter;

  /// Storage for gauge measurements.
  final GaugeStorage<T> _storage = GaugeStorage<T>();

  /// Creates a new ObservableGauge instance.
  ObservableGauge({
    required APIObservableGauge<T> apiGauge,
    required Meter meter,
  })  : _apiGaugeDelegate = apiGauge,
        _meter = meter;

  @override
  String get name => _apiGaugeDelegate.name;

  @override
  String? get unit => _apiGaugeDelegate.unit;

  @override
  String? get description => _apiGaugeDelegate.description;

  @override
  bool get enabled {
    return _meter.provider.enabled;
  }

  @override
  APIMeter get meter => _meter;

  @override
  List<ObservableCallback<T>> get callbacks => _apiGaugeDelegate.callbacks;

  @override
  APICallbackRegistration<T> addCallback(ObservableCallback<T> callback) {
    // Register with the API implementation first
    final registration = _apiGaugeDelegate.addCallback(callback);

    // Return a registration that handles unregistering properly
    return _ObservableGaugeCallbackRegistration<T>(
      apiRegistration: registration,
      gauge: this,
      callback: callback,
    );
  }

  @override
  void removeCallback(ObservableCallback<T> callback) {
    _apiGaugeDelegate.removeCallback(callback);
  }

  /// Gets the current value of the gauge for a specific set of attributes.
  /// If no attributes are provided, returns the average of all recorded values.
  T getValue([Attributes? attributes]) {
    final num value;

    if (attributes == null) {
      // For gauges without attributes, we return the average of all values
      final points = _storage.collectPoints();
      if (points.isEmpty) {
        value = 0;
      } else {
        value =
            points.fold<num>(0, (sum, point) => sum + (point.value as num)) /
                points.length;
      }
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
          final value = measurement.value;

          final num numValue;
          numValue = value;

          // For observable gauges, we just record the latest value
          // For SDK storage, convert the num to the appropriate T type
          final attributes =
              measurement.attributes ?? OTelFactory.otelFactory!.attributes();
          if (T == int) {
            _storage.record(numValue.toInt() as T, attributes);
          } else if (T == double) {
            _storage.record(numValue.toDouble() as T, attributes);
          } else {
            _storage.record(numValue as T, attributes);
          }

          result.add(measurement);
        }
      } catch (e) {
        print(
            'Error collecting measurements from ObservableGauge callback: $e');
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
      Metric.gauge(
        name: name,
        description: description,
        unit: unit,
        points: points,
      )
    ];
  }

  /// Gets the current points for this gauge.
  /// This is used by the SDK to collect metrics.
  List<MetricPoint<T>> collectPoints() {
    if (!enabled) {
      return [];
    }

    // Return points from storage
    return _storage.collectPoints();
  }
}

/// Wrapper for APICallbackRegistration that also handles our internal state.
class _ObservableGaugeCallbackRegistration<T extends num>
    implements APICallbackRegistration<T> {
  /// The API registration.
  final APICallbackRegistration<T> apiRegistration;

  /// The gauge this registration is for.
  final ObservableGauge<T> gauge;

  /// The callback that was registered.
  final ObservableCallback<T> callback;

  _ObservableGaugeCallbackRegistration({
    required this.apiRegistration,
    required this.gauge,
    required this.callback,
  });

  @override
  void unregister() {
    // Unregister from the API implementation
    apiRegistration.unregister();

    // Also remove from our gauge directly for redundancy
    gauge.removeCallback(callback);
  }
}
