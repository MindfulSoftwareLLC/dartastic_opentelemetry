// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

//
//  Generated code. Do not modify.
//  source: opentelemetry/proto/metrics/v1/metrics.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references, public_member_api_docs
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// AggregationTemporality defines how a metric aggregator reports aggregated
/// values. It describes how those values relate to the time interval over
/// which they are aggregated.
class AggregationTemporality extends $pb.ProtobufEnum {
  static const AggregationTemporality AGGREGATION_TEMPORALITY_UNSPECIFIED =
      AggregationTemporality._(
          0, _omitEnumNames ? '' : 'AGGREGATION_TEMPORALITY_UNSPECIFIED');
  static const AggregationTemporality AGGREGATION_TEMPORALITY_DELTA =
      AggregationTemporality._(
          1, _omitEnumNames ? '' : 'AGGREGATION_TEMPORALITY_DELTA');
  static const AggregationTemporality AGGREGATION_TEMPORALITY_CUMULATIVE =
      AggregationTemporality._(
          2, _omitEnumNames ? '' : 'AGGREGATION_TEMPORALITY_CUMULATIVE');

  static const $core.List<AggregationTemporality> values =
      <AggregationTemporality>[
    AGGREGATION_TEMPORALITY_UNSPECIFIED,
    AGGREGATION_TEMPORALITY_DELTA,
    AGGREGATION_TEMPORALITY_CUMULATIVE,
  ];

  static final $core.Map<$core.int, AggregationTemporality> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static AggregationTemporality? valueOf($core.int value) => _byValue[value];

  const AggregationTemporality._($core.int v, $core.String n) : super(v, n);
}

///  DataPointFlags is defined as a protobuf 'uint32' type and is to be used as a
///  bit-field representing 32 distinct boolean flags.  Each flag defined in this
///  enum is a bit-mask.  To test the presence of a single flag in the flags of
///  a data point, for example, use an expression like:
///
///    (point.flags & DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK) == DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK
class DataPointFlags extends $pb.ProtobufEnum {
  static const DataPointFlags DATA_POINT_FLAGS_DO_NOT_USE =
      DataPointFlags._(0, _omitEnumNames ? '' : 'DATA_POINT_FLAGS_DO_NOT_USE');
  static const DataPointFlags DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK =
      DataPointFlags._(
          1, _omitEnumNames ? '' : 'DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK');

  static const $core.List<DataPointFlags> values = <DataPointFlags>[
    DATA_POINT_FLAGS_DO_NOT_USE,
    DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK,
  ];

  static final $core.Map<$core.int, DataPointFlags> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static DataPointFlags? valueOf($core.int value) => _byValue[value];

  const DataPointFlags._($core.int v, $core.String n) : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
