// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../../otel.dart';

/// Exemplar is a sample data point that may be used to annotate aggregated
/// metric data points.
///
/// Exemplars allow correlation between aggregated metric data and the
/// original API calls where measurements were recorded.
class Exemplar {
  /// The attributes for this exemplar, typically including trace and span IDs.
  final Attributes attributes;

  /// The filtered attributes for this exemplar.
  /// These are attributes that were on the original measurement but
  /// not included in the aggregation.
  final Attributes filteredAttributes;

  /// The timestamp when this exemplar was recorded.
  final DateTime timestamp;

  /// The value of this exemplar.
  final num value;

  /// The trace ID associated with this exemplar.
  final TraceId? traceId;

  /// The span ID associated with this exemplar.
  final SpanId? spanId;

  /// Creates a new Exemplar instance.
  Exemplar({
    required this.attributes,
    required this.filteredAttributes,
    required this.timestamp,
    required this.value,
    this.traceId,
    this.spanId,
  });

  /// Creates an exemplar from a measurement.
  factory Exemplar.fromMeasurement({
    required Measurement measurement,
    required DateTime timestamp,
    required Attributes aggregationAttributes,
    SpanId? spanId,
    TraceId? traceId,
  }) {
    // Determine which attributes are filtered out
    final filteredAttrs = _filterAttributes(
        measurement.attributes ?? OTelFactory.otelFactory!.attributes(),
        aggregationAttributes);

    return Exemplar(
      attributes: aggregationAttributes,
      filteredAttributes: filteredAttrs,
      timestamp: timestamp,
      value: measurement.value,
      traceId: traceId,
      spanId: spanId,
    );
  }

  /// Filters attributes to get those that are not included in the aggregation.
  static Attributes _filterAttributes(
      Attributes measurementAttrs, Attributes aggregationAttrs) {
    final result = <Attribute<Object>>[];

    // Get the attribute keys that are in the measurement but not in the aggregation
    final aggregationKeys = aggregationAttrs.keys.toSet();
    for (final attr in measurementAttrs.toList()) {
      if (!aggregationKeys.contains(attr.key)) {
        result.add(attr);
      }
    }

    return OTel.attributesFromList(result);
  }
}
