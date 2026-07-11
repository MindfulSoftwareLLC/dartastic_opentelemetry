// Licensed under the Apache License, Version 2.0
// Copyright 2026, Michael Bushe, All rights reserved.

import 'dart:convert';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show IdGenerator;
import 'package:protobuf/protobuf.dart';

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
/// This helper converts the proto3-JSON tree, hex-encoding every ID field
/// wherever it appears (spans, span links, log records, metric exemplars).
Object? otlpProto3JsonWithHexIds(GeneratedMessage request) =>
    _hexifyIds(request.toProto3Json());

const _idKeys = {'traceId', 'spanId', 'parentSpanId'};

Object? _hexifyIds(Object? node) {
  if (node is Map) {
    return <String, Object?>{
      for (final entry in node.entries)
        entry.key as String:
            _idKeys.contains(entry.key) && entry.value is String
                ? _base64ToHex(entry.value as String)
                : _hexifyIds(entry.value),
    };
  }
  if (node is List) {
    return <Object?>[for (final item in node) _hexifyIds(item)];
  }
  return node;
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
