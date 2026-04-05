// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Helper script: initializes OTel and runs EnvVarResourceDetector, prints
// the detected attributes as JSON.
// Run via subprocess with OTEL_RESOURCE_ATTRIBUTES env var set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() async {
  // Suppress all logging so only our JSON goes to stdout.
  // Use a no-op function (not null, not print) so initializeLogging() won't
  // override it from the OTEL_LOG_LEVEL env var.
  OTelLog.logFunction = (_) {};

  await OTel.initialize(
    serviceName: 'test',
    detectPlatformResources: false,
    enableMetrics: false,
    enableLogs: false,
  );

  final detector = EnvVarResourceDetector();
  final resource = await detector.detect();

  final attrs = <String, dynamic>{};
  resource.attributes.toList().forEach((attr) {
    attrs[attr.key] = attr.value;
  });

  print(jsonEncode(attrs));

  await OTel.shutdown();
  await OTel.reset();
}
