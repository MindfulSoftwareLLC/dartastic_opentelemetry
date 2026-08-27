// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../data/metric_point.dart';
import '../exemplar_filter.dart';
import '../exemplar_reservoir.dart';

/// Base storage interface for all metric types.
/// This replaces the old PointStorage with proper input/output type separation.
abstract class MetricStorage {
  /// Resets the storage (for delta temporality).
  void reset();
}

/// Storage for metrics that have simple numeric input and output (sum, gauge).
abstract class NumericStorage<T extends num> extends MetricStorage {
  /// Records a measurement with the given attributes and context.
  void record(T value,
      [Attributes? attributes, Context? context, DateTime? timestamp]);

  /// Gets the current value for the given attributes.
  /// If no attributes are provided, returns a summary value depending on the instrument type.
  T getValue([Attributes? attributes]);

  /// Collects the current set of metric points.
  List<MetricPoint<T>> collectPoints();
}

/// Storage for histogram metrics that have numeric input but HistogramValue output.
abstract class HistogramStorageBase<T extends num> extends MetricStorage {
  /// Records a measurement with the given attributes and context.
  void record(T value,
      [Attributes? attributes, Context? context, DateTime? timestamp]);

  /// Gets the current histogram value for the given attributes.
  /// If no attributes are provided, returns a combined HistogramValue across all attribute sets.
  HistogramValue getValue([Attributes? attributes]);

  /// Collects the current set of metric points containing HistogramValue objects.
  List<MetricPoint<HistogramValue>> collectPoints();
}

/// Mixin for managing exemplar sampling policy across storage implementations.
mixin ExemplarSampling<T extends num> {
  ExemplarFilter get exemplarFilter;

  void maybeOffer(ExemplarReservoir reservoir, T value, Attributes attributes,
      Context context, DateTime timestamp,
      [int? bucketIndex]) {
    if (exemplarFilter.shouldSample(value, attributes, context)) {
      reservoir.offerMeasurement(
          value, attributes, context, timestamp, bucketIndex);
    }
  }
}
