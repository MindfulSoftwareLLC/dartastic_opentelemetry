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

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../../../metrics/v1/metrics.pb.dart' as $6;

class ExportMetricsServiceRequest extends $pb.GeneratedMessage {
  factory ExportMetricsServiceRequest({
    $core.Iterable<$6.ResourceMetrics>? resourceMetrics,
  }) {
    final $result = create();
    if (resourceMetrics != null) {
      $result.resourceMetrics.addAll(resourceMetrics);
    }
    return $result;
  }
  ExportMetricsServiceRequest._() : super();
  factory ExportMetricsServiceRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ExportMetricsServiceRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ExportMetricsServiceRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'opentelemetry.proto.collector.metrics.v1'), createEmptyInstance: create)
    ..pc<$6.ResourceMetrics>(1, _omitFieldNames ? '' : 'resourceMetrics', $pb.PbFieldType.PM, subBuilder: $6.ResourceMetrics.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ExportMetricsServiceRequest clone() => ExportMetricsServiceRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ExportMetricsServiceRequest copyWith(void Function(ExportMetricsServiceRequest) updates) => super.copyWith((message) => updates(message as ExportMetricsServiceRequest)) as ExportMetricsServiceRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportMetricsServiceRequest create() => ExportMetricsServiceRequest._();
  ExportMetricsServiceRequest createEmptyInstance() => create();
  static $pb.PbList<ExportMetricsServiceRequest> createRepeated() => $pb.PbList<ExportMetricsServiceRequest>();
  @$core.pragma('dart2js:noInline')
  static ExportMetricsServiceRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExportMetricsServiceRequest>(create);
  static ExportMetricsServiceRequest? _defaultInstance;

  /// An array of ResourceMetrics.
  /// For data coming from a single resource this array will typically contain one
  /// element. Intermediary nodes (such as OpenTelemetry Collector) that receive
  /// data from multiple origins typically batch the data before forwarding further and
  /// in that case this array will contain multiple elements.
  @$pb.TagNumber(1)
  $core.List<$6.ResourceMetrics> get resourceMetrics => $_getList(0);
}

class ExportMetricsServiceResponse extends $pb.GeneratedMessage {
  factory ExportMetricsServiceResponse({
    ExportMetricsPartialSuccess? partialSuccess,
  }) {
    final $result = create();
    if (partialSuccess != null) {
      $result.partialSuccess = partialSuccess;
    }
    return $result;
  }
  ExportMetricsServiceResponse._() : super();
  factory ExportMetricsServiceResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ExportMetricsServiceResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ExportMetricsServiceResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'opentelemetry.proto.collector.metrics.v1'), createEmptyInstance: create)
    ..aOM<ExportMetricsPartialSuccess>(1, _omitFieldNames ? '' : 'partialSuccess', subBuilder: ExportMetricsPartialSuccess.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ExportMetricsServiceResponse clone() => ExportMetricsServiceResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ExportMetricsServiceResponse copyWith(void Function(ExportMetricsServiceResponse) updates) => super.copyWith((message) => updates(message as ExportMetricsServiceResponse)) as ExportMetricsServiceResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportMetricsServiceResponse create() => ExportMetricsServiceResponse._();
  ExportMetricsServiceResponse createEmptyInstance() => create();
  static $pb.PbList<ExportMetricsServiceResponse> createRepeated() => $pb.PbList<ExportMetricsServiceResponse>();
  @$core.pragma('dart2js:noInline')
  static ExportMetricsServiceResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExportMetricsServiceResponse>(create);
  static ExportMetricsServiceResponse? _defaultInstance;

  ///  The details of a partially successful export request.
  ///
  ///  If the request is only partially accepted
  ///  (i.e. when the server accepts only parts of the data and rejects the rest)
  ///  the server MUST initialize the `partial_success` field and MUST
  ///  set the `rejected_<signal>` with the number of items it rejected.
  ///
  ///  Servers MAY also make use of the `partial_success` field to convey
  ///  warnings/suggestions to senders even when the request was fully accepted.
  ///  In such cases, the `rejected_<signal>` MUST have a value of `0` and
  ///  the `error_message` MUST be non-empty.
  ///
  ///  A `partial_success` message with an empty value (rejected_\<signal> = 0 and
  ///  `error_message` = "") is equivalent to it not being set/present. Senders
  ///  SHOULD interpret it the same way as in the full success case.
  @$pb.TagNumber(1)
  ExportMetricsPartialSuccess get partialSuccess => $_getN(0);
  @$pb.TagNumber(1)
  set partialSuccess(ExportMetricsPartialSuccess v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasPartialSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearPartialSuccess() => clearField(1);
  @$pb.TagNumber(1)
  ExportMetricsPartialSuccess ensurePartialSuccess() => $_ensure(0);
}

class ExportMetricsPartialSuccess extends $pb.GeneratedMessage {
  factory ExportMetricsPartialSuccess({
    $fixnum.Int64? rejectedDataPoints,
    $core.String? errorMessage,
  }) {
    final $result = create();
    if (rejectedDataPoints != null) {
      $result.rejectedDataPoints = rejectedDataPoints;
    }
    if (errorMessage != null) {
      $result.errorMessage = errorMessage;
    }
    return $result;
  }
  ExportMetricsPartialSuccess._() : super();
  factory ExportMetricsPartialSuccess.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ExportMetricsPartialSuccess.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ExportMetricsPartialSuccess', package: const $pb.PackageName(_omitMessageNames ? '' : 'opentelemetry.proto.collector.metrics.v1'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'rejectedDataPoints')
    ..aOS(2, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ExportMetricsPartialSuccess clone() => ExportMetricsPartialSuccess()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ExportMetricsPartialSuccess copyWith(void Function(ExportMetricsPartialSuccess) updates) => super.copyWith((message) => updates(message as ExportMetricsPartialSuccess)) as ExportMetricsPartialSuccess;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportMetricsPartialSuccess create() => ExportMetricsPartialSuccess._();
  ExportMetricsPartialSuccess createEmptyInstance() => create();
  static $pb.PbList<ExportMetricsPartialSuccess> createRepeated() => $pb.PbList<ExportMetricsPartialSuccess>();
  @$core.pragma('dart2js:noInline')
  static ExportMetricsPartialSuccess getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExportMetricsPartialSuccess>(create);
  static ExportMetricsPartialSuccess? _defaultInstance;

  ///  The number of rejected data points.
  ///
  ///  A `rejected_<signal>` field holding a `0` value indicates that the
  ///  request was fully accepted.
  @$pb.TagNumber(1)
  $fixnum.Int64 get rejectedDataPoints => $_getI64(0);
  @$pb.TagNumber(1)
  set rejectedDataPoints($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRejectedDataPoints() => $_has(0);
  @$pb.TagNumber(1)
  void clearRejectedDataPoints() => clearField(1);

  ///  A developer-facing human-readable message in English. It should be used
  ///  either to explain why the server rejected parts of the data during a partial
  ///  success or to convey warnings/suggestions during a full success. The message
  ///  should offer guidance on how users can address such issues.
  ///
  ///  error_message is an optional field. An error_message with an empty value
  ///  is equivalent to it not being set.
  @$pb.TagNumber(2)
  $core.String get errorMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set errorMessage($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasErrorMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrorMessage() => clearField(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
