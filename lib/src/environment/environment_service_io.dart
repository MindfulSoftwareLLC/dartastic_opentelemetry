// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io' as io;

import 'env_constants.dart';
import 'env_from_define.dart';
import 'environment_service.dart';

/// IO implementation of the environment service.
///
/// This implementation is used on all platforms except web (Dart VM, Flutter
/// native, and Flutter desktop).
///
/// Environment variable lookup priority:
/// 1. String.fromEnvironment (--dart-define values)
/// 2. io.Platform.environment (system environment variables)
///
/// The implementation uses String.fromEnvironment with empty string as the
/// default value. If the result is empty, it falls back to checking
/// io.Platform.environment. This allows --dart-define values to take
/// precedence over system environment variables, as per OpenTelemetry
/// specification recommendations.
class EnvironmentService implements EnvironmentServiceInterface {
  static final EnvironmentService _instance = EnvironmentService._();

  /// The singleton instance of the EnvironmentService.
  static EnvironmentService get instance => _instance;

  EnvironmentService._();

  /// Gets the value of an environment variable.
  ///
  /// Returns the value from the first available source:
  /// 1. String.fromEnvironment if defined via --dart-define
  /// 2. io.Platform.environment (system environment variables)
  /// 3. null if not found
  ///
  /// Note: String.fromEnvironment only works for compile-time constants that
  /// are in our [supportedEnvVars] set. This is a limitation of the Dart
  /// language when using --dart-define.
  ///
  /// @param key The name of the environment variable to retrieve
  /// @return The value of the environment variable, or null if not found
  @override
  String? getValue(String key) {
    // Priority 1: String.fromEnvironment (--dart-define values)
    // Only check if this is a known environment variable
    String? value;
    if (supportedEnvVars.contains(key)) {
      final fromEnvironment = getFromEnvironment(key);
      if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
        value = fromEnvironment;
      }
    }

    // Priority 2: Platform environment variables
    value ??= io.Platform.environment[key];

    // Handle comma-separated values for --define compatibility
    // The --define flag cannot handle commas in values, so we use semicolons
    // as a delimiter for these specific variables and convert them back
    if (value != null) {
      switch (key) {
        case otelResourceAttributes:
        case otelPropagators:
        case otelExporterOtlpHeaders:
        case otelExporterOtlpTracesHeaders:
        case otelExporterOtlpMetricsHeaders:
        case otelExporterOtlpLogsHeaders:
          value = value.replaceAll(';', ',');
          break;
      }
    }

    return value;
  }
}
