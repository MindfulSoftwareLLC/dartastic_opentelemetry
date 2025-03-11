// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';

/// Implementation of the ObservableResult interface.
class ObservableResultImpl implements ObservableResult {
  final List<Measurement> _measurements = [];

  @override
  void observe(num value, Attributes attributes) {
    _measurements.add(Measurement(value, attributes));
  }

  @override
  void observeWithMap(num value, Map<String, Object> attributes) {
    observe(value, attributes.toAttributes());
  }

  /// Returns all measurements recorded by this result.
  List<Measurement> get measurements => List.unmodifiable(_measurements);
}
