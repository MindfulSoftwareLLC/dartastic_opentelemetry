// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Helper script: prints JSON of OTelEnv.getBspConfig() result.
// Run via subprocess with OTEL_BSP_* env vars set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  OTelLog.logFunction = null;
  final config = OTelEnv.getBspConfig();

  // Convert record to JSON-serializable map.
  final jsonConfig = <String, dynamic>{};
  if (config.scheduleDelay != null) {
    jsonConfig['scheduleDelay_ms'] = config.scheduleDelay!.inMilliseconds;
  }
  if (config.exportTimeout != null) {
    jsonConfig['exportTimeout_ms'] = config.exportTimeout!.inMilliseconds;
  }
  if (config.maxQueueSize != null) {
    jsonConfig['maxQueueSize'] = config.maxQueueSize;
  }
  if (config.maxExportBatchSize != null) {
    jsonConfig['maxExportBatchSize'] = config.maxExportBatchSize;
  }

  print(jsonEncode(jsonConfig));
}
