// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: prints the log level after OTelEnv.initializeLogging().
// Run via subprocess with OTEL_LOG_LEVEL env var set.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

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
