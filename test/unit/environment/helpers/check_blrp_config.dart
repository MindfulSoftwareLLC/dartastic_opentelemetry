// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: prints JSON of OTelEnv.getBlrpConfig() result.
// Run via subprocess with OTEL_BLRP_* env vars set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  OTelLog.logFunction = null;
  final config = OTelEnv.getBlrpConfig();

  // Convert Duration to milliseconds for JSON serialization
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
