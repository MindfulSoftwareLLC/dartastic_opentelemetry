#!/usr/bin/env dart
// Simple utility to read environment variables and output them in a parseable format
// Used by test_env_vars.sh to verify environment variable reading works correctly

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main(List<String> args) {
  final envService = EnvironmentService.instance;
  
  // Read the requested environment variables from command line args
  // Format: ENV_VAR_NAME1 ENV_VAR_NAME2 ...
  if (args.isEmpty) {
    print('ERROR: No environment variable names provided');
    return;
  }
  
  for (final envVarName in args) {
    final value = envService.getValue(envVarName);
    // Output format: ENV_VAR_NAME=value (or ENV_VAR_NAME=<null> if not set)
    if (value != null) {
      print('$envVarName=$value');
    } else {
      print('$envVarName=<null>');
    }
  }
}
