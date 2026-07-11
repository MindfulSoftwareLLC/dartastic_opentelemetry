// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Wire-format protocol for OTLP/HTTP exporters.
///
/// The OpenTelemetry specification defines two HTTP encodings:
///   - `application/x-protobuf` — protobuf-encoded OTLP messages. The
///     spec-recommended default; smaller payloads, faster to encode.
///   - `application/json` — JSON-encoded OTLP messages using the
///     protobuf-to-JSON mapping (proto3 JSON). Optional per spec — SDKs
///     `MAY` support it — but supported by Dartastic for parity with the
///     JS/Python implementations and for backends that prefer JSON for
///     human-readable telemetry (e.g. local dev UIs, Browser DevTools).
///
/// See `specification/protocol/exporter.md` for the full conformance
/// rules; the env-var `OTEL_EXPORTER_OTLP_PROTOCOL` (and signal-specific
/// `_TRACES_PROTOCOL` / `_METRICS_PROTOCOL` / `_LOGS_PROTOCOL` variants)
/// selects this from configuration with values `http/protobuf` or
/// `http/json`. `OtlpHttpProtocol.httpProtobuf` is the default.
enum OtlpHttpProtocol {
  /// `application/x-protobuf` — protobuf-encoded OTLP messages.
  httpProtobuf,

  /// `application/json` — proto3-JSON-encoded OTLP messages.
  httpJson,
}

/// Parses the OTel `OTEL_EXPORTER_OTLP_PROTOCOL` env-var value into an
/// [OtlpHttpProtocol]. Returns `null` for unsupported values (e.g. `grpc`
/// — caller is expected to handle that out-of-band by selecting an
/// OTLP/gRPC exporter instead).
OtlpHttpProtocol? otlpHttpProtocolFromString(String value) {
  switch (value.trim().toLowerCase()) {
    case 'http/protobuf':
      return OtlpHttpProtocol.httpProtobuf;
    case 'http/json':
      return OtlpHttpProtocol.httpJson;
    default:
      return null;
  }
}
