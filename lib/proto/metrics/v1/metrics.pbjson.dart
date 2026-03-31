// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/metrics/v1/metrics.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use aggregationTemporalityDescriptor instead')
const AggregationTemporality$json = {
  '1': 'AggregationTemporality',
  '2': [
    {'1': 'AGGREGATION_TEMPORALITY_UNSPECIFIED', '2': 0},
    {'1': 'AGGREGATION_TEMPORALITY_DELTA', '2': 1},
    {'1': 'AGGREGATION_TEMPORALITY_CUMULATIVE', '2': 2},
  ],
};

/// Descriptor for `AggregationTemporality`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List aggregationTemporalityDescriptor = $convert.base64Decode(
    'ChZBZ2dyZWdhdGlvblRlbXBvcmFsaXR5EicKI0FHR1JFR0FUSU9OX1RFTVBPUkFMSVRZX1VOU1'
    'BFQ0lGSUVEEAASIQodQUdHUkVHQVRJT05fVEVNUE9SQUxJVFlfREVMVEEQARImCiJBR0dSRUdB'
    'VElPTl9URU1QT1JBTElUWV9DVU1VTEFUSVZFEAI=');

@$core.Deprecated('Use dataPointFlagsDescriptor instead')
const DataPointFlags$json = {
  '1': 'DataPointFlags',
  '2': [
    {'1': 'DATA_POINT_FLAGS_DO_NOT_USE', '2': 0},
    {'1': 'DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK', '2': 1},
  ],
};

/// Descriptor for `DataPointFlags`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List dataPointFlagsDescriptor = $convert.base64Decode(
    'Cg5EYXRhUG9pbnRGbGFncxIfChtEQVRBX1BPSU5UX0ZMQUdTX0RPX05PVF9VU0UQABIrCidEQV'
    'RBX1BPSU5UX0ZMQUdTX05PX1JFQ09SREVEX1ZBTFVFX01BU0sQAQ==');

@$core.Deprecated('Use metricsDataDescriptor instead')
const MetricsData$json = {
  '1': 'MetricsData',
  '2': [
    {
      '1': 'resource_metrics',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.ResourceMetrics',
      '10': 'resourceMetrics'
    },
  ],
};

/// Descriptor for `MetricsData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metricsDataDescriptor = $convert.base64Decode(
    'CgtNZXRyaWNzRGF0YRJaChByZXNvdXJjZV9tZXRyaWNzGAEgAygLMi8ub3BlbnRlbGVtZXRyeS'
    '5wcm90by5tZXRyaWNzLnYxLlJlc291cmNlTWV0cmljc1IPcmVzb3VyY2VNZXRyaWNz');

@$core.Deprecated('Use resourceMetricsDescriptor instead')
const ResourceMetrics$json = {
  '1': 'ResourceMetrics',
  '2': [
    {
      '1': 'resource',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.opentelemetry.proto.resource.v1.Resource',
      '10': 'resource'
    },
    {
      '1': 'scope_metrics',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.ScopeMetrics',
      '10': 'scopeMetrics'
    },
    {'1': 'schema_url', '3': 3, '4': 1, '5': 9, '10': 'schemaUrl'},
  ],
  '9': [
    {'1': 1000, '2': 1001},
  ],
};

/// Descriptor for `ResourceMetrics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resourceMetricsDescriptor = $convert.base64Decode(
    'Cg9SZXNvdXJjZU1ldHJpY3MSRQoIcmVzb3VyY2UYASABKAsyKS5vcGVudGVsZW1ldHJ5LnByb3'
    'RvLnJlc291cmNlLnYxLlJlc291cmNlUghyZXNvdXJjZRJRCg1zY29wZV9tZXRyaWNzGAIgAygL'
    'Miwub3BlbnRlbGVtZXRyeS5wcm90by5tZXRyaWNzLnYxLlNjb3BlTWV0cmljc1IMc2NvcGVNZX'
    'RyaWNzEh0KCnNjaGVtYV91cmwYAyABKAlSCXNjaGVtYVVybEoGCOgHEOkH');

