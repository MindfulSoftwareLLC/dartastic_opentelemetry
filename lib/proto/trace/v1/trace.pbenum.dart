// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/trace/v1/trace.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// SpanFlags represents constants used to interpret the
/// Span.flags field, which is protobuf 'fixed32' type and is to
/// be used as bit-fields. Each non-zero value defined in this enum is
/// a bit-mask.  To extract the bit-field, for example, use an
/// expression like:
///
///   (span.flags & SPAN_FLAGS_TRACE_FLAGS_MASK)
///
/// See https://www.w3.org/TR/trace-context-2/#trace-flags for the flag definitions.
///
/// Note that Span flags were introduced in version 1.1 of the
/// OpenTelemetry protocol.  Older Span producers do not set this
/// field, consequently consumers should not rely on the absence of a
/// particular flag bit to indicate the presence of a particular feature.
class SpanFlags extends $pb.ProtobufEnum {
  /// The zero value for the enum. Should not be used for comparisons.
  /// Instead use bitwise "and" with the appropriate mask as shown above.
  static const SpanFlags SPAN_FLAGS_DO_NOT_USE =
      SpanFlags._(0, _omitEnumNames ? '' : 'SPAN_FLAGS_DO_NOT_USE');

  /// Bits 0-7 are used for trace flags.
  static const SpanFlags SPAN_FLAGS_TRACE_FLAGS_MASK =
      SpanFlags._(255, _omitEnumNames ? '' : 'SPAN_FLAGS_TRACE_FLAGS_MASK');

  static const $core.List<SpanFlags> values = <SpanFlags>[
    SPAN_FLAGS_DO_NOT_USE,
    SPAN_FLAGS_TRACE_FLAGS_MASK,
  ];

  static final $core.Map<$core.int, SpanFlags> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static SpanFlags? valueOf($core.int value) => _byValue[value];

  const SpanFlags._(super.value, super.name);
}

/// SpanKind is the type of span. Can be used to specify additional relationships between spans
/// in addition to a parent/child relationship.
class Span_SpanKind extends $pb.ProtobufEnum {
  /// Unspecified. Do NOT use as default.
  /// Implementations MAY assume SpanKind to be INTERNAL when receiving UNSPECIFIED.
  static const Span_SpanKind SPAN_KIND_UNSPECIFIED =
      Span_SpanKind._(0, _omitEnumNames ? '' : 'SPAN_KIND_UNSPECIFIED');

  /// Indicates that the span represents an internal operation within an application,
  /// as opposed to an operation happening at the boundaries. Default value.
  static const Span_SpanKind SPAN_KIND_INTERNAL =
      Span_SpanKind._(1, _omitEnumNames ? '' : 'SPAN_KIND_INTERNAL');

  /// Indicates that the span covers server-side handling of an RPC or other
  /// remote network request.
  static const Span_SpanKind SPAN_KIND_SERVER =
      Span_SpanKind._(2, _omitEnumNames ? '' : 'SPAN_KIND_SERVER');

  /// Indicates that the span describes a request to some remote service.
  static const Span_SpanKind SPAN_KIND_CLIENT =
      Span_SpanKind._(3, _omitEnumNames ? '' : 'SPAN_KIND_CLIENT');

  /// Indicates that the span describes a producer sending a message to a broker.
  /// Unlike CLIENT and SERVER, there is often no direct critical path latency relationship
  /// between producer and consumer spans. A PRODUCER span ends when the message was accepted
  /// by the broker while the logical processing of the message might span a much longer time.
  static const Span_SpanKind SPAN_KIND_PRODUCER =
      Span_SpanKind._(4, _omitEnumNames ? '' : 'SPAN_KIND_PRODUCER');

  /// Indicates that the span describes consumer receiving a message from a broker.
  /// Like the PRODUCER kind, there is often no direct critical path latency relationship
  /// between producer and consumer spans.
  static const Span_SpanKind SPAN_KIND_CONSUMER =
      Span_SpanKind._(5, _omitEnumNames ? '' : 'SPAN_KIND_CONSUMER');

  static const $core.List<Span_SpanKind> values = <Span_SpanKind>[
    SPAN_KIND_UNSPECIFIED,
    SPAN_KIND_INTERNAL,
    SPAN_KIND_SERVER,
    SPAN_KIND_CLIENT,
    SPAN_KIND_PRODUCER,
    SPAN_KIND_CONSUMER,
  ];

  static final $core.List<Span_SpanKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static Span_SpanKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Span_SpanKind._(super.value, super.name);
}

/// For the semantics of status codes see
/// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#set-status
class Status_StatusCode extends $pb.ProtobufEnum {
  /// The default status.
  static const Status_StatusCode STATUS_CODE_UNSET =
      Status_StatusCode._(0, _omitEnumNames ? '' : 'STATUS_CODE_UNSET');

  /// The Span has been validated by an Application developer or Operator to
  /// have completed successfully.
  static const Status_StatusCode STATUS_CODE_OK =
      Status_StatusCode._(1, _omitEnumNames ? '' : 'STATUS_CODE_OK');

  /// The Span contains an error.
  static const Status_StatusCode STATUS_CODE_ERROR =
      Status_StatusCode._(2, _omitEnumNames ? '' : 'STATUS_CODE_ERROR');

  static const $core.List<Status_StatusCode> values = <Status_StatusCode>[
    STATUS_CODE_UNSET,
    STATUS_CODE_OK,
    STATUS_CODE_ERROR,
  ];

  static final $core.List<Status_StatusCode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Status_StatusCode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Status_StatusCode._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
