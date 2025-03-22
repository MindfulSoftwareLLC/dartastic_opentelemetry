// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';

/// Implementation of the APIObservableResult interface.
class ObservableResult<T extends num> implements APIObservableResult<T> {
  final List<Measurement<T>> _measurements = [];

  @override
  void observe(T value, [Attributes? attributes]) {
    _measurements.add(OTelFactory.otelFactory!.createMeasurement<T>(value, attributes));
  }

  @override
  void observeWithMap(T value, Map<String, Object> attributes) {
    observe(value, attributes.toAttributes());
  }

  /// Returns all measurements recorded by this result.
  @override
  List<Measurement<T>> get measurements => List.unmodifiable(_measurements);
}
