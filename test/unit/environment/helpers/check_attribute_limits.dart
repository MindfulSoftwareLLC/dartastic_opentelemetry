// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: prints JSON of OTelEnv.getAttributeLimits() result.
// Run via subprocess with OTEL_ATTRIBUTE_* env vars set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  OTelLog.logFunction = null;
  final config = OTelEnv.getAttributeLimits();
  final jsonConfig = <String, dynamic>{};
  if (config.attributeValueLengthLimit != null) {
    jsonConfig['attributeValueLengthLimit'] = config.attributeValueLengthLimit;
  }
  if (config.attributeCountLimit != null) {
    jsonConfig['attributeCountLimit'] = config.attributeCountLimit;
  }

  print(jsonEncode(jsonConfig));
}
