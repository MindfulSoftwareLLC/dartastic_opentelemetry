// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Helper script: constructs BatchSpanProcessorConfig.fromEnvironment() in a
// subprocess and prints the four resolved fields as JSON.
// Run via subprocess with OTEL_BSP_* env vars set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  final logs = <String>[];
  OTelLog.logFunction = logs.add;
  OTelLog.enableWarnLogging();

  final config = BatchSpanProcessorConfig.fromEnvironment();

  final jsonConfig = <String, dynamic>{
    'scheduleDelay_ms': config.scheduleDelay.inMilliseconds,
    'exportTimeout_ms': config.exportTimeout.inMilliseconds,
    'maxQueueSize': config.maxQueueSize,
    'maxExportBatchSize': config.maxExportBatchSize,
    'logs': logs,
  };

  print(jsonEncode(jsonConfig));
}
