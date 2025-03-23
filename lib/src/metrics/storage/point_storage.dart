// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../data/metric_point.dart';
import '../data/exemplar.dart';

/// PointStorage is the base class for all metric storage implementations.
abstract class PointStorage<T extends num> {
  /// Records a measurement with the given attributes.
  void record(T value, [Attributes? attributes]);

  /// Collects the current set of metric points.
  List<MetricPoint> collectPoints();

  /// Resets the storage (for delta temporality).
  void reset();

  /// Adds an exemplar to a specific point.
  void addExemplar(Exemplar exemplar, [Attributes? attributes]);
}
