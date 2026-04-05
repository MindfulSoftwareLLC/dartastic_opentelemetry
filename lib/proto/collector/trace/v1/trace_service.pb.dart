// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/collector/trace/v1/trace_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../../../trace/v1/trace.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ExportTraceServiceRequest extends $pb.GeneratedMessage {
  factory ExportTraceServiceRequest({
    $core.Iterable<$1.ResourceSpans>? resourceSpans,
  }) {
    final result = create();
    if (resourceSpans != null) result.resourceSpans.addAll(resourceSpans);
    return result;
  }

  ExportTraceServiceRequest._();

  factory ExportTraceServiceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportTraceServiceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportTraceServiceRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.collector.trace.v1'),
      createEmptyInstance: create)
    ..pPM<$1.ResourceSpans>(1, _omitFieldNames ? '' : 'resourceSpans',
        subBuilder: $1.ResourceSpans.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportTraceServiceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportTraceServiceRequest copyWith(
          void Function(ExportTraceServiceRequest) updates) =>
      super.copyWith((message) => updates(message as ExportTraceServiceRequest))
          as ExportTraceServiceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportTraceServiceRequest create() => ExportTraceServiceRequest._();
  @$core.override
  ExportTraceServiceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportTraceServiceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportTraceServiceRequest>(create);
  static ExportTraceServiceRequest? _defaultInstance;

  /// An array of ResourceSpans.
  /// For data coming from a single resource this array will typically contain one
  /// element. Intermediary nodes (such as OpenTelemetry Collector) that receive
  /// data from multiple origins typically batch the data before forwarding further and
  /// in that case this array will contain multiple elements.
  @$pb.TagNumber(1)
  $pb.PbList<$1.ResourceSpans> get resourceSpans => $_getList(0);
}

class ExportTraceServiceResponse extends $pb.GeneratedMessage {
  factory ExportTraceServiceResponse({
    ExportTracePartialSuccess? partialSuccess,
  }) {
    final result = create();
    if (partialSuccess != null) result.partialSuccess = partialSuccess;
    return result;
  }

  ExportTraceServiceResponse._();

  factory ExportTraceServiceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportTraceServiceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportTraceServiceResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.collector.trace.v1'),
      createEmptyInstance: create)
    ..aOM<ExportTracePartialSuccess>(1, _omitFieldNames ? '' : 'partialSuccess',
        subBuilder: ExportTracePartialSuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportTraceServiceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportTraceServiceResponse copyWith(
          void Function(ExportTraceServiceResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ExportTraceServiceResponse))
          as ExportTraceServiceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportTraceServiceResponse create() => ExportTraceServiceResponse._();
  @$core.override
  ExportTraceServiceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportTraceServiceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportTraceServiceResponse>(create);
  static ExportTraceServiceResponse? _defaultInstance;

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
  ExportTracePartialSuccess get partialSuccess => $_getN(0);
  @$pb.TagNumber(1)
  set partialSuccess(ExportTracePartialSuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPartialSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearPartialSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  ExportTracePartialSuccess ensurePartialSuccess() => $_ensure(0);
}

class ExportTracePartialSuccess extends $pb.GeneratedMessage {
  factory ExportTracePartialSuccess({
    $fixnum.Int64? rejectedSpans,
    $core.String? errorMessage,
  }) {
    final result = create();
    if (rejectedSpans != null) result.rejectedSpans = rejectedSpans;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  ExportTracePartialSuccess._();

  factory ExportTracePartialSuccess.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportTracePartialSuccess.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportTracePartialSuccess',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.collector.trace.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'rejectedSpans')
    ..aOS(2, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportTracePartialSuccess clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportTracePartialSuccess copyWith(
          void Function(ExportTracePartialSuccess) updates) =>
      super.copyWith((message) => updates(message as ExportTracePartialSuccess))
          as ExportTracePartialSuccess;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportTracePartialSuccess create() => ExportTracePartialSuccess._();
  @$core.override
  ExportTracePartialSuccess createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportTracePartialSuccess getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportTracePartialSuccess>(create);
  static ExportTracePartialSuccess? _defaultInstance;

  /// The number of rejected spans.
  ///
  /// A `rejected_signal` field holding a `0` value indicates that the
  /// request was fully accepted.
  @$pb.TagNumber(1)
  $fixnum.Int64 get rejectedSpans => $_getI64(0);
  @$pb.TagNumber(1)
  set rejectedSpans($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRejectedSpans() => $_has(0);
  @$pb.TagNumber(1)
  void clearRejectedSpans() => $_clearField(1);

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
