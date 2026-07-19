// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: prints JSON of OTelEnv.getLogRecordLimits() result.
// Run via subprocess with OTEL_LOGRECORD_* env vars set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  OTelLog.logFunction = null;
  final config = OTelEnv.getLogRecordLimits();
  print(jsonEncode(config.toJson()));
}
