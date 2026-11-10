// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:fixnum/fixnum.dart';

import '../../proto/common/v1/common.pb.dart' as proto;

/// Encodes an API value without losing its OTLP type or collection structure.
///
/// Depth truncation is reported at most once per call.
proto.AnyValue otlpAnyValue(AnyValue value) =>
    _AnyValueEncoder().encode(value, 0);

class _AnyValueEncoder {
  bool _depthReported = false;

  proto.AnyValue encode(AnyValue value, int depth) {
    // Match the API conversion safeguard, including values assembled directly
    // from AnyValue collections, which bypass fromObject's depth check.
    if (depth >= 32 && value is! AnyValueNull) {
      if (!_depthReported) {
        _depthReported = true;
        OTelErrorHandling.report(ArgumentError(
            'AnyValue export nesting exceeds the maximum depth of 32'));
      }
      return proto.AnyValue();
    }
    return switch (value) {
      AnyValueNull() => proto.AnyValue(),
      AnyValueString(value: final v) => proto.AnyValue(stringValue: v),
      AnyValueBool(value: final v) => proto.AnyValue(boolValue: v),
      AnyValueInt(value: final v) => proto.AnyValue(intValue: Int64(v)),
      AnyValueDouble(value: final v) => proto.AnyValue(doubleValue: v),
      AnyValueBytes(value: final v) => proto.AnyValue(bytesValue: v),
      AnyValueArray(value: final v) => proto.AnyValue(
          arrayValue: proto.ArrayValue(
              values: v.map((item) => encode(item, depth + 1)))),
      AnyValueMap(value: final v) => proto.AnyValue(
          kvlistValue: proto.KeyValueList(
              values: v.entries.map((entry) => proto.KeyValue(
                  key: entry.key, value: encode(entry.value, depth + 1))))),
    };
  }
}

/// Encodes every attribute, including entries containing an empty AnyValue.
List<proto.KeyValue> otlpAttributes(Attributes attributes) => attributes
    .toList()
    .map((attr) =>
        proto.KeyValue(key: attr.key, value: otlpAnyValue(attr.value)))
    .toList();
