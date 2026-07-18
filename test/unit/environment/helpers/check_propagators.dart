// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: initializes the SDK and prints JSON describing the
// global TextMapPropagator that OTel.initialize() installed per
// OTEL_PROPAGATORS. Run via subprocess with env vars set.

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

Future<void> main() async {
  final warnings = <String>[];
  OTelLog.logFunction = warnings.add;
  OTelLog.currentLevel = LogLevel.warn;

  await OTel.initialize(
    serviceName: 'propagator-check',
    serviceVersion: '1.0.0',
  );

  final propagator = OTelAPI.textMapPropagator;
  OTelLog.logFunction = null;
  print(jsonEncode({
    'type': propagator.runtimeType.toString(),
    'fields': [...propagator.fields()]..sort(),
    'logs':
        warnings.where((line) => line.contains('OTEL_PROPAGATORS')).toList(),
  }));

  // Force-exit to avoid waiting on background batch/metric timers — we
  // only want the installed-propagator snapshot.
  exit(0);
}