@$core.Deprecated('Use scopeMetricsDescriptor instead')
const ScopeMetrics$json = {
  '1': 'ScopeMetrics',
  '2': [
    {
      '1': 'scope',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.opentelemetry.proto.common.v1.InstrumentationScope',
      '10': 'scope'
    },
    {
      '1': 'metrics',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.Metric',
      '10': 'metrics'
    },
    {'1': 'schema_url', '3': 3, '4': 1, '5': 9, '10': 'schemaUrl'},
  ],
};

/// Descriptor for `ScopeMetrics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scopeMetricsDescriptor = $convert.base64Decode(
    'CgxTY29wZU1ldHJpY3MSSQoFc2NvcGUYASABKAsyMy5vcGVudGVsZW1ldHJ5LnByb3RvLmNvbW'
    '1vbi52MS5JbnN0cnVtZW50YXRpb25TY29wZVIFc2NvcGUSQAoHbWV0cmljcxgCIAMoCzImLm9w'
    'ZW50ZWxlbWV0cnkucHJvdG8ubWV0cmljcy52MS5NZXRyaWNSB21ldHJpY3MSHQoKc2NoZW1hX3'
    'VybBgDIAEoCVIJc2NoZW1hVXJs');

@$core.Deprecated('Use metricDescriptor instead')
const Metric$json = {
  '1': 'Metric',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'unit', '3': 3, '4': 1, '5': 9, '10': 'unit'},
    {
      '1': 'gauge',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.Gauge',
      '9': 0,
      '10': 'gauge'
    },
    {
      '1': 'sum',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.Sum',
      '9': 0,
      '10': 'sum'
    },
    {
      '1': 'histogram',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.Histogram',
      '9': 0,
      '10': 'histogram'
    },
    {
      '1': 'exponential_histogram',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.ExponentialHistogram',
      '9': 0,
      '10': 'exponentialHistogram'
    },
    {
      '1': 'summary',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.Summary',
      '9': 0,
      '10': 'summary'
    },
  ],
  '8': [
    {'1': 'data'},
  ],
  '9': [
    {'1': 4, '2': 5},
    {'1': 6, '2': 7},
    {'1': 8, '2': 9},
  ],
};

/// Descriptor for `Metric`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metricDescriptor = $convert.base64Decode(
    'CgZNZXRyaWMSEgoEbmFtZRgBIAEoCVIEbmFtZRIgCgtkZXNjcmlwdGlvbhgCIAEoCVILZGVzY3'
    'JpcHRpb24SEgoEdW5pdBgDIAEoCVIEdW5pdBI9CgVnYXVnZRgFIAEoCzIlLm9wZW50ZWxlbWV0'
    'cnkucHJvdG8ubWV0cmljcy52MS5HYXVnZUgAUgVnYXVnZRI3CgNzdW0YByABKAsyIy5vcGVudG'
    'VsZW1ldHJ5LnByb3RvLm1ldHJpY3MudjEuU3VtSABSA3N1bRJJCgloaXN0b2dyYW0YCSABKAsy'
    'KS5vcGVudGVsZW1ldHJ5LnByb3RvLm1ldHJpY3MudjEuSGlzdG9ncmFtSABSCWhpc3RvZ3JhbR'
    'JrChVleHBvbmVudGlhbF9oaXN0b2dyYW0YCiABKAsyNC5vcGVudGVsZW1ldHJ5LnByb3RvLm1l'
    'dHJpY3MudjEuRXhwb25lbnRpYWxIaXN0b2dyYW1IAFIUZXhwb25lbnRpYWxIaXN0b2dyYW0SQw'
    'oHc3VtbWFyeRgLIAEoCzInLm9wZW50ZWxlbWV0cnkucHJvdG8ubWV0cmljcy52MS5TdW1tYXJ5'
    'SABSB3N1bW1hcnlCBgoEZGF0YUoECAQQBUoECAYQB0oECAgQCQ==');

@$core.Deprecated('Use gaugeDescriptor instead')
const Gauge$json = {
  '1': 'Gauge',
  '2': [
    {
      '1': 'data_points',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.NumberDataPoint',
      '10': 'dataPoints'
    },
  ],
};

