// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import '../../resource/resource.dart';
import 'metric.dart';

/// MetricData represents a collection of metrics to be exported.
class MetricData {
  /// The resource associated with the metrics.
  final Resource? resource;

  /// The collection of metrics.
  final List<Metric> metrics;

  /// Creates a new MetricData instance.
  MetricData({
    this.resource,
    required this.metrics,
  });

  /// Creates an empty MetricData instance.
  factory MetricData.empty() {
    return MetricData(metrics: []);
  }

  /// Returns a new MetricData instance with the metrics filtered by the given predicate.
  MetricData filter(bool Function(Metric metric) predicate) {
    return MetricData(
      resource: resource,
      metrics: metrics.where(predicate).toList(),
    );
  }

  /// Returns a new MetricData instance with the given metrics added.
  MetricData merge(MetricData other) {
    return MetricData(
      resource: resource ?? other.resource,
      metrics: [...metrics, ...other.metrics],
    );
  }
}
