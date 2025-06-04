// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../data/exemplar.dart';
import '../data/metric_point.dart';

/// Base storage interface for all metric types.
/// This replaces the old PointStorage with proper input/output type separation.
abstract class MetricStorage {
  /// Resets the storage (for delta temporality).
  void reset();

  /// Adds an exemplar to a specific point.
  void addExemplar(Exemplar exemplar, [Attributes? attributes]);
}

/// Storage for metrics that have simple numeric input and output (sum, gauge).
abstract class NumericStorage<T extends num> extends MetricStorage {
  /// Records a measurement with the given attributes.
  void record(T value, [Attributes? attributes]);

  /// Gets the current value for the given attributes.
  /// If no attributes are provided, returns a summary value depending on the instrument type.
  T getValue([Attributes? attributes]);

  /// Collects the current set of metric points.
  List<MetricPoint<T>> collectPoints();
}

/// Storage for histogram metrics that have numeric input but HistogramValue output.
abstract class HistogramStorageBase<T extends num> extends MetricStorage {
  /// Records a measurement with the given attributes.
  void record(T value, [Attributes? attributes]);

  /// Gets the current histogram value for the given attributes.
  /// If no attributes are provided, returns a combined HistogramValue across all attribute sets.
  HistogramValue getValue([Attributes? attributes]);

  /// Collects the current set of metric points containing HistogramValue objects.
  List<MetricPoint<HistogramValue>> collectPoints();
}