/// Descriptor for `Gauge`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gaugeDescriptor = $convert.base64Decode(
    'CgVHYXVnZRJQCgtkYXRhX3BvaW50cxgBIAMoCzIvLm9wZW50ZWxlbWV0cnkucHJvdG8ubWV0cm'
    'ljcy52MS5OdW1iZXJEYXRhUG9pbnRSCmRhdGFQb2ludHM=');

@$core.Deprecated('Use sumDescriptor instead')
const Sum$json = {
  '1': 'Sum',
  '2': [
    {
      '1': 'data_points',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.NumberDataPoint',
      '10': 'dataPoints'
    },
    {
      '1': 'aggregation_temporality',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.opentelemetry.proto.metrics.v1.AggregationTemporality',
      '10': 'aggregationTemporality'
    },
    {'1': 'is_monotonic', '3': 3, '4': 1, '5': 8, '10': 'isMonotonic'},
  ],
};

/// Descriptor for `Sum`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sumDescriptor = $convert.base64Decode(
    'CgNTdW0SUAoLZGF0YV9wb2ludHMYASADKAsyLy5vcGVudGVsZW1ldHJ5LnByb3RvLm1ldHJpY3'
    'MudjEuTnVtYmVyRGF0YVBvaW50UgpkYXRhUG9pbnRzEm8KF2FnZ3JlZ2F0aW9uX3RlbXBvcmFs'
    'aXR5GAIgASgOMjYub3BlbnRlbGVtZXRyeS5wcm90by5tZXRyaWNzLnYxLkFnZ3JlZ2F0aW9uVG'
    'VtcG9yYWxpdHlSFmFnZ3JlZ2F0aW9uVGVtcG9yYWxpdHkSIQoMaXNfbW9ub3RvbmljGAMgASgI'
    'Ugtpc01vbm90b25pYw==');

@$core.Deprecated('Use histogramDescriptor instead')
const Histogram$json = {
  '1': 'Histogram',
  '2': [
    {
      '1': 'data_points',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.HistogramDataPoint',
      '10': 'dataPoints'
    },
    {
      '1': 'aggregation_temporality',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.opentelemetry.proto.metrics.v1.AggregationTemporality',
      '10': 'aggregationTemporality'
    },
  ],
};

/// Descriptor for `Histogram`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List histogramDescriptor = $convert.base64Decode(
    'CglIaXN0b2dyYW0SUwoLZGF0YV9wb2ludHMYASADKAsyMi5vcGVudGVsZW1ldHJ5LnByb3RvLm'
    '1ldHJpY3MudjEuSGlzdG9ncmFtRGF0YVBvaW50UgpkYXRhUG9pbnRzEm8KF2FnZ3JlZ2F0aW9u'
    'X3RlbXBvcmFsaXR5GAIgASgOMjYub3BlbnRlbGVtZXRyeS5wcm90by5tZXRyaWNzLnYxLkFnZ3'
    'JlZ2F0aW9uVGVtcG9yYWxpdHlSFmFnZ3JlZ2F0aW9uVGVtcG9yYWxpdHk=');

@$core.Deprecated('Use exponentialHistogramDescriptor instead')
const ExponentialHistogram$json = {
  '1': 'ExponentialHistogram',
  '2': [
    {
      '1': 'data_points',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.ExponentialHistogramDataPoint',
      '10': 'dataPoints'
    },
    {
      '1': 'aggregation_temporality',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.opentelemetry.proto.metrics.v1.AggregationTemporality',
      '10': 'aggregationTemporality'
    },
  ],
};

/// Descriptor for `ExponentialHistogram`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exponentialHistogramDescriptor = $convert.base64Decode(
    'ChRFeHBvbmVudGlhbEhpc3RvZ3JhbRJeCgtkYXRhX3BvaW50cxgBIAMoCzI9Lm9wZW50ZWxlbW'
    'V0cnkucHJvdG8ubWV0cmljcy52MS5FeHBvbmVudGlhbEhpc3RvZ3JhbURhdGFQb2ludFIKZGF0'
    'YVBvaW50cxJvChdhZ2dyZWdhdGlvbl90ZW1wb3JhbGl0eRgCIAEoDjI2Lm9wZW50ZWxlbWV0cn'
    'kucHJvdG8ubWV0cmljcy52MS5BZ2dyZWdhdGlvblRlbXBvcmFsaXR5UhZhZ2dyZWdhdGlvblRl'
    'bXBvcmFsaXR5');

