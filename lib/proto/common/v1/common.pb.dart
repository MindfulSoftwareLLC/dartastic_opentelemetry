// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/common/v1/common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

enum AnyValue_Value {
  stringValue,
  boolValue,
  intValue,
  doubleValue,
  arrayValue,
  kvlistValue,
  bytesValue,
  stringValueStrindex,
  notSet
}

/// Represents any type of attribute value. AnyValue may contain a
/// primitive value such as a string or integer or it may contain an arbitrary nested
/// object containing arrays, key-value lists and primitives.
class AnyValue extends $pb.GeneratedMessage {
  factory AnyValue({
    $core.String? stringValue,
    $core.bool? boolValue,
    $fixnum.Int64? intValue,
    $core.double? doubleValue,
    ArrayValue? arrayValue,
    KeyValueList? kvlistValue,
    $core.List<$core.int>? bytesValue,
    $core.int? stringValueStrindex,
  }) {
    final result = create();
    if (stringValue != null) result.stringValue = stringValue;
    if (boolValue != null) result.boolValue = boolValue;
    if (intValue != null) result.intValue = intValue;
    if (doubleValue != null) result.doubleValue = doubleValue;
    if (arrayValue != null) result.arrayValue = arrayValue;
    if (kvlistValue != null) result.kvlistValue = kvlistValue;
    if (bytesValue != null) result.bytesValue = bytesValue;
    if (stringValueStrindex != null)
      result.stringValueStrindex = stringValueStrindex;
    return result;
  }

  AnyValue._();

