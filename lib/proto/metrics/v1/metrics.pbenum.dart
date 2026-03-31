// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/metrics/v1/metrics.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// AggregationTemporality defines how a metric aggregator reports aggregated
/// values. It describes how those values relate to the time interval over
/// which they are aggregated.
class AggregationTemporality extends $pb.ProtobufEnum {
  /// UNSPECIFIED is the default AggregationTemporality, it MUST not be used.
  static const AggregationTemporality AGGREGATION_TEMPORALITY_UNSPECIFIED =
      AggregationTemporality._(
          0, _omitEnumNames ? '' : 'AGGREGATION_TEMPORALITY_UNSPECIFIED');

  /// DELTA is an AggregationTemporality for a metric aggregator which reports
  /// changes since last report time. Successive metrics contain aggregation of
  /// values from continuous and non-overlapping intervals.
  ///
  /// The values for a DELTA metric are based only on the time interval
  /// associated with one measurement cycle. There is no dependency on
  /// previous measurements like is the case for CUMULATIVE metrics.
  ///
  /// For example, consider a system measuring the number of requests that
  /// it receives and reports the sum of these requests every second as a
  /// DELTA metric:
  ///
  ///   1. The system starts receiving at time=t_0.
  ///   2. A request is received, the system measures 1 request.
  ///   3. A request is received, the system measures 1 request.
  ///   4. A request is received, the system measures 1 request.
  ///   5. The 1 second collection cycle ends. A metric is exported for the
  ///      number of requests received over the interval of time t_0 to
  ///      t_0+1 with a value of 3.
  ///   6. A request is received, the system measures 1 request.
  ///   7. A request is received, the system measures 1 request.
  ///   8. The 1 second collection cycle ends. A metric is exported for the
  ///      number of requests received over the interval of time t_0+1 to
  ///      t_0+2 with a value of 2.
  static const AggregationTemporality AGGREGATION_TEMPORALITY_DELTA =
      AggregationTemporality._(
          1, _omitEnumNames ? '' : 'AGGREGATION_TEMPORALITY_DELTA');

  /// CUMULATIVE is an AggregationTemporality for a metric aggregator which
  /// reports changes since a fixed start time. This means that current values
  /// of a CUMULATIVE metric depend on all previous measurements since the
  /// start time. Because of this, the sender is required to retain this state
  /// in some form. If this state is lost or invalidated, the CUMULATIVE metric
  /// values MUST be reset and a new fixed start time following the last
  /// reported measurement time sent MUST be used.
  ///
  /// For example, consider a system measuring the number of requests that
  /// it receives and reports the sum of these requests every second as a
  /// CUMULATIVE metric:
  ///
  ///   1. The system starts receiving at time=t_0.
  ///   2. A request is received, the system measures 1 request.
  ///   3. A request is received, the system measures 1 request.
  ///   4. A request is received, the system measures 1 request.
  ///   5. The 1 second collection cycle ends. A metric is exported for the
  ///      number of requests received over the interval of time t_0 to
  ///      t_0+1 with a value of 3.
  ///   6. A request is received, the system measures 1 request.
  ///   7. A request is received, the system measures 1 request.
  ///   8. The 1 second collection cycle ends. A metric is exported for the
  ///      number of requests received over the interval of time t_0 to
  ///      t_0+2 with a value of 5.
  ///   9. The system experiences a fault and loses state.
  ///   10. The system recovers and resumes receiving at time=t_1.
  ///   11. A request is received, the system measures 1 request.
  ///   12. The 1 second collection cycle ends. A metric is exported for the
  ///      number of requests received over the interval of time t_1 to
  ///      t_0+1 with a value of 1.
  ///
  /// Note: Even though, when reporting changes since last report time, using
  /// CUMULATIVE is valid, it is not recommended. This may cause problems for
  /// systems that do not use start_time to determine when the aggregation
  /// value was reset (e.g. Prometheus).
  static const AggregationTemporality AGGREGATION_TEMPORALITY_CUMULATIVE =
      AggregationTemporality._(
          2, _omitEnumNames ? '' : 'AGGREGATION_TEMPORALITY_CUMULATIVE');

  static const $core.List<AggregationTemporality> values =
      <AggregationTemporality>[
    AGGREGATION_TEMPORALITY_UNSPECIFIED,
    AGGREGATION_TEMPORALITY_DELTA,
    AGGREGATION_TEMPORALITY_CUMULATIVE,
  ];

  static final $core.List<AggregationTemporality?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static AggregationTemporality? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AggregationTemporality._(super.value, super.name);
}

/// DataPointFlags is defined as a protobuf 'uint32' type and is to be used as a
/// bit-field representing 32 distinct boolean flags.  Each flag defined in this
/// enum is a bit-mask.  To test the presence of a single flag in the flags of
/// a data point, for example, use an expression like:
///
///   (point.flags & DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK) == DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK
class DataPointFlags extends $pb.ProtobufEnum {
  /// The zero value for the enum. Should not be used for comparisons.
  /// Instead use bitwise "and" with the appropriate mask as shown above.
  static const DataPointFlags DATA_POINT_FLAGS_DO_NOT_USE =
      DataPointFlags._(0, _omitEnumNames ? '' : 'DATA_POINT_FLAGS_DO_NOT_USE');

  /// This DataPoint is valid but has no recorded value.  This value
  /// SHOULD be used to reflect explicitly missing data in a series, as
  /// for an equivalent to the Prometheus "staleness marker".
  static const DataPointFlags DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK =
      DataPointFlags._(
          1, _omitEnumNames ? '' : 'DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK');

  static const $core.List<DataPointFlags> values = <DataPointFlags>[
    DATA_POINT_FLAGS_DO_NOT_USE,
    DATA_POINT_FLAGS_NO_RECORDED_VALUE_MASK,
  ];

  static final $core.List<DataPointFlags?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static DataPointFlags? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DataPointFlags._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
