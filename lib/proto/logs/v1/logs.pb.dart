// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/logs/v1/logs.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../../common/v1/common.pb.dart' as $1;
import '../../resource/v1/resource.pb.dart' as $0;
import 'logs.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'logs.pbenum.dart';

/// LogsData represents the logs data that can be stored in a persistent storage,
/// OR can be embedded by other protocols that transfer OTLP logs data but do not
/// implement the OTLP protocol.
///
/// The main difference between this message and collector protocol is that
/// in this message there will not be any "control" or "metadata" specific to
/// OTLP protocol.
///
/// When new fields are added into this message, the OTLP request MUST be updated
/// as well.
class LogsData extends $pb.GeneratedMessage {
  factory LogsData({
    $core.Iterable<ResourceLogs>? resourceLogs,
  }) {
    final result = create();
    if (resourceLogs != null) result.resourceLogs.addAll(resourceLogs);
    return result;
  }

  LogsData._();

  factory LogsData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LogsData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogsData',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.logs.v1'),
      createEmptyInstance: create)
    ..pPM<ResourceLogs>(1, _omitFieldNames ? '' : 'resourceLogs',
        subBuilder: ResourceLogs.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogsData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogsData copyWith(void Function(LogsData) updates) =>
      super.copyWith((message) => updates(message as LogsData)) as LogsData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogsData create() => LogsData._();
  @$core.override
  LogsData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LogsData getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogsData>(create);
  static LogsData? _defaultInstance;

  /// An array of ResourceLogs.
  /// For data coming from a single resource this array will typically contain
  /// one element. Intermediary nodes that receive data from multiple origins
  /// typically batch the data before forwarding further and in that case this
  /// array will contain multiple elements.
  @$pb.TagNumber(1)
  $pb.PbList<ResourceLogs> get resourceLogs => $_getList(0);
}

/// A collection of ScopeLogs from a Resource.
class ResourceLogs extends $pb.GeneratedMessage {
  factory ResourceLogs({
    $0.Resource? resource,
    $core.Iterable<ScopeLogs>? scopeLogs,
    $core.String? schemaUrl,
  }) {
    final result = create();
    if (resource != null) result.resource = resource;
    if (scopeLogs != null) result.scopeLogs.addAll(scopeLogs);
    if (schemaUrl != null) result.schemaUrl = schemaUrl;
    return result;
  }

  ResourceLogs._();

