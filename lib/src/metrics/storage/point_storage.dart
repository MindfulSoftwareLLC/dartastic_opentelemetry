// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../data/exemplar.dart';
import '../data/metric_point.dart';

/// PointStorage is the base class for all metric storage implementations.
abstract class PointStorage<T extends num> {
  /// Records a measurement with the given attributes.
  void record(T value, [Attributes? attributes]);

  /// Gets the current value for the given attributes.
  /// If no attributes are provided, returns a summary value depending on the instrument type.
  T getValue([Attributes? attributes]);

  /// Collects the current set of metric points.
  List<MetricPoint<T>> collectPoints();

  /// Resets the storage (for delta temporality).
  void reset();

  /// Adds an exemplar to a specific point.
  void addExemplar(Exemplar exemplar, [Attributes? attributes]);
}
