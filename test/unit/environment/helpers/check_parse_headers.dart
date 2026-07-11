// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: prints JSON of parsed headers from OTEL_EXPORTER_OTLP_HEADERS.
// Run via subprocess with OTEL_EXPORTER_OTLP_HEADERS env var set.
// This exercises the _parseHeaders() method via getOtlpConfig().

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  OTelLog.logFunction = null;
  final config = OTelEnv.getOtlpConfig(signal: 'traces');
  final headers = config['headers'] as Map<String, String>?;
  print(jsonEncode(headers ?? {}));
}
