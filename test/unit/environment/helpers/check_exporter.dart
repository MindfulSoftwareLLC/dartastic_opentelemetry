// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Helper script: prints the result of OTelEnv.getExporter().
// Run via subprocess with OTEL_TRACES_EXPORTER, OTEL_METRICS_EXPORTER,
// or OTEL_LOGS_EXPORTER env var set.
// Set CHECK_SIGNAL env var to control which signal to check (default: traces).

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  final signal = Platform.environment['CHECK_SIGNAL'] ?? 'traces';
  final exporter = OTelEnv.getExporter(signal: signal);
  print(exporter ?? 'null');
}
