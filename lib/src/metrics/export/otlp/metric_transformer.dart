// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:fixnum/fixnum.dart';

import '../../../../proto/common/v1/common.pb.dart' as common_proto;
import '../../../../proto/metrics/v1/metrics.pb.dart' as proto;
import '../../../../proto/resource/v1/resource.pb.dart' as resource_proto;
import '../../../resource/resource.dart';
import '../../../util/otel_log.dart';
import '../../data/metric.dart';
import '../../data/metric_point.dart';

/// Utility class for transforming metric data to OTLP protobuf format.
class MetricTransformer {
  /// Transforms a Resource to an OTLP Resource proto.
  static resource_proto.Resource transformResource(Resource resource) {
    final resourceProto = resource_proto.Resource();
    final attributes = resource.attributes;

    resourceProto.attributes.addAll(
      attributes.toMap().entries.map((entry) => _createKeyValue(entry.key, entry.value.value)),
    );

    return resourceProto;
  }

  /// Transforms a Metric to an OTLP Metric proto.
  static proto.Metric transformMetric(Metric metric) {
    final metricProto = proto.Metric();
    metricProto.name = metric.name;

    if (metric.description != null) {
      metricProto.description = metric.description!;
    }

    if (metric.unit != null) {
      metricProto.unit = metric.unit!;
    }

    if (OTelLog.isLogExport()) {
      OTelLog.logExport('MetricTransformer: Transforming metric ${metric.name} of type ${metric.type}');
    }
    
    // Set data based on metric type
    switch (metric.type) {
      case MetricType.histogram:
        // Histogram metric
        final histogram = metricProto.histogram;
        // Set aggregation temporality
        if (metric.temporality == AggregationTemporality.delta) {
          histogram.aggregationTemporality = proto.AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA;
        } else {
          histogram.aggregationTemporality = proto.AggregationTemporality.AGGREGATION_TEMPORALITY_CUMULATIVE;
        }
        
        for (final point in metric.points) {
          if (point.value is HistogramValue) {
            _addHistogramDataPoint(histogram.dataPoints, point);
          }
        }
        break;
        
      case MetricType.sum:
        // Sum metric
        final sum = metricProto.sum;
        sum.isMonotonic = true; // Assuming sum metrics are monotonic by default
        
        // Set aggregation temporality
        if (metric.temporality == AggregationTemporality.delta) {
          sum.aggregationTemporality = proto.AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA;
        } else {
          sum.aggregationTemporality = proto.AggregationTemporality.AGGREGATION_TEMPORALITY_CUMULATIVE;
        }
        
        for (final point in metric.points) {
          _addNumberDataPoint(sum.dataPoints, point);
        }
        break;
        
      case MetricType.gauge:
        // Gauge metric
        final gauge = metricProto.gauge;
        for (final point in metric.points) {
          _addNumberDataPoint(gauge.dataPoints, point);
        }
        break;
    }

    return metricProto;
  }

  /// Adds a histogram data point to the given list.
  static void _addHistogramDataPoint(
    List<proto.HistogramDataPoint> dataPoints,
    MetricPoint point,
  ) {
    final histogramValue = point.value as HistogramValue;
    final dataPoint = proto.HistogramDataPoint();

    // Set common fields
    _setCommonDataPointFields(dataPoint, point);

    // Set histogram-specific fields
    dataPoint.count = Int64(histogramValue.count);
    dataPoint.sum = histogramValue.sum.toDouble();

    // Add bucket counts and boundaries
    dataPoint.bucketCounts.addAll(
      histogramValue.bucketCounts.map((count) => Int64(count)),
    );
    dataPoint.explicitBounds.addAll(histogramValue.boundaries);

    // Add min/max if available
    if (histogramValue.min != null) {
      dataPoint.min = histogramValue.min!.toDouble();
    }
    if (histogramValue.max != null) {
      dataPoint.max = histogramValue.max!.toDouble();
    }

    // Add exemplars if available
    if (point.hasExemplars) {
      for (final exemplar in point.exemplars!) {
        // Note: Exemplar transformation is simplified here
        final exemplarProto = proto.Exemplar();
        exemplarProto.timeUnixNano = Int64(exemplar.timestamp.microsecondsSinceEpoch * 1000);
        exemplarProto.asDouble = exemplar.value.toDouble();
        dataPoint.exemplars.add(exemplarProto);
      }
    }

    dataPoints.add(dataPoint);
  }

  /// Adds a number data point to the given list.
  static void _addNumberDataPoint(
    List<proto.NumberDataPoint> dataPoints,
    MetricPoint point,
  ) {
    final dataPoint = proto.NumberDataPoint();

    // Set common fields
    _setCommonDataPointFields(dataPoint, point);

    // Set value (as double)
    dataPoint.asDouble = point.value.toDouble();

    // Add exemplars if available
    if (point.hasExemplars) {
      for (final exemplar in point.exemplars!) {
        // Note: Exemplar transformation is simplified here
        final exemplarProto = proto.Exemplar();
        exemplarProto.timeUnixNano = Int64(exemplar.timestamp.microsecondsSinceEpoch * 1000);
        exemplarProto.asDouble = exemplar.value.toDouble();
        dataPoint.exemplars.add(exemplarProto);
      }
    }

    dataPoints.add(dataPoint);
  }

  /// Sets common fields for any data point type.
  static void _setCommonDataPointFields(dynamic dataPoint, MetricPoint point) {
    // Convert timestamps to nanoseconds
    dataPoint.startTimeUnixNano = Int64(point.startTime.microsecondsSinceEpoch * 1000);
    dataPoint.timeUnixNano = Int64(point.endTime.microsecondsSinceEpoch * 1000);

    // Add attributes
    final attributes = point.attributes.toMap();
    for (final entry in attributes.entries) {
      dataPoint.attributes.add(_createKeyValue(entry.key, entry.value.value));
    }
  }

  /// Creates a KeyValue proto from a key and value.
  static common_proto.KeyValue _createKeyValue(String key, dynamic value) {
    final keyValue = common_proto.KeyValue();
    keyValue.key = key;

    if (value is String) {
      keyValue.value = common_proto.AnyValue(stringValue: value);
    } else if (value is bool) {
      keyValue.value = common_proto.AnyValue(boolValue: value);
    } else if (value is int) {
      keyValue.value = common_proto.AnyValue(intValue: Int64(value));
    } else if (value is double) {
      keyValue.value = common_proto.AnyValue(doubleValue: value);
    } else if (value is List) {
      final arrayValue = common_proto.ArrayValue();
      for (final item in value) {
        final anyValue = common_proto.AnyValue();
        if (item is String) {
          anyValue.stringValue = item;
        } else if (item is bool) {
          anyValue.boolValue = item;
        } else if (item is int) {
          anyValue.intValue = Int64(item);
        } else if (item is double) {
          anyValue.doubleValue = item;
        }
        arrayValue.values.add(anyValue);
      }
      keyValue.value = common_proto.AnyValue(arrayValue: arrayValue);
    } else {
      // Default to string representation for unsupported types
      keyValue.value = common_proto.AnyValue(stringValue: value.toString());
    }

    return keyValue;
  }
}
