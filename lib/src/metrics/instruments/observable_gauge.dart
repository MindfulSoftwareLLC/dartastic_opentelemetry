// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../meter.dart';
import '../data/metric_point.dart';
import '../storage/gauge_storage.dart';
import '../observe/observable_result.dart';

/// ObservableGauge is an asynchronous instrument which reports non-additive value(s)
/// when the instrument is being observed.
///
/// An ObservableGauge is used to asynchronously measure a non-additive current value
/// that cannot be calculated synchronously.
class ObservableGauge<T extends num> implements APIObservableGauge<T> {
  /// The underlying API ObservableGauge.
  final APIObservableGauge<T> _apiGauge;

  /// The Meter that created this ObservableGauge.
  final Meter _meter;

  /// Storage for gauge measurements.
  final GaugeStorage _storage = GaugeStorage();

  /// Creates a new ObservableGauge instance.
  ObservableGauge({
    required APIObservableGauge<T> apiGauge,
    required Meter meter,
  }) : _apiGauge = apiGauge,
       _meter = meter;

  @override
  String get name => _apiGauge.name;

  @override
  String? get unit => _apiGauge.unit;

  @override
  String? get description => _apiGauge.description;

  @override
  bool get enabled => _apiGauge.enabled && _meter.enabled;

  @override
  APIMeter get meter => _meter;

  @override
  List<ObservableCallback> get callbacks => _apiGauge.callbacks;

  @override
  APICallbackRegistration<T> addCallback(ObservableCallback<T> callback) {
    // Register with the API implementation first
    final registration = _apiGauge.addCallback(callback);

    // Return a registration that also unregisters from our list
    return _ObservableGaugeCallbackRegistration(
      apiRegistration: registration,
      gauge: this,
      callback: callback,
    );
  }
  
  @override
  void removeCallback(ObservableCallback<T> callback) {
    _apiGauge._removeCallback(callback);
  }

  /// Gets the current value of the gauge for a specific set of attributes.
  T getValue(Attributes attributes) {
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

    final result = <Measurement>[];
    final observableResult = ObservableResult<T>();

    // Call all callbacks
    for (final callback in callbacks) {
      try {
        // Call the callback with the observable result
        callback(observableResult as APIObservableResult<T>);

        // Process the measurements from the observable result
        for (final measurement in observableResult.measurements) {
          // Type checking for the generic parameter
          final value = measurement.value;
          if (T != dynamic && value is! T) {
            print('Warning: Value must be of type $T, got ${value.runtimeType}. Skipping measurement.');
            continue;
          }

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

  /// Gets the current points for this gauge.
  /// This is used by the SDK to collect metrics.
  List<MetricPoint> collectPoints() {
    // For gauges, we don't keep historical data, so first clear the storage
    _storage.reset();

    // Collect measurements from callbacks
    collect();

    // Then return points from storage
    return _storage.collectPoints();
  }
}

/// Wrapper for APICallbackRegistration that also handles our internal state.
class _ObservableGaugeCallbackRegistration implements APICallbackRegistration<T> {
  /// The API registration.
  final APICallbackRegistration<T> apiRegistration;

  /// The gauge this registration is for.
  final ObservableGauge gauge;

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
  }
}