  factory ResourceLogs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResourceLogs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResourceLogs',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.logs.v1'),
      createEmptyInstance: create)
    ..aOM<$0.Resource>(1, _omitFieldNames ? '' : 'resource',
        subBuilder: $0.Resource.create)
    ..pPM<ScopeLogs>(2, _omitFieldNames ? '' : 'scopeLogs',
        subBuilder: ScopeLogs.create)
    ..aOS(3, _omitFieldNames ? '' : 'schemaUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResourceLogs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResourceLogs copyWith(void Function(ResourceLogs) updates) =>
      super.copyWith((message) => updates(message as ResourceLogs))
          as ResourceLogs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResourceLogs create() => ResourceLogs._();
  @$core.override
  ResourceLogs createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResourceLogs getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResourceLogs>(create);
  static ResourceLogs? _defaultInstance;

  /// The resource for the logs in this message.
  /// If this field is not set then resource info is unknown.
  @$pb.TagNumber(1)
  $0.Resource get resource => $_getN(0);
  @$pb.TagNumber(1)
  set resource($0.Resource value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasResource() => $_has(0);
  @$pb.TagNumber(1)
  void clearResource() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.Resource ensureResource() => $_ensure(0);

  /// A list of ScopeLogs that originate from a resource.
  @$pb.TagNumber(2)
  $pb.PbList<ScopeLogs> get scopeLogs => $_getList(1);

  /// The Schema URL, if known. This is the identifier of the Schema that the resource data
  /// is recorded in. To learn more about Schema URL see
  /// https://opentelemetry.io/docs/specs/otel/schemas/#schema-url
  /// This schema_url applies to the data in the "resource" field. It does not apply
  /// to the data in the "scope_logs" field which have their own schema_url field.
  @$pb.TagNumber(3)
  $core.String get schemaUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set schemaUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSchemaUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearSchemaUrl() => $_clearField(3);
}

/// A collection of Logs produced by a Scope.
class ScopeLogs extends $pb.GeneratedMessage {
  factory ScopeLogs({
    $1.InstrumentationScope? scope,
    $core.Iterable<LogRecord>? logRecords,
    $core.String? schemaUrl,
  }) {
    final result = create();
    if (scope != null) result.scope = scope;
    if (logRecords != null) result.logRecords.addAll(logRecords);
    if (schemaUrl != null) result.schemaUrl = schemaUrl;
    return result;
  }

  ScopeLogs._();

  factory ScopeLogs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScopeLogs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScopeLogs',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.logs.v1'),
      createEmptyInstance: create)
    ..aOM<$1.InstrumentationScope>(1, _omitFieldNames ? '' : 'scope',
        subBuilder: $1.InstrumentationScope.create)
    ..pPM<LogRecord>(2, _omitFieldNames ? '' : 'logRecords',
        subBuilder: LogRecord.create)
    ..aOS(3, _omitFieldNames ? '' : 'schemaUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScopeLogs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScopeLogs copyWith(void Function(ScopeLogs) updates) =>
      super.copyWith((message) => updates(message as ScopeLogs)) as ScopeLogs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScopeLogs create() => ScopeLogs._();
  @$core.override
  ScopeLogs createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScopeLogs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ScopeLogs>(create);
  static ScopeLogs? _defaultInstance;

  /// The instrumentation scope information for the logs in this message.
  /// Semantically when InstrumentationScope isn't set, it is equivalent with
  /// an empty instrumentation scope name (unknown).
  @$pb.TagNumber(1)
  $1.InstrumentationScope get scope => $_getN(0);
  @$pb.TagNumber(1)
  set scope($1.InstrumentationScope value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasScope() => $_has(0);
  @$pb.TagNumber(1)
  void clearScope() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.InstrumentationScope ensureScope() => $_ensure(0);

  /// A list of log records.
  @$pb.TagNumber(2)
  $pb.PbList<LogRecord> get logRecords => $_getList(1);

  /// The Schema URL, if known. This is the identifier of the Schema that the log data
  /// is recorded in. To learn more about Schema URL see
  /// https://opentelemetry.io/docs/specs/otel/schemas/#schema-url
  /// This schema_url applies to all logs in the "logs" field.
  @$pb.TagNumber(3)
  $core.String get schemaUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set schemaUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSchemaUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearSchemaUrl() => $_clearField(3);
}

/// A log record according to OpenTelemetry Log Data Model:
/// https://github.com/open-telemetry/oteps/blob/main/text/logs/0097-log-data-model.md
class LogRecord extends $pb.GeneratedMessage {
  factory LogRecord({
    $fixnum.Int64? timeUnixNano,
    SeverityNumber? severityNumber,
    $core.String? severityText,
    $1.AnyValue? body,
    $core.Iterable<$1.KeyValue>? attributes,
    $core.int? droppedAttributesCount,
    $core.int? flags,
    $core.List<$core.int>? traceId,
    $core.List<$core.int>? spanId,
    $fixnum.Int64? observedTimeUnixNano,
  }) {
    final result = create();
    if (timeUnixNano != null) result.timeUnixNano = timeUnixNano;
    if (severityNumber != null) result.severityNumber = severityNumber;
    if (severityText != null) result.severityText = severityText;
    if (body != null) result.body = body;
    if (attributes != null) result.attributes.addAll(attributes);
    if (droppedAttributesCount != null)
      result.droppedAttributesCount = droppedAttributesCount;
    if (flags != null) result.flags = flags;
    if (traceId != null) result.traceId = traceId;
    if (spanId != null) result.spanId = spanId;
    if (observedTimeUnixNano != null)
      result.observedTimeUnixNano = observedTimeUnixNano;
    return result;
  }

  LogRecord._();

  factory LogRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LogRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogRecord',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.logs.v1'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'timeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<SeverityNumber>(2, _omitFieldNames ? '' : 'severityNumber',
        enumValues: SeverityNumber.values)
    ..aOS(3, _omitFieldNames ? '' : 'severityText')
    ..aOM<$1.AnyValue>(5, _omitFieldNames ? '' : 'body',
        subBuilder: $1.AnyValue.create)
    ..pPM<$1.KeyValue>(6, _omitFieldNames ? '' : 'attributes',
        subBuilder: $1.KeyValue.create)
    ..aI(7, _omitFieldNames ? '' : 'droppedAttributesCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'flags', fieldType: $pb.PbFieldType.OF3)
    ..a<$core.List<$core.int>>(
        9, _omitFieldNames ? '' : 'traceId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        10, _omitFieldNames ? '' : 'spanId', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(
        11, _omitFieldNames ? '' : 'observedTimeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogRecord copyWith(void Function(LogRecord) updates) =>
      super.copyWith((message) => updates(message as LogRecord)) as LogRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogRecord create() => LogRecord._();
  @$core.override
  LogRecord createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LogRecord getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogRecord>(create);
  static LogRecord? _defaultInstance;

  /// time_unix_nano is the time when the event occurred.
  /// Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January 1970.
  /// Value of 0 indicates unknown or missing timestamp.
  @$pb.TagNumber(1)
  $fixnum.Int64 get timeUnixNano => $_getI64(0);
  @$pb.TagNumber(1)
  set timeUnixNano($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTimeUnixNano() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimeUnixNano() => $_clearField(1);

  /// Numerical value of the severity, normalized to values described in Log Data Model.
  /// [Optional].
  @$pb.TagNumber(2)
  SeverityNumber get severityNumber => $_getN(1);
  @$pb.TagNumber(2)
  set severityNumber(SeverityNumber value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSeverityNumber() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeverityNumber() => $_clearField(2);

  /// The severity text (also known as log level). The original string representation as
  /// it is known at the source. [Optional].
  @$pb.TagNumber(3)
  $core.String get severityText => $_getSZ(2);
  @$pb.TagNumber(3)
  set severityText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSeverityText() => $_has(2);
  @$pb.TagNumber(3)
  void clearSeverityText() => $_clearField(3);

  /// A value containing the body of the log record. Can be for example a human-readable
  /// string message (including multi-line) describing the event in a free form or it can
  /// be a structured data composed of arrays and maps of other values. [Optional].
  @$pb.TagNumber(5)
  $1.AnyValue get body => $_getN(3);
  @$pb.TagNumber(5)
  set body($1.AnyValue value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasBody() => $_has(3);
  @$pb.TagNumber(5)
  void clearBody() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.AnyValue ensureBody() => $_ensure(3);

  /// Additional attributes that describe the specific event occurrence. [Optional].
  /// Attribute keys MUST be unique (it is not allowed to have more than one
  /// attribute with the same key).
  @$pb.TagNumber(6)
  $pb.PbList<$1.KeyValue> get attributes => $_getList(4);

  @$pb.TagNumber(7)
  $core.int get droppedAttributesCount => $_getIZ(5);
  @$pb.TagNumber(7)
  set droppedAttributesCount($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(7)
  $core.bool hasDroppedAttributesCount() => $_has(5);
  @$pb.TagNumber(7)
  void clearDroppedAttributesCount() => $_clearField(7);

  /// Flags, a bit field. 8 least significant bits are the trace flags as
  /// defined in W3C Trace Context specification. 24 most significant bits are reserved
  /// and must be set to 0. Readers must not assume that 24 most significant bits
  /// will be zero and must correctly mask the bits when reading 8-bit trace flag (use
  /// flags & LOG_RECORD_FLAGS_TRACE_FLAGS_MASK). [Optional].
  @$pb.TagNumber(8)
  $core.int get flags => $_getIZ(6);
  @$pb.TagNumber(8)
  set flags($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(8)
  $core.bool hasFlags() => $_has(6);
  @$pb.TagNumber(8)
  void clearFlags() => $_clearField(8);

  /// A unique identifier for a trace. All logs from the same trace share
  /// the same `trace_id`. The ID is a 16-byte array. An ID with all zeroes OR
  /// of length other than 16 bytes is considered invalid (empty string in OTLP/JSON
  /// is zero-length and thus is also invalid).
  ///
  /// This field is optional.
  ///
  /// The receivers SHOULD assume that the log record is not associated with a
  /// trace if any of the following is true:
  ///   - the field is not present,
  ///   - the field contains an invalid value.
  @$pb.TagNumber(9)
  $core.List<$core.int> get traceId => $_getN(7);
  @$pb.TagNumber(9)
  set traceId($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(9)
  $core.bool hasTraceId() => $_has(7);
  @$pb.TagNumber(9)
  void clearTraceId() => $_clearField(9);

  /// A unique identifier for a span within a trace, assigned when the span
  /// is created. The ID is an 8-byte array. An ID with all zeroes OR of length
  /// other than 8 bytes is considered invalid (empty string in OTLP/JSON
  /// is zero-length and thus is also invalid).
  ///
  /// This field is optional. If the sender specifies a valid span_id then it SHOULD also
  /// specify a valid trace_id.
  ///
  /// The receivers SHOULD assume that the log record is not associated with a
  /// span if any of the following is true:
  ///   - the field is not present,
  ///   - the field contains an invalid value.
  @$pb.TagNumber(10)
  $core.List<$core.int> get spanId => $_getN(8);
  @$pb.TagNumber(10)
  set spanId($core.List<$core.int> value) => $_setBytes(8, value);
  @$pb.TagNumber(10)
  $core.bool hasSpanId() => $_has(8);
  @$pb.TagNumber(10)
  void clearSpanId() => $_clearField(10);

  /// Time when the event was observed by the collection system.
  /// For events that originate in OpenTelemetry (e.g. using OpenTelemetry Logging SDK)
  /// this timestamp is typically set at the generation time and is equal to Timestamp.
  /// For events originating externally and collected by OpenTelemetry (e.g. using
  /// Collector) this is the time when OpenTelemetry's code observed the event measured
  /// by the clock of the OpenTelemetry code. This field MUST be set once the event is
  /// observed by OpenTelemetry.
  ///
  /// For converting OpenTelemetry log data to formats that support only one timestamp or
  /// when receiving OpenTelemetry log data by recipients that support only one timestamp
  /// internally the following logic is recommended:
  ///   - Use time_unix_nano if it is present, otherwise use observed_time_unix_nano.
  ///
  /// Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January 1970.
  /// Value of 0 indicates unknown or missing timestamp.
  @$pb.TagNumber(11)
  $fixnum.Int64 get observedTimeUnixNano => $_getI64(9);
  @$pb.TagNumber(11)
  set observedTimeUnixNano($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(11)
  $core.bool hasObservedTimeUnixNano() => $_has(9);
  @$pb.TagNumber(11)
  void clearObservedTimeUnixNano() => $_clearField(11);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
