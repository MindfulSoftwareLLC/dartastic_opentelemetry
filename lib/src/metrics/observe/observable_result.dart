// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';

/// Implementation of the APIObservableResult interface.
class ObservableResult<T extends num> implements APIObservableResult<T> {
  final List<Measurement<T>> _measurements = [];

  @override
  void observe(T value, [Attributes? attributes]) {
    // Make sure we have a valid OTelFactory
    if (OTelFactory.otelFactory == null) {
      if (OTelLog.isWarn()) {
        OTelLog.warn('Warning: OTelFactory.otelFactory is null in ObservableResult.observe');
      }
      return;
    }

    // Add the measurement
    final measurement = OTelFactory.otelFactory!.createMeasurement<T>(value, attributes);
    _measurements.add(measurement);
  }

  @override
  void observeWithMap(T value, Map<String, Object> attributes) {
    observe(value, attributes.toAttributes());
  }

  /// Returns all measurements recorded by this result.
  @override
  List<Measurement<T>> get measurements => List.unmodifiable(_measurements);
}
