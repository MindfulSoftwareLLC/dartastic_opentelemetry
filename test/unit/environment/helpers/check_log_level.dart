// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Helper script: prints the log level after OTelEnv.initializeLogging().
// Run via subprocess with OTEL_LOG_LEVEL env var set.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show LogLevel;

void main() {
  // Start from a clean state
  OTelLog.logFunction = null;
  OTelLog.metricLogFunction = null;
  OTelLog.spanLogFunction = null;
  OTelLog.exportLogFunction = null;
  OTelLog.currentLevel = LogLevel.info;

  OTelEnv.initializeLogging();

  // Print the resulting log level name
  print(OTelLog.currentLevel.name);
}
