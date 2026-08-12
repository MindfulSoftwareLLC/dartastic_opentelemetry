// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: prints a JSON array of every log line emitted while
// OTelEnv.getOtlpConfig() parses OTEL_EXPORTER_OTLP_HEADERS at debug level,
// after the header log allowlist has been applied.
//
// Run via subprocess with OTEL_EXPORTER_OTLP_HEADERS set, and optionally
// DAR_OTLP_HEADER_LOG_ALLOWLIST. Passing names as command line arguments
// stands in for the OTel.initialize parameter, so that the precedence between
// the two can be tested.

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
