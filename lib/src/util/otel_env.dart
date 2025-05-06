// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io' as io;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Utility class for handling OpenTelemetry environment variables.
///
/// This class provides methods for reading standard OpenTelemetry environment
/// variables and applying their configuration to the SDK.
///
/// OpenTelemetry standard environment variables:
/// https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
class OTelEnv {
  /// Environment variable names
  /// Log level for the OTelLog class (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
  static const String logLevelEnv = 'OTEL_LOG_LEVEL';
  
  /// Enable logging of metrics (1, true, yes, on)
  static const String enableMetricsLogEnv = 'OTEL_LOG_METRICS';
  
  /// Enable logging of spans (1, true, yes, on)
  static const String enableSpansLogEnv = 'OTEL_LOG_SPANS';
  
  /// Enable logging of exports (1, true, yes, on)
  static const String enableExportLogEnv = 'OTEL_LOG_EXPORT';

  /// Initialize logging based on environment variables.
  ///
  /// This method reads the logging-related environment variables
  /// and configures the OTelLog accordingly.
  static void initializeLogging() {
    // Set log level based on environment variable
    final logLevel = _getEnv(logLevelEnv)?.toLowerCase();
    if (logLevel != null) {
      switch (logLevel) {
        case 'trace':
          OTelLog.enableTraceLogging();
          OTelLog.logFunction = print;
          break;
        case 'debug':
          OTelLog.enableDebugLogging();
          OTelLog.logFunction = print;
          break;
        case 'info':
          OTelLog.enableInfoLogging();
          OTelLog.logFunction = print;
          break;
        case 'warn':
          OTelLog.enableWarnLogging();
          OTelLog.logFunction = print;
          break;
        case 'error':
          OTelLog.enableErrorLogging();
          OTelLog.logFunction = print;
          break;
        case 'fatal':
          OTelLog.enableFatalLogging();
          OTelLog.logFunction = print;
          break;
        default:
          // No change to logging if level not recognized
          break;
      }
    }

    // Enable metrics logging based on environment variable
    if (_getEnvBool(enableMetricsLogEnv)) {
      OTelLog.metricLogFunction = print;
    }

    // Enable spans logging based on environment variable
    if (_getEnvBool(enableSpansLogEnv)) {
      OTelLog.spanLogFunction = print;
    }

    // Enable export logging based on environment variable
    if (_getEnvBool(enableExportLogEnv)) {
      OTelLog.exportLogFunction = print;
    }
  }

  /// Get environment variable value.
  ///
  /// This method safely retrieves an environment variable value,
  /// handling exceptions that might occur in environments where
  /// Platform is not available (e.g., browsers).
  ///
  /// @param name The name of the environment variable
  /// @return The value of the environment variable, or null if not found
  static String? _getEnv(String name) {
    try {
      return io.Platform.environment[name];
    } catch (e) {
      // In case we're in a browser environment where Platform is not available
      return null;
    }
  }

  /// Get boolean environment variable value.
  ///
  /// This method converts an environment variable value to a boolean.
  /// Values of '1', 'true', 'yes', and 'on' (case-insensitive) are considered true.
  ///
  /// @param name The name of the environment variable
  /// @return true if the environment variable has a truthy value, false otherwise
  static bool _getEnvBool(String name) {
    final value = _getEnv(name)?.toLowerCase();
    return value == '1' || value == 'true' || value == 'yes' || value == 'on';
  }
}
