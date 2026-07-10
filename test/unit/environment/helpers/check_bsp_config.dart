// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Helper script: prints JSON of OTelEnv.getBspConfig() result.
// Run via subprocess with OTEL_BSP_* env vars set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  OTelLog.logFunction = null;
  final config = OTelEnv.getBspConfig();

  // Convert Duration to milliseconds for JSON serialization.
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
