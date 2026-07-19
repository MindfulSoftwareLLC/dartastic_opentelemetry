// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show IdGenerator;
import 'package:protobuf/protobuf.dart';

import '../../proto/logs/v1/logs.pb.dart' show SeverityNumber;
import '../../proto/metrics/v1/metrics.pb.dart' show AggregationTemporality;
import '../../proto/trace/v1/trace.pb.dart' show Span_SpanKind, Status_StatusCode;

/// OTLP/JSON encoding of an OTLP request message.
///
/// OTLP/JSON is proto3-JSON **with explicit deviations** — the one that bites
/// is ID encoding: the OTLP specification requires `traceId`, `spanId`, and
/// `parentSpanId` to be **hex-encoded** strings (case-insensitive), NOT the
/// proto3-JSON default base64 for `bytes` fields. See
/// opentelemetry-proto's JSON Protobuf Encoding notes.
///
/// `toProto3Json()` alone therefore produces payloads that strict OTLP
/// receivers reject — the OpenTelemetry Collector enforces hex from
/// contrib ~0.15x ("ID.UnmarshalJSONIter: length mismatch", HTTP 400); older
/// collectors happened to tolerate base64, which is how this survived in the
/// wild until the first strict endpoint (Dartastic Cloud, 2026-07-10).
///
/// The second deviation, same origin story: the OTLP spec requires enum
/// fields to be encoded as their **integer** values, while `toProto3Json()`
/// emits proto3-JSON's default enum **names** (`"SPAN_KIND_SERVER"`).
/// Lenient receivers accept both; the spec (and the engine wire-parity
/// harness in dartastic-pro#140, which found this) says integers.
///
/// This helper converts the proto3-JSON tree, hex-encoding every ID field
/// wherever it appears (spans, span links, log records, metric exemplars)
/// and int-encoding every enum field (span `kind`, status `code`, log
/// `severityNumber`, metric `aggregationTemporality`).
Object? otlpProto3JsonWithHexIds(GeneratedMessage request) =>
    _fixupOtlpJson(request.toProto3Json());

const _idKeys = {'traceId', 'spanId', 'parentSpanId'};

/// Enum fields keyed by their JSON field name, each with its own
/// name→int table built from the generated protos (drift-proof) and
/// guarded by the enum's name prefix so an attribute value that merely
/// resembles an enum name can never be corrupted (attribute values live
/// under `stringValue` keys, never these).
final Map<String, Map<String, int>> _enumFields = {
  'kind': {for (final v in Span_SpanKind.values) v.name: v.value},
  'code': {for (final v in Status_StatusCode.values) v.name: v.value},
  'severityNumber': {for (final v in SeverityNumber.values) v.name: v.value},
  'aggregationTemporality': {
    for (final v in AggregationTemporality.values) v.name: v.value,
  },
};

Object? _fixupOtlpJson(Object? node) {
  if (node is Map) {
    return <String, Object?>{
      for (final entry in node.entries)
        entry.key as String: _fixupValue(entry.key as String, entry.value),
    };
  }
  if (node is List) {
    return <Object?>[for (final item in node) _fixupOtlpJson(item)];
  }
  return node;
}

Object? _fixupValue(String key, Object? value) {
  if (_idKeys.contains(key) && value is String) {
    return _base64ToHex(value);
  }
  final enumTable = _enumFields[key];
  if (enumTable != null && value is String) {
    // Defensive like _base64ToHex: an unknown name passes through
    // unchanged (never corrupt a payload we don't understand).
    return enumTable[value] ?? value;
  }
  return _fixupOtlpJson(value);
}

/// Base64 → lowercase hex, via the same codec that formats
/// `TraceId.hexString`/`SpanId.hexString`. Defensive: a value that doesn't
/// parse as base64 is returned unchanged (never corrupt a payload we don't
/// understand).
String _base64ToHex(String b64) {
  try {
    return IdGenerator.bytesToHex(base64.decode(b64));
  } on FormatException {
    return b64;
  }
}
