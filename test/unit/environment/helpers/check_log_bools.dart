// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Helper script: prints JSON with boolean log function status after
// OTelEnv.initializeLogging().
// Run via subprocess with OTEL_LOG_METRICS, OTEL_LOG_SPANS, OTEL_LOG_EXPORT
// env vars set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  // Start from a clean state
  OTelLog.logFunction = null;
  OTelLog.metricLogFunction = null;
  OTelLog.spanLogFunction = null;
  OTelLog.exportLogFunction = null;

  OTelEnv.initializeLogging();

  print(jsonEncode({
    'metricLogFunction': OTelLog.metricLogFunction != null,
    'spanLogFunction': OTelLog.spanLogFunction != null,
    'exportLogFunction': OTelLog.exportLogFunction != null,
  }));
}
