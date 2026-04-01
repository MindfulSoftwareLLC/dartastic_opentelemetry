// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

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