  factory AnyValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AnyValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, AnyValue_Value> _AnyValue_ValueByTag = {
    1: AnyValue_Value.stringValue,
    2: AnyValue_Value.boolValue,
    3: AnyValue_Value.intValue,
    4: AnyValue_Value.doubleValue,
    5: AnyValue_Value.arrayValue,
    6: AnyValue_Value.kvlistValue,
    7: AnyValue_Value.bytesValue,
    8: AnyValue_Value.stringValueStrindex,
    0: AnyValue_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnyValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.common.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8])
    ..aOS(1, _omitFieldNames ? '' : 'stringValue')
    ..aOB(2, _omitFieldNames ? '' : 'boolValue')
    ..aInt64(3, _omitFieldNames ? '' : 'intValue')
    ..aD(4, _omitFieldNames ? '' : 'doubleValue')
    ..aOM<ArrayValue>(5, _omitFieldNames ? '' : 'arrayValue',
        subBuilder: ArrayValue.create)
    ..aOM<KeyValueList>(6, _omitFieldNames ? '' : 'kvlistValue',
        subBuilder: KeyValueList.create)
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'bytesValue', $pb.PbFieldType.OY)
    ..aI(8, _omitFieldNames ? '' : 'stringValueStrindex')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnyValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnyValue copyWith(void Function(AnyValue) updates) =>
      super.copyWith((message) => updates(message as AnyValue)) as AnyValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnyValue create() => AnyValue._();
  @$core.override
  AnyValue createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AnyValue getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AnyValue>(create);
  static AnyValue? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  AnyValue_Value whichValue() => _AnyValue_ValueByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  void clearValue() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get stringValue => $_getSZ(0);
  @$pb.TagNumber(1)
  set stringValue($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStringValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearStringValue() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get boolValue => $_getBF(1);
  @$pb.TagNumber(2)
  set boolValue($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBoolValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearBoolValue() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get intValue => $_getI64(2);
  @$pb.TagNumber(3)
  set intValue($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIntValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearIntValue() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get doubleValue => $_getN(3);
  @$pb.TagNumber(4)
  set doubleValue($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDoubleValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearDoubleValue() => $_clearField(4);

  @$pb.TagNumber(5)
  ArrayValue get arrayValue => $_getN(4);
  @$pb.TagNumber(5)
  set arrayValue(ArrayValue value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasArrayValue() => $_has(4);
  @$pb.TagNumber(5)
  void clearArrayValue() => $_clearField(5);
  @$pb.TagNumber(5)
  ArrayValue ensureArrayValue() => $_ensure(4);

  @$pb.TagNumber(6)
  KeyValueList get kvlistValue => $_getN(5);
  @$pb.TagNumber(6)
  set kvlistValue(KeyValueList value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasKvlistValue() => $_has(5);
  @$pb.TagNumber(6)
  void clearKvlistValue() => $_clearField(6);
  @$pb.TagNumber(6)
  KeyValueList ensureKvlistValue() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.List<$core.int> get bytesValue => $_getN(6);
  @$pb.TagNumber(7)
  set bytesValue($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBytesValue() => $_has(6);
  @$pb.TagNumber(7)
  void clearBytesValue() => $_clearField(7);

  /// Reference to the string value in ProfilesDictionary.string_table.
  ///
  /// Note: This is currently used exclusively in the Profiling signal.
  /// Implementers of OTLP receivers for signals other than Profiling should
  /// treat the presence of this value as a non-fatal issue.
  /// Log an error or warning indicating an unexpected field intended for the
  /// Profiling signal and process the data as if this value were absent or
  /// empty, ignoring its semantic content for the non-Profiling signal.
  ///
  /// Status: [Alpha]
  @$pb.TagNumber(8)
  $core.int get stringValueStrindex => $_getIZ(7);
  @$pb.TagNumber(8)
  set stringValueStrindex($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStringValueStrindex() => $_has(7);
  @$pb.TagNumber(8)
  void clearStringValueStrindex() => $_clearField(8);
}

/// ArrayValue is a list of AnyValue messages. We need ArrayValue as a message
/// since oneof in AnyValue does not allow repeated fields.
class ArrayValue extends $pb.GeneratedMessage {
  factory ArrayValue({
    $core.Iterable<AnyValue>? values,
  }) {
    final result = create();
    if (values != null) result.values.addAll(values);
    return result;
  }

  ArrayValue._();

  factory ArrayValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ArrayValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArrayValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.common.v1'),
      createEmptyInstance: create)
    ..pPM<AnyValue>(1, _omitFieldNames ? '' : 'values',
        subBuilder: AnyValue.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArrayValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArrayValue copyWith(void Function(ArrayValue) updates) =>
      super.copyWith((message) => updates(message as ArrayValue)) as ArrayValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ArrayValue create() => ArrayValue._();
  @$core.override
  ArrayValue createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ArrayValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArrayValue>(create);
  static ArrayValue? _defaultInstance;

  /// Array of values. The array may be empty (contain 0 elements).
  @$pb.TagNumber(1)
  $pb.PbList<AnyValue> get values => $_getList(0);
}

/// KeyValueList is a list of KeyValue messages. We need KeyValueList as a message
/// since `oneof` in AnyValue does not allow repeated fields. Everywhere else where we need
/// a list of KeyValue messages (e.g. in Span) we use `repeated KeyValue` directly to
/// avoid unnecessary extra wrapping (which slows down the protocol). The 2 approaches
/// are semantically equivalent.
class KeyValueList extends $pb.GeneratedMessage {
  factory KeyValueList({
    $core.Iterable<KeyValue>? values,
  }) {
    final result = create();
    if (values != null) result.values.addAll(values);
    return result;
  }

  KeyValueList._();

  factory KeyValueList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyValueList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyValueList',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.common.v1'),
      createEmptyInstance: create)
    ..pPM<KeyValue>(1, _omitFieldNames ? '' : 'values',
        subBuilder: KeyValue.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyValueList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyValueList copyWith(void Function(KeyValueList) updates) =>
      super.copyWith((message) => updates(message as KeyValueList))
          as KeyValueList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyValueList create() => KeyValueList._();
  @$core.override
  KeyValueList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyValueList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeyValueList>(create);
  static KeyValueList? _defaultInstance;

  /// A collection of key/value pairs of key-value pairs. The list may be empty (may
  /// contain 0 elements).
  ///
  /// The keys MUST be unique (it is not allowed to have more than one
  /// value with the same key).
  /// The behavior of software that receives duplicated keys can be unpredictable.
  @$pb.TagNumber(1)
  $pb.PbList<KeyValue> get values => $_getList(0);
}

/// Represents a key-value pair that is used to store Span attributes, Link
/// attributes, etc.
class KeyValue extends $pb.GeneratedMessage {
  factory KeyValue({
    $core.String? key,
    AnyValue? value,
    $core.int? keyStrindex,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    if (keyStrindex != null) result.keyStrindex = keyStrindex;
    return result;
  }

  KeyValue._();

  factory KeyValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.common.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOM<AnyValue>(2, _omitFieldNames ? '' : 'value',
        subBuilder: AnyValue.create)
    ..aI(3, _omitFieldNames ? '' : 'keyStrindex')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyValue copyWith(void Function(KeyValue) updates) =>
      super.copyWith((message) => updates(message as KeyValue)) as KeyValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyValue create() => KeyValue._();
  @$core.override
  KeyValue createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyValue getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KeyValue>(create);
  static KeyValue? _defaultInstance;

  /// The key name of the pair.
  /// key_strindex MUST NOT be set if key is used.
  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  /// The value of the pair.
  @$pb.TagNumber(2)
  AnyValue get value => $_getN(1);
  @$pb.TagNumber(2)
  set value(AnyValue value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
  @$pb.TagNumber(2)
  AnyValue ensureValue() => $_ensure(1);

  /// Reference to the string key in ProfilesDictionary.string_table.
  /// key MUST NOT be set if key_strindex is used.
  ///
  /// Note: This is currently used exclusively in the Profiling signal.
  /// Implementers of OTLP receivers for signals other than Profiling should
  /// treat the presence of this key as a non-fatal issue.
  /// Log an error or warning indicating an unexpected field intended for the
  /// Profiling signal and process the data as if this value were absent or
  /// empty, ignoring its semantic content for the non-Profiling signal.
  ///
  /// Status: [Alpha]
  @$pb.TagNumber(3)
  $core.int get keyStrindex => $_getIZ(2);
  @$pb.TagNumber(3)
  set keyStrindex($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKeyStrindex() => $_has(2);
  @$pb.TagNumber(3)
  void clearKeyStrindex() => $_clearField(3);
}

/// InstrumentationScope is a message representing the instrumentation scope information
/// such as the fully qualified name and version.
class InstrumentationScope extends $pb.GeneratedMessage {
  factory InstrumentationScope({
    $core.String? name,
    $core.String? version,
    $core.Iterable<KeyValue>? attributes,
    $core.int? droppedAttributesCount,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (version != null) result.version = version;
    if (attributes != null) result.attributes.addAll(attributes);
    if (droppedAttributesCount != null)
      result.droppedAttributesCount = droppedAttributesCount;
    return result;
  }

  InstrumentationScope._();

  factory InstrumentationScope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InstrumentationScope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InstrumentationScope',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.common.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..pPM<KeyValue>(3, _omitFieldNames ? '' : 'attributes',
        subBuilder: KeyValue.create)
    ..aI(4, _omitFieldNames ? '' : 'droppedAttributesCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InstrumentationScope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InstrumentationScope copyWith(void Function(InstrumentationScope) updates) =>
      super.copyWith((message) => updates(message as InstrumentationScope))
          as InstrumentationScope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InstrumentationScope create() => InstrumentationScope._();
  @$core.override
  InstrumentationScope createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InstrumentationScope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InstrumentationScope>(create);
  static InstrumentationScope? _defaultInstance;

  /// A name denoting the Instrumentation scope.
  /// An empty instrumentation scope name means the name is unknown.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// Defines the version of the instrumentation scope.
  /// An empty instrumentation scope version means the version is unknown.
  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);

  /// Additional attributes that describe the scope. [Optional].
  /// Attribute keys MUST be unique (it is not allowed to have more than one
  /// attribute with the same key).
  /// The behavior of software that receives duplicated keys can be unpredictable.
  @$pb.TagNumber(3)
  $pb.PbList<KeyValue> get attributes => $_getList(2);

  /// The number of attributes that were discarded. Attributes
  /// can be discarded because their keys are too long or because there are too many
  /// attributes. If this value is 0, then no attributes were dropped.
  @$pb.TagNumber(4)
  $core.int get droppedAttributesCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set droppedAttributesCount($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDroppedAttributesCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearDroppedAttributesCount() => $_clearField(4);
}

/// A reference to an Entity.
/// Entity represents an object of interest associated with produced telemetry: e.g spans, metrics, profiles, or logs.
///
/// Status: [Development]
class EntityRef extends $pb.GeneratedMessage {
  factory EntityRef({
    $core.String? schemaUrl,
    $core.String? type,
    $core.Iterable<$core.String>? idKeys,
    $core.Iterable<$core.String>? descriptionKeys,
  }) {
    final result = create();
    if (schemaUrl != null) result.schemaUrl = schemaUrl;
    if (type != null) result.type = type;
    if (idKeys != null) result.idKeys.addAll(idKeys);
    if (descriptionKeys != null) result.descriptionKeys.addAll(descriptionKeys);
    return result;
  }

  EntityRef._();

  factory EntityRef.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EntityRef.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EntityRef',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.common.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'schemaUrl')
    ..aOS(2, _omitFieldNames ? '' : 'type')
    ..pPS(3, _omitFieldNames ? '' : 'idKeys')
    ..pPS(4, _omitFieldNames ? '' : 'descriptionKeys')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EntityRef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EntityRef copyWith(void Function(EntityRef) updates) =>
      super.copyWith((message) => updates(message as EntityRef)) as EntityRef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EntityRef create() => EntityRef._();
  @$core.override
  EntityRef createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EntityRef getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EntityRef>(create);
  static EntityRef? _defaultInstance;

  /// The Schema URL, if known. This is the identifier of the Schema that the entity data
  /// is recorded in. To learn more about Schema URL see
  /// https://opentelemetry.io/docs/specs/otel/schemas/#schema-url
  ///
  /// This schema_url applies to the data in this message and to the Resource attributes
  /// referenced by id_keys and description_keys.
  /// TODO: discuss if we are happy with this somewhat complicated definition of what
  /// the schema_url applies to.
  ///
  /// This field obsoletes the schema_url field in ResourceMetrics/ResourceSpans/ResourceLogs.
  @$pb.TagNumber(1)
  $core.String get schemaUrl => $_getSZ(0);
  @$pb.TagNumber(1)
  set schemaUrl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchemaUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchemaUrl() => $_clearField(1);

  /// Defines the type of the entity. MUST not change during the lifetime of the entity.
  /// For example: "service" or "host". This field is required and MUST not be empty
  /// for valid entities.
  @$pb.TagNumber(2)
  $core.String get type => $_getSZ(1);
  @$pb.TagNumber(2)
  set type($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  /// Attribute Keys that identify the entity.
  /// MUST not change during the lifetime of the entity. The Id must contain at least one attribute.
  /// These keys MUST exist in the containing {message}.attributes.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get idKeys => $_getList(2);

  /// Descriptive (non-identifying) attribute keys of the entity.
  /// MAY change over the lifetime of the entity. MAY be empty.
  /// These attribute keys are not part of entity's identity.
  /// These keys MUST exist in the containing {message}.attributes.
  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get descriptionKeys => $_getList(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
