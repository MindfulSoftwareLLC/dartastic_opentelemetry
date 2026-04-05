// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/collector/logs/v1/logs_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../../../logs/v1/logs.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ExportLogsServiceRequest extends $pb.GeneratedMessage {
  factory ExportLogsServiceRequest({
    $core.Iterable<$1.ResourceLogs>? resourceLogs,
  }) {
    final result = create();
    if (resourceLogs != null) result.resourceLogs.addAll(resourceLogs);
    return result;
  }

  ExportLogsServiceRequest._();

  factory ExportLogsServiceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportLogsServiceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportLogsServiceRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.collector.logs.v1'),
      createEmptyInstance: create)
    ..pPM<$1.ResourceLogs>(1, _omitFieldNames ? '' : 'resourceLogs',
        subBuilder: $1.ResourceLogs.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportLogsServiceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportLogsServiceRequest copyWith(
          void Function(ExportLogsServiceRequest) updates) =>
      super.copyWith((message) => updates(message as ExportLogsServiceRequest))
          as ExportLogsServiceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportLogsServiceRequest create() => ExportLogsServiceRequest._();
  @$core.override
  ExportLogsServiceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportLogsServiceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportLogsServiceRequest>(create);
  static ExportLogsServiceRequest? _defaultInstance;

  /// An array of ResourceLogs.
  /// For data coming from a single resource this array will typically contain one
  /// element. Intermediary nodes (such as OpenTelemetry Collector) that receive
  /// data from multiple origins typically batch the data before forwarding further and
  /// in that case this array will contain multiple elements.
  @$pb.TagNumber(1)
  $pb.PbList<$1.ResourceLogs> get resourceLogs => $_getList(0);
}

class ExportLogsServiceResponse extends $pb.GeneratedMessage {
  factory ExportLogsServiceResponse({
    ExportLogsPartialSuccess? partialSuccess,
  }) {
    final result = create();
    if (partialSuccess != null) result.partialSuccess = partialSuccess;
    return result;
  }

  ExportLogsServiceResponse._();

  factory ExportLogsServiceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportLogsServiceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportLogsServiceResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.collector.logs.v1'),
      createEmptyInstance: create)
    ..aOM<ExportLogsPartialSuccess>(1, _omitFieldNames ? '' : 'partialSuccess',
        subBuilder: ExportLogsPartialSuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportLogsServiceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportLogsServiceResponse copyWith(
          void Function(ExportLogsServiceResponse) updates) =>
      super.copyWith((message) => updates(message as ExportLogsServiceResponse))
          as ExportLogsServiceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportLogsServiceResponse create() => ExportLogsServiceResponse._();
  @$core.override
  ExportLogsServiceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportLogsServiceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportLogsServiceResponse>(create);
  static ExportLogsServiceResponse? _defaultInstance;

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
  ExportLogsPartialSuccess get partialSuccess => $_getN(0);
  @$pb.TagNumber(1)
  set partialSuccess(ExportLogsPartialSuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPartialSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearPartialSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  ExportLogsPartialSuccess ensurePartialSuccess() => $_ensure(0);
}

class ExportLogsPartialSuccess extends $pb.GeneratedMessage {
  factory ExportLogsPartialSuccess({
    $fixnum.Int64? rejectedLogRecords,
    $core.String? errorMessage,
  }) {
    final result = create();
    if (rejectedLogRecords != null)
      result.rejectedLogRecords = rejectedLogRecords;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  ExportLogsPartialSuccess._();

  factory ExportLogsPartialSuccess.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportLogsPartialSuccess.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportLogsPartialSuccess',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.collector.logs.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'rejectedLogRecords')
    ..aOS(2, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportLogsPartialSuccess clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportLogsPartialSuccess copyWith(
          void Function(ExportLogsPartialSuccess) updates) =>
      super.copyWith((message) => updates(message as ExportLogsPartialSuccess))
          as ExportLogsPartialSuccess;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportLogsPartialSuccess create() => ExportLogsPartialSuccess._();
  @$core.override
  ExportLogsPartialSuccess createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportLogsPartialSuccess getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportLogsPartialSuccess>(create);
  static ExportLogsPartialSuccess? _defaultInstance;

  /// The number of rejected log records.
  ///
  /// A `rejected_signal` field holding a `0` value indicates that the
  /// request was fully accepted.
  @$pb.TagNumber(1)
  $fixnum.Int64 get rejectedLogRecords => $_getI64(0);
  @$pb.TagNumber(1)
  set rejectedLogRecords($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRejectedLogRecords() => $_has(0);
  @$pb.TagNumber(1)
  void clearRejectedLogRecords() => $_clearField(1);

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
