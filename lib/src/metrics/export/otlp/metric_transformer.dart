// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart' show OTelLog;
import 'package:fixnum/fixnum.dart';

import '../../../../proto/common/v1/common.pb.dart' as common_proto;
import '../../../../proto/metrics/v1/metrics.pb.dart' as proto;
import '../../../../proto/resource/v1/resource.pb.dart' as resource_proto;
import '../../../resource/resource.dart';
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

    if (OTelLog.isLogMetrics()) {
      OTelLog.logMetric('MetricTransformer: Transforming metric ${metric.name} of type ${metric.type}');
    }
    
    // Set data based on metric type
    switch (metric.type) {
      case MetricType.histogram:
        // Histogram metric
        final histogramDataPoints = <proto.HistogramDataPoint>[];
        for (final point in metric.points) {
          if (point.value is HistogramValue) {
            final dataPoint = _createHistogramDataPoint(point);
            histogramDataPoints.add(dataPoint);
          }
        }
        
        // Create a new histogram with the correct temporality and data points
        final histogram = proto.Histogram(
          aggregationTemporality: metric.temporality == AggregationTemporality.delta
              ? proto.AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA
              : proto.AggregationTemporality.AGGREGATION_TEMPORALITY_CUMULATIVE,
          dataPoints: histogramDataPoints,
        );
        
        metricProto.histogram = histogram;
        break;
        
      case MetricType.sum:
        // Sum metric
        final numberDataPoints = <proto.NumberDataPoint>[];
        for (final point in metric.points) {
          final dataPoint = _createNumberDataPoint(point);
          numberDataPoints.add(dataPoint);
        }
        
        // Create a new sum with the correct temporality and data points
        final sum = proto.Sum(
          isMonotonic: metric.isMonotonic ?? true, // Assuming sum metrics are monotonic by default
          aggregationTemporality: metric.temporality == AggregationTemporality.delta
              ? proto.AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA
              : proto.AggregationTemporality.AGGREGATION_TEMPORALITY_CUMULATIVE,
          dataPoints: numberDataPoints,
        );
        
        metricProto.sum = sum;
        break;
        
      case MetricType.gauge:
        // Gauge metric
        final numberDataPoints = <proto.NumberDataPoint>[];
        for (final point in metric.points) {
          final dataPoint = _createNumberDataPoint(point);
          numberDataPoints.add(dataPoint);
        }
        
        // Create a new gauge with the data points
        final gauge = proto.Gauge(dataPoints: numberDataPoints);
        metricProto.gauge = gauge;
        break;
    }

    return metricProto;
  }

  /// Creates a histogram data point for the given MetricPoint.
  static proto.HistogramDataPoint _createHistogramDataPoint(MetricPoint<dynamic> point) {
    final histogramValue = point.value as HistogramValue;
    
    // Prepare attributes
    final attributes = point.attributes.toMap();
    final attributeKeyValues = attributes.entries
        .map((entry) => _createKeyValue(entry.key, entry.value.value))
        .toList();
    
    // Prepare exemplars if available
    final exemplars = <proto.Exemplar>[];
    if (point.hasExemplars) {
      for (final exemplar in point.exemplars!) {
        final exemplarProto = proto.Exemplar(
          timeUnixNano: Int64(exemplar.timestamp.microsecondsSinceEpoch * 1000),
          asDouble: exemplar.value.toDouble(),
        );
        exemplars.add(exemplarProto);
      }
    }
    
    // Create bucket counts as Int64 list
    final bucketCountsInt64 = histogramValue.bucketCounts
        .map(Int64.new)
        .toList();
    
    // Create the HistogramDataPoint with all fields set
    return proto.HistogramDataPoint(
      attributes: attributeKeyValues,
      startTimeUnixNano: Int64(point.startTime.microsecondsSinceEpoch * 1000),
      timeUnixNano: Int64(point.endTime.microsecondsSinceEpoch * 1000),
      count: Int64(histogramValue.count),
      sum: histogramValue.sum.toDouble(),
      bucketCounts: bucketCountsInt64,
      explicitBounds: List<double>.from(histogramValue.boundaries),
      exemplars: exemplars,
      min: histogramValue.min?.toDouble(),
      max: histogramValue.max?.toDouble(),
    );
  }

  /// Creates a number data point for the given MetricPoint.
  static proto.NumberDataPoint _createNumberDataPoint(MetricPoint<dynamic> point) {
    // Prepare attributes
    final attributes = point.attributes.toMap();
    final attributeKeyValues = attributes.entries
        .map((entry) => _createKeyValue(entry.key, entry.value.value))
        .toList();
    
    // Prepare exemplars if available
    final exemplars = <proto.Exemplar>[];
    if (point.hasExemplars) {
      for (final exemplar in point.exemplars!) {
        final exemplarProto = proto.Exemplar(
          timeUnixNano: Int64(exemplar.timestamp.microsecondsSinceEpoch * 1000),
          asDouble: exemplar.value.toDouble(),
        );
        exemplars.add(exemplarProto);
      }
    }
    
    // Create the NumberDataPoint with all fields set
    return proto.NumberDataPoint(
      attributes: attributeKeyValues,
      startTimeUnixNano: Int64(point.startTime.microsecondsSinceEpoch * 1000),
      timeUnixNano: Int64(point.endTime.microsecondsSinceEpoch * 1000),
      asDouble: (point.value is num) ? (point.value as num).toDouble() : double.tryParse(point.value.toString()) ?? 0.0,
      exemplars: exemplars,
    );
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
