#!/usr/bin/env dart
// Comprehensive utility to test reading ALL OTel environment variables
// Used by integration tests to verify both POSIX env vars and --dart-defines work

import 'dart:convert';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: read_all_env_vars.dart <output_format>');
    print('  json  - Output as JSON');
    print('  text  - Output as text (ENV_VAR=value)');
    return;
  }

  final format = args[0];
  final envService = EnvironmentService.instance;

  // Read ALL supported env vars
  final results = <String, String?>{};

  for (final envVar in supportedEnvVars) {
    results[envVar] = envService.getValue(envVar);
  }

  if (format == 'json') {
    print(jsonEncode(results));
  } else {
    for (final entry in results.entries) {
      final value = entry.value ?? '<null>';
      print('${entry.key}=$value');
    }
  }
}
