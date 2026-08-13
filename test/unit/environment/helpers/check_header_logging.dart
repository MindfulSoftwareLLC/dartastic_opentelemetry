// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: prints JSON of the debug log lines emitted while
// getOtlpConfig() parses OTEL_EXPORTER_OTLP_HEADERS.
// Run via subprocess with OTEL_EXPORTER_OTLP_HEADERS set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  final captured = <String>[];
  OTelLog.logFunction = captured.add;
  OTelLog.currentLevel = LogLevel.debug;

  OTelEnv.getOtlpConfig(signal: 'traces');

  print(jsonEncode(captured));
}
