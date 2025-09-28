// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Implementation of the APIObservableResult interface for asynchronous instruments.
///
/// ObservableResult is used by asynchronous instruments to collect measurements
/// during observation callbacks. When a callback is invoked, it receives an
/// ObservableResult that it can use to record observations.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/api/#asynchronous-instruments
class ObservableResult<T extends num> implements APIObservableResult<T> {
  /// The list of measurements recorded during this observation.
  final List<Measurement<T>> _measurements = [];

  /// Records an observation with this result.
  ///
  /// This method records a measurement with the specified value and optional
  /// attributes. The measurement will be associated with the current timestamp.
  ///
  /// @param value The observed value to record
  /// @param attributes Optional attributes to associate with this observation
  @override
  void observe(T value, [Attributes? attributes]) {
    // Make sure we have a valid OTelFactory
    if (OTelFactory.otelFactory == null) {
      if (OTelLog.isWarn()) {
        OTelLog.warn(
            'Warning: OTelFactory.otelFactory is null in ObservableResult.observe');
      }
      return;
    }

    // Add the measurement
    final measurement =
        OTelFactory.otelFactory!.createMeasurement<T>(value, attributes);
    _measurements.add(measurement);
  }

  /// Records an observation with attributes specified as a map.
  ///
  /// This is a convenience method that converts the map to Attributes
  /// and calls observe().
  ///
  /// @param value The observed value to record
  /// @param attributes Map of attribute names to values
  @override
  void observeWithMap(T value, Map<String, Object> attributes) {
    observe(value, attributes.toAttributes());
  }

  /// Returns all measurements recorded by this result.
  ///
  /// This method is used by the SDK to collect measurements after
  /// an observation callback has been executed.
  ///
  /// @return An unmodifiable list of all measurements recorded
  @override
  List<Measurement<T>> get measurements => List.unmodifiable(_measurements);
}