@$core.Deprecated('Use summaryDescriptor instead')
const Summary$json = {
  '1': 'Summary',
  '2': [
    {
      '1': 'data_points',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.SummaryDataPoint',
      '10': 'dataPoints'
    },
  ],
};

/// Descriptor for `Summary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List summaryDescriptor = $convert.base64Decode(
    'CgdTdW1tYXJ5ElEKC2RhdGFfcG9pbnRzGAEgAygLMjAub3BlbnRlbGVtZXRyeS5wcm90by5tZX'
    'RyaWNzLnYxLlN1bW1hcnlEYXRhUG9pbnRSCmRhdGFQb2ludHM=');

@$core.Deprecated('Use numberDataPointDescriptor instead')
const NumberDataPoint$json = {
  '1': 'NumberDataPoint',
  '2': [
    {
      '1': 'attributes',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.common.v1.KeyValue',
      '10': 'attributes'
    },
    {
      '1': 'start_time_unix_nano',
      '3': 2,
      '4': 1,
      '5': 6,
      '10': 'startTimeUnixNano'
    },
    {'1': 'time_unix_nano', '3': 3, '4': 1, '5': 6, '10': 'timeUnixNano'},
    {'1': 'as_double', '3': 4, '4': 1, '5': 1, '9': 0, '10': 'asDouble'},
    {'1': 'as_int', '3': 6, '4': 1, '5': 16, '9': 0, '10': 'asInt'},
    {
      '1': 'exemplars',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.Exemplar',
      '10': 'exemplars'
    },
    {'1': 'flags', '3': 8, '4': 1, '5': 13, '10': 'flags'},
  ],
  '8': [
    {'1': 'value'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `NumberDataPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List numberDataPointDescriptor = $convert.base64Decode(
    'Cg9OdW1iZXJEYXRhUG9pbnQSRwoKYXR0cmlidXRlcxgHIAMoCzInLm9wZW50ZWxlbWV0cnkucH'
    'JvdG8uY29tbW9uLnYxLktleVZhbHVlUgphdHRyaWJ1dGVzEi8KFHN0YXJ0X3RpbWVfdW5peF9u'
    'YW5vGAIgASgGUhFzdGFydFRpbWVVbml4TmFubxIkCg50aW1lX3VuaXhfbmFubxgDIAEoBlIMdG'
    'ltZVVuaXhOYW5vEh0KCWFzX2RvdWJsZRgEIAEoAUgAUghhc0RvdWJsZRIXCgZhc19pbnQYBiAB'
    'KBBIAFIFYXNJbnQSRgoJZXhlbXBsYXJzGAUgAygLMigub3BlbnRlbGVtZXRyeS5wcm90by5tZX'
    'RyaWNzLnYxLkV4ZW1wbGFyUglleGVtcGxhcnMSFAoFZmxhZ3MYCCABKA1SBWZsYWdzQgcKBXZh'
    'bHVlSgQIARAC');

@$core.Deprecated('Use histogramDataPointDescriptor instead')
const HistogramDataPoint$json = {
  '1': 'HistogramDataPoint',
  '2': [
    {
      '1': 'attributes',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.common.v1.KeyValue',
      '10': 'attributes'
    },
    {
      '1': 'start_time_unix_nano',
      '3': 2,
      '4': 1,
      '5': 6,
      '10': 'startTimeUnixNano'
    },
    {'1': 'time_unix_nano', '3': 3, '4': 1, '5': 6, '10': 'timeUnixNano'},
    {'1': 'count', '3': 4, '4': 1, '5': 6, '10': 'count'},
    {'1': 'sum', '3': 5, '4': 1, '5': 1, '9': 0, '10': 'sum', '17': true},
    {'1': 'bucket_counts', '3': 6, '4': 3, '5': 6, '10': 'bucketCounts'},
    {'1': 'explicit_bounds', '3': 7, '4': 3, '5': 1, '10': 'explicitBounds'},
    {
      '1': 'exemplars',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.Exemplar',
      '10': 'exemplars'
    },
    {'1': 'flags', '3': 10, '4': 1, '5': 13, '10': 'flags'},
    {'1': 'min', '3': 11, '4': 1, '5': 1, '9': 1, '10': 'min', '17': true},
    {'1': 'max', '3': 12, '4': 1, '5': 1, '9': 2, '10': 'max', '17': true},
  ],
  '8': [
    {'1': '_sum'},
    {'1': '_min'},
    {'1': '_max'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `HistogramDataPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List histogramDataPointDescriptor = $convert.base64Decode(
    'ChJIaXN0b2dyYW1EYXRhUG9pbnQSRwoKYXR0cmlidXRlcxgJIAMoCzInLm9wZW50ZWxlbWV0cn'
    'kucHJvdG8uY29tbW9uLnYxLktleVZhbHVlUgphdHRyaWJ1dGVzEi8KFHN0YXJ0X3RpbWVfdW5p'
    'eF9uYW5vGAIgASgGUhFzdGFydFRpbWVVbml4TmFubxIkCg50aW1lX3VuaXhfbmFubxgDIAEoBl'
    'IMdGltZVVuaXhOYW5vEhQKBWNvdW50GAQgASgGUgVjb3VudBIVCgNzdW0YBSABKAFIAFIDc3Vt'
    'iAEBEiMKDWJ1Y2tldF9jb3VudHMYBiADKAZSDGJ1Y2tldENvdW50cxInCg9leHBsaWNpdF9ib3'
    'VuZHMYByADKAFSDmV4cGxpY2l0Qm91bmRzEkYKCWV4ZW1wbGFycxgIIAMoCzIoLm9wZW50ZWxl'
    'bWV0cnkucHJvdG8ubWV0cmljcy52MS5FeGVtcGxhclIJZXhlbXBsYXJzEhQKBWZsYWdzGAogAS'
    'gNUgVmbGFncxIVCgNtaW4YCyABKAFIAVIDbWluiAEBEhUKA21heBgMIAEoAUgCUgNtYXiIAQFC'
    'BgoEX3N1bUIGCgRfbWluQgYKBF9tYXhKBAgBEAI=');

@$core.Deprecated('Use exponentialHistogramDataPointDescriptor instead')
const ExponentialHistogramDataPoint$json = {
  '1': 'ExponentialHistogramDataPoint',
  '2': [
    {
      '1': 'attributes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.common.v1.KeyValue',
      '10': 'attributes'
    },
    {
      '1': 'start_time_unix_nano',
      '3': 2,
      '4': 1,
      '5': 6,
      '10': 'startTimeUnixNano'
    },
    {'1': 'time_unix_nano', '3': 3, '4': 1, '5': 6, '10': 'timeUnixNano'},
    {'1': 'count', '3': 4, '4': 1, '5': 6, '10': 'count'},
    {'1': 'sum', '3': 5, '4': 1, '5': 1, '9': 0, '10': 'sum', '17': true},
    {'1': 'scale', '3': 6, '4': 1, '5': 17, '10': 'scale'},
    {'1': 'zero_count', '3': 7, '4': 1, '5': 6, '10': 'zeroCount'},
    {
      '1': 'positive',
      '3': 8,
      '4': 1,
      '5': 11,
      '6':
          '.opentelemetry.proto.metrics.v1.ExponentialHistogramDataPoint.Buckets',
      '10': 'positive'
    },
    {
      '1': 'negative',
      '3': 9,
      '4': 1,
      '5': 11,
      '6':
          '.opentelemetry.proto.metrics.v1.ExponentialHistogramDataPoint.Buckets',
      '10': 'negative'
    },
    {'1': 'flags', '3': 10, '4': 1, '5': 13, '10': 'flags'},
    {
      '1': 'exemplars',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.Exemplar',
      '10': 'exemplars'
    },
    {'1': 'min', '3': 12, '4': 1, '5': 1, '9': 1, '10': 'min', '17': true},
    {'1': 'max', '3': 13, '4': 1, '5': 1, '9': 2, '10': 'max', '17': true},
    {'1': 'zero_threshold', '3': 14, '4': 1, '5': 1, '10': 'zeroThreshold'},
  ],
  '3': [ExponentialHistogramDataPoint_Buckets$json],
  '8': [
    {'1': '_sum'},
    {'1': '_min'},
    {'1': '_max'},
  ],
};

@$core.Deprecated('Use exponentialHistogramDataPointDescriptor instead')
const ExponentialHistogramDataPoint_Buckets$json = {
  '1': 'Buckets',
  '2': [
    {'1': 'offset', '3': 1, '4': 1, '5': 17, '10': 'offset'},
    {'1': 'bucket_counts', '3': 2, '4': 3, '5': 4, '10': 'bucketCounts'},
  ],
};

/// Descriptor for `ExponentialHistogramDataPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exponentialHistogramDataPointDescriptor = $convert.base64Decode(
    'Ch1FeHBvbmVudGlhbEhpc3RvZ3JhbURhdGFQb2ludBJHCgphdHRyaWJ1dGVzGAEgAygLMicub3'
    'BlbnRlbGVtZXRyeS5wcm90by5jb21tb24udjEuS2V5VmFsdWVSCmF0dHJpYnV0ZXMSLwoUc3Rh'
    'cnRfdGltZV91bml4X25hbm8YAiABKAZSEXN0YXJ0VGltZVVuaXhOYW5vEiQKDnRpbWVfdW5peF'
    '9uYW5vGAMgASgGUgx0aW1lVW5peE5hbm8SFAoFY291bnQYBCABKAZSBWNvdW50EhUKA3N1bRgF'
    'IAEoAUgAUgNzdW2IAQESFAoFc2NhbGUYBiABKBFSBXNjYWxlEh0KCnplcm9fY291bnQYByABKA'
    'ZSCXplcm9Db3VudBJhCghwb3NpdGl2ZRgIIAEoCzJFLm9wZW50ZWxlbWV0cnkucHJvdG8ubWV0'
    'cmljcy52MS5FeHBvbmVudGlhbEhpc3RvZ3JhbURhdGFQb2ludC5CdWNrZXRzUghwb3NpdGl2ZR'
    'JhCghuZWdhdGl2ZRgJIAEoCzJFLm9wZW50ZWxlbWV0cnkucHJvdG8ubWV0cmljcy52MS5FeHBv'
    'bmVudGlhbEhpc3RvZ3JhbURhdGFQb2ludC5CdWNrZXRzUghuZWdhdGl2ZRIUCgVmbGFncxgKIA'
    'EoDVIFZmxhZ3MSRgoJZXhlbXBsYXJzGAsgAygLMigub3BlbnRlbGVtZXRyeS5wcm90by5tZXRy'
    'aWNzLnYxLkV4ZW1wbGFyUglleGVtcGxhcnMSFQoDbWluGAwgASgBSAFSA21pbogBARIVCgNtYX'
    'gYDSABKAFIAlIDbWF4iAEBEiUKDnplcm9fdGhyZXNob2xkGA4gASgBUg16ZXJvVGhyZXNob2xk'
    'GkYKB0J1Y2tldHMSFgoGb2Zmc2V0GAEgASgRUgZvZmZzZXQSIwoNYnVja2V0X2NvdW50cxgCIA'
    'MoBFIMYnVja2V0Q291bnRzQgYKBF9zdW1CBgoEX21pbkIGCgRfbWF4');

@$core.Deprecated('Use summaryDataPointDescriptor instead')
const SummaryDataPoint$json = {
  '1': 'SummaryDataPoint',
  '2': [
    {
      '1': 'attributes',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.common.v1.KeyValue',
      '10': 'attributes'
    },
    {
      '1': 'start_time_unix_nano',
      '3': 2,
      '4': 1,
      '5': 6,
      '10': 'startTimeUnixNano'
    },
    {'1': 'time_unix_nano', '3': 3, '4': 1, '5': 6, '10': 'timeUnixNano'},
    {'1': 'count', '3': 4, '4': 1, '5': 6, '10': 'count'},
    {'1': 'sum', '3': 5, '4': 1, '5': 1, '10': 'sum'},
    {
      '1': 'quantile_values',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.metrics.v1.SummaryDataPoint.ValueAtQuantile',
      '10': 'quantileValues'
    },
    {'1': 'flags', '3': 8, '4': 1, '5': 13, '10': 'flags'},
  ],
  '3': [SummaryDataPoint_ValueAtQuantile$json],
  '9': [
    {'1': 1, '2': 2},
  ],
};

@$core.Deprecated('Use summaryDataPointDescriptor instead')
const SummaryDataPoint_ValueAtQuantile$json = {
  '1': 'ValueAtQuantile',
  '2': [
    {'1': 'quantile', '3': 1, '4': 1, '5': 1, '10': 'quantile'},
    {'1': 'value', '3': 2, '4': 1, '5': 1, '10': 'value'},
  ],
};

/// Descriptor for `SummaryDataPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List summaryDataPointDescriptor = $convert.base64Decode(
    'ChBTdW1tYXJ5RGF0YVBvaW50EkcKCmF0dHJpYnV0ZXMYByADKAsyJy5vcGVudGVsZW1ldHJ5Ln'
    'Byb3RvLmNvbW1vbi52MS5LZXlWYWx1ZVIKYXR0cmlidXRlcxIvChRzdGFydF90aW1lX3VuaXhf'
    'bmFubxgCIAEoBlIRc3RhcnRUaW1lVW5peE5hbm8SJAoOdGltZV91bml4X25hbm8YAyABKAZSDH'
    'RpbWVVbml4TmFubxIUCgVjb3VudBgEIAEoBlIFY291bnQSEAoDc3VtGAUgASgBUgNzdW0SaQoP'
    'cXVhbnRpbGVfdmFsdWVzGAYgAygLMkAub3BlbnRlbGVtZXRyeS5wcm90by5tZXRyaWNzLnYxLl'
    'N1bW1hcnlEYXRhUG9pbnQuVmFsdWVBdFF1YW50aWxlUg5xdWFudGlsZVZhbHVlcxIUCgVmbGFn'
    'cxgIIAEoDVIFZmxhZ3MaQwoPVmFsdWVBdFF1YW50aWxlEhoKCHF1YW50aWxlGAEgASgBUghxdW'
    'FudGlsZRIUCgV2YWx1ZRgCIAEoAVIFdmFsdWVKBAgBEAI=');

@$core.Deprecated('Use exemplarDescriptor instead')
const Exemplar$json = {
  '1': 'Exemplar',
  '2': [
    {
      '1': 'filtered_attributes',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.common.v1.KeyValue',
      '10': 'filteredAttributes'
    },
    {'1': 'time_unix_nano', '3': 2, '4': 1, '5': 6, '10': 'timeUnixNano'},
    {'1': 'as_double', '3': 3, '4': 1, '5': 1, '9': 0, '10': 'asDouble'},
    {'1': 'as_int', '3': 6, '4': 1, '5': 16, '9': 0, '10': 'asInt'},
    {'1': 'span_id', '3': 4, '4': 1, '5': 12, '10': 'spanId'},
    {'1': 'trace_id', '3': 5, '4': 1, '5': 12, '10': 'traceId'},
  ],
  '8': [
    {'1': 'value'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `Exemplar`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exemplarDescriptor = $convert.base64Decode(
    'CghFeGVtcGxhchJYChNmaWx0ZXJlZF9hdHRyaWJ1dGVzGAcgAygLMicub3BlbnRlbGVtZXRyeS'
    '5wcm90by5jb21tb24udjEuS2V5VmFsdWVSEmZpbHRlcmVkQXR0cmlidXRlcxIkCg50aW1lX3Vu'
    'aXhfbmFubxgCIAEoBlIMdGltZVVuaXhOYW5vEh0KCWFzX2RvdWJsZRgDIAEoAUgAUghhc0RvdW'
    'JsZRIXCgZhc19pbnQYBiABKBBIAFIFYXNJbnQSFwoHc3Bhbl9pZBgEIAEoDFIGc3BhbklkEhkK'
    'CHRyYWNlX2lkGAUgASgMUgd0cmFjZUlkQgcKBXZhbHVlSgQIARAC');
