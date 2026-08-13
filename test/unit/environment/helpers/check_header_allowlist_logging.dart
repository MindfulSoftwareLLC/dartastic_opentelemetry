// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: prints JSON of the debug log lines emitted while
// getOtlpConfig() parses OTEL_EXPORTER_OTLP_HEADERS, with the allowlist applied.
// Run via subprocess with OTEL_EXPORTER_OTLP_HEADERS and optionally
// OTEL_DART_HEADER_LOG_ALLOWLIST set. Command line arguments stand in for the
// OTel.initialize parameter, so the precedence between the two can be tested.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main(List<String> args) {
  final captured = <String>[];
  OTelLog.logFunction = captured.add;
  OTelLog.currentLevel = LogLevel.debug;

  OTelEnv.applyHeaderLogAllowlist(args.isEmpty ? null : args);
  OTelEnv.getOtlpConfig(signal: 'traces');

  print(jsonEncode(captured));
}
