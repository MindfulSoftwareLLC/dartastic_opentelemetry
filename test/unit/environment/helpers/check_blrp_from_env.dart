// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: constructs BatchLogRecordProcessorConfig.fromEnvironment() in a
// subprocess and prints the four resolved fields as JSON.
// Run via subprocess with OTEL_BLRP_* env vars set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  final logs = <String>[];
  OTelLog.logFunction = logs.add;
  OTelLog.enableWarnLogging();

  final config = BatchLogRecordProcessorConfig.fromEnvironment();

  final jsonConfig = <String, dynamic>{
    'scheduleDelay_ms': config.scheduleDelay.inMilliseconds,
    'exportTimeout_ms': config.exportTimeout.inMilliseconds,
    'maxQueueSize': config.maxQueueSize,
    'maxExportBatchSize': config.maxExportBatchSize,
    'logs': logs,
  };

  print(jsonEncode(jsonConfig));
}
