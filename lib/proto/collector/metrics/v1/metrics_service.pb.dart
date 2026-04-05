// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/collector/metrics/v1/metrics_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../../../metrics/v1/metrics.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ExportMetricsServiceRequest extends $pb.GeneratedMessage {
  factory ExportMetricsServiceRequest({
    $core.Iterable<$1.ResourceMetrics>? resourceMetrics,
  }) {
    final result = create();
    if (resourceMetrics != null) result.resourceMetrics.addAll(resourceMetrics);
    return result;
  }

  ExportMetricsServiceRequest._();

  factory ExportMetricsServiceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportMetricsServiceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportMetricsServiceRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.collector.metrics.v1'),
      createEmptyInstance: create)
    ..pPM<$1.ResourceMetrics>(1, _omitFieldNames ? '' : 'resourceMetrics',
        subBuilder: $1.ResourceMetrics.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportMetricsServiceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportMetricsServiceRequest copyWith(
          void Function(ExportMetricsServiceRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ExportMetricsServiceRequest))
          as ExportMetricsServiceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportMetricsServiceRequest create() =>
      ExportMetricsServiceRequest._();
  @$core.override
  ExportMetricsServiceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportMetricsServiceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportMetricsServiceRequest>(create);
  static ExportMetricsServiceRequest? _defaultInstance;

  /// An array of ResourceMetrics.
  /// For data coming from a single resource this array will typically contain one
  /// element. Intermediary nodes (such as OpenTelemetry Collector) that receive
  /// data from multiple origins typically batch the data before forwarding further and
  /// in that case this array will contain multiple elements.
  @$pb.TagNumber(1)
  $pb.PbList<$1.ResourceMetrics> get resourceMetrics => $_getList(0);
}

class ExportMetricsServiceResponse extends $pb.GeneratedMessage {
  factory ExportMetricsServiceResponse({
    ExportMetricsPartialSuccess? partialSuccess,
  }) {
    final result = create();
    if (partialSuccess != null) result.partialSuccess = partialSuccess;
    return result;
  }

  ExportMetricsServiceResponse._();

  factory ExportMetricsServiceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportMetricsServiceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportMetricsServiceResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.collector.metrics.v1'),
      createEmptyInstance: create)
    ..aOM<ExportMetricsPartialSuccess>(
        1, _omitFieldNames ? '' : 'partialSuccess',
        subBuilder: ExportMetricsPartialSuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportMetricsServiceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportMetricsServiceResponse copyWith(
          void Function(ExportMetricsServiceResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ExportMetricsServiceResponse))
          as ExportMetricsServiceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportMetricsServiceResponse create() =>
      ExportMetricsServiceResponse._();
  @$core.override
  ExportMetricsServiceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportMetricsServiceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportMetricsServiceResponse>(create);
  static ExportMetricsServiceResponse? _defaultInstance;

  /// The details of a partially successful export request.
  ///
  /// If the request is only partially accepted
  /// (i.e. when the server accepts only parts of the data and rejects the rest)
  /// the server MUST initialize the `partial_success` field and MUST
  /// set the `rejected_signal` with the number of items it rejected.
  ///
  /// Servers MAY also make use of the `partial_success` field to convey
  /// warnings/suggestions to senders even when the request was fully accepted.
  /// In such cases, the `rejected_signal` MUST have a value of `0` and
  /// the `error_message` MUST be non-empty.
  ///
  /// A `partial_success` message with an empty value (rejected_signal = 0 and
  /// `error_message` = "") is equivalent to it not being set/present. Senders
  /// SHOULD interpret it the same way as in the full success case.
  @$pb.TagNumber(1)
  ExportMetricsPartialSuccess get partialSuccess => $_getN(0);
  @$pb.TagNumber(1)
  set partialSuccess(ExportMetricsPartialSuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPartialSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearPartialSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  ExportMetricsPartialSuccess ensurePartialSuccess() => $_ensure(0);
}

class ExportMetricsPartialSuccess extends $pb.GeneratedMessage {
  factory ExportMetricsPartialSuccess({
    $fixnum.Int64? rejectedDataPoints,
    $core.String? errorMessage,
  }) {
    final result = create();
    if (rejectedDataPoints != null)
      result.rejectedDataPoints = rejectedDataPoints;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  ExportMetricsPartialSuccess._();

  factory ExportMetricsPartialSuccess.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportMetricsPartialSuccess.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportMetricsPartialSuccess',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.collector.metrics.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'rejectedDataPoints')
    ..aOS(2, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportMetricsPartialSuccess clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportMetricsPartialSuccess copyWith(
          void Function(ExportMetricsPartialSuccess) updates) =>
      super.copyWith(
              (message) => updates(message as ExportMetricsPartialSuccess))
          as ExportMetricsPartialSuccess;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportMetricsPartialSuccess create() =>
      ExportMetricsPartialSuccess._();
  @$core.override
  ExportMetricsPartialSuccess createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportMetricsPartialSuccess getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportMetricsPartialSuccess>(create);
  static ExportMetricsPartialSuccess? _defaultInstance;

  /// The number of rejected data points.
  ///
  /// A `rejected_signal` field holding a `0` value indicates that the
  /// request was fully accepted.
  @$pb.TagNumber(1)
  $fixnum.Int64 get rejectedDataPoints => $_getI64(0);
  @$pb.TagNumber(1)
  set rejectedDataPoints($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRejectedDataPoints() => $_has(0);
  @$pb.TagNumber(1)
  void clearRejectedDataPoints() => $_clearField(1);

  /// A developer-facing human-readable message in English. It should be used
  /// either to explain why the server rejected parts of the data during a partial
  /// success or to convey warnings/suggestions during a full success. The message
  /// should offer guidance on how users can address such issues.
  ///
  /// error_message is an optional field. An error_message with an empty value
  /// is equivalent to it not being set.
  @$pb.TagNumber(2)
  $core.String get errorMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set errorMessage($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrorMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrorMessage() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
