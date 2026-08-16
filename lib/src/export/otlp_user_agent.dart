// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Default User-Agent the OTLP exporters send on every request.
///
/// Per the OTLP exporter spec (specification/protocol/exporter.md, "User
/// agent"), OTLP exporters SHOULD emit a `User-Agent` header that at minimum
/// identifies the exporter, the language of its implementation, and the
/// version of the exporter. The HTTP exporters send this header directly; the
/// gRPC exporters pass it through `ChannelOptions.userAgent`, because gRPC
/// treats `user-agent` as a reserved header and would strip it from a
/// user-supplied map.
library;

/// Hand-synced with the package version in pubspec.yaml.
const String packageVersion = '1.1.0-beta.14-wip';

/// The default User-Agent value, e.g. `OTel-OTLP-Exporter-Dart/1.1.0-beta.14-wip`.
const String otlpUserAgent = 'OTel-OTLP-Exporter-Dart/$packageVersion';
