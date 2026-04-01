// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Helper script: prints JSON of OTelEnv.getResourceAttributes() result.
// Run via subprocess with OTEL_RESOURCE_ATTRIBUTES env var set.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  final attrs = OTelEnv.getResourceAttributes();
  print(jsonEncode(attrs));
}
