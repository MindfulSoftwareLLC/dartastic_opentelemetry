// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Helper script: prints JSON of OTelEnv.getOtlpConfig() result.
// Run via subprocess with OTEL_EXPORTER_OTLP_* env vars set.
// Set CHECK_SIGNAL env var to control which signal to check (default: traces).

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  final signal = Platform.environment['CHECK_SIGNAL'] ?? 'traces';
  final config = OTelEnv.getOtlpConfig(signal: signal);

  // Convert Duration to milliseconds for JSON serialization
  final jsonConfig = <String, dynamic>{};
  config.forEach((key, value) {
    if (value is Duration) {
      jsonConfig['${key}_ms'] = value.inMilliseconds;
    } else {
      jsonConfig[key] = value;
    }
  });

  print(jsonEncode(jsonConfig));
}
