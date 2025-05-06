// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

//
//  Generated code. Do not modify.
//  source: opentelemetry/proto/collector/metrics/v1/metrics_service.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references, public_member_api_docs
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use exportMetricsServiceRequestDescriptor instead')
const ExportMetricsServiceRequest$json = {
  '1': 'ExportMetricsServiceRequest',
  '2': [
    {'1': 'resource_metrics', '3': 1, '4': 3, '5': 11, '6': '.opentelemetry.proto.metrics.v1.ResourceMetrics', '10': 'resourceMetrics'},
  ],
};

/// Descriptor for `ExportMetricsServiceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportMetricsServiceRequestDescriptor = $convert.base64Decode(
    'ChtFeHBvcnRNZXRyaWNzU2VydmljZVJlcXVlc3QSWgoQcmVzb3VyY2VfbWV0cmljcxgBIAMoCz'
    'IvLm9wZW50ZWxlbWV0cnkucHJvdG8ubWV0cmljcy52MS5SZXNvdXJjZU1ldHJpY3NSD3Jlc291'
    'cmNlTWV0cmljcw==');

@$core.Deprecated('Use exportMetricsServiceResponseDescriptor instead')
const ExportMetricsServiceResponse$json = {
  '1': 'ExportMetricsServiceResponse',
  '2': [
    {'1': 'partial_success', '3': 1, '4': 1, '5': 11, '6': '.opentelemetry.proto.collector.metrics.v1.ExportMetricsPartialSuccess', '10': 'partialSuccess'},
  ],
};

/// Descriptor for `ExportMetricsServiceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportMetricsServiceResponseDescriptor = $convert.base64Decode(
    'ChxFeHBvcnRNZXRyaWNzU2VydmljZVJlc3BvbnNlEm4KD3BhcnRpYWxfc3VjY2VzcxgBIAEoCz'
    'JFLm9wZW50ZWxlbWV0cnkucHJvdG8uY29sbGVjdG9yLm1ldHJpY3MudjEuRXhwb3J0TWV0cmlj'
    'c1BhcnRpYWxTdWNjZXNzUg5wYXJ0aWFsU3VjY2Vzcw==');

@$core.Deprecated('Use exportMetricsPartialSuccessDescriptor instead')
const ExportMetricsPartialSuccess$json = {
  '1': 'ExportMetricsPartialSuccess',
  '2': [
    {'1': 'rejected_data_points', '3': 1, '4': 1, '5': 3, '10': 'rejectedDataPoints'},
    {'1': 'error_message', '3': 2, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
};

/// Descriptor for `ExportMetricsPartialSuccess`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportMetricsPartialSuccessDescriptor = $convert.base64Decode(
    'ChtFeHBvcnRNZXRyaWNzUGFydGlhbFN1Y2Nlc3MSMAoUcmVqZWN0ZWRfZGF0YV9wb2ludHMYAS'
    'ABKANSEnJlamVjdGVkRGF0YVBvaW50cxIjCg1lcnJvcl9tZXNzYWdlGAIgASgJUgxlcnJvck1l'
    'c3NhZ2U=');

