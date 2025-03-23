// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../../../dartastic_opentelemetry.dart';

/// ObservableGauge is an asynchronous instrument which reports non-additive value(s)
/// when the instrument is being observed.
///
/// An ObservableGauge is used to asynchronously measure a non-additive current value
/// that cannot be calculated synchronously.
class ObservableGauge<T extends num> implements APIObservableGauge<T>, BaseInstrument {
  /// The underlying API ObservableGauge.
  final APIObservableGauge<T> _apiGaugeDelegate;

  /// The Meter that created this ObservableGauge.
  final Meter _meter;

  /// Storage for gauge measurements.
  final GaugeStorage _storage = GaugeStorage();

  /// Creates a new ObservableGauge instance.
  ObservableGauge({
    required APIObservableGauge<T> apiGauge,
    required Meter meter,
  }) : _apiGaugeDelegate = apiGauge,
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
  /// If no attributes are provided, returns the value for the null/empty attribute set.
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

    // Get a snapshot of callbacks to avoid concurrent modification issues
    final callbacksSnapshot = List<ObservableCallback<T>>.from(callbacks);

    // Call all callbacks
    for (final callback in callbacksSnapshot) {
      try {
        // Create a new observable result for each callback
        final observableResult = ObservableResult<T>();

        // Call the callback with the observable result
        callback(observableResult as APIObservableResult<T>);

        // Process the measurements from the observable result
        for (final measurement in observableResult.measurements) {
          // Type checking for the generic parameter
          final value = measurement.value;

          // For observable gauges, we just record the latest value
          _storage.record(value, measurement.attributes ?? OTelFactory.otelFactory!.attributes());
          result.add(measurement);
        }
      } catch (e) {
        print('Error collecting measurements from ObservableGauge callback: $e');
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
  List<MetricPoint> collectPoints() {
    if (!enabled) {
      return [];
    }

    // For gauges, we don't keep historical data, so first clear the storage
    _storage.reset();

    // Collect measurements from callbacks
    collect();

    // Then return points from storage
    return _storage.collectPoints();
  }
}

/// Wrapper for APICallbackRegistration that also handles our internal state.
class _ObservableGaugeCallbackRegistration<T extends num> implements APICallbackRegistration<T> {
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
