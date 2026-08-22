// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: prints JSON of OTelEnv.getServiceConfig() result.
// Run via subprocess with OTEL_RESOURCE_ATTRIBUTES and/or OTEL_SERVICE_NAME
// env vars set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  final config = OTelEnv.getServiceConfig();

  // Convert record to JSON-serializable map.
  final jsonConfig = <String, dynamic>{};
  if (config.serviceName != null) {
    jsonConfig['serviceName'] = config.serviceName;
  }
  if (config.serviceVersion != null) {
    jsonConfig['serviceVersion'] = config.serviceVersion;
  }

  print(jsonEncode(jsonConfig));
}
