// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io' as io;
import 'otel_log.dart';

/// Environment variables for controlling OTel SDK behavior
class OTelEnv {
  /// Environment variable names
  static const String logLevelEnv = 'OTEL_LOG_LEVEL';
  static const String enableMetricsLogEnv = 'OTEL_LOG_METRICS';
  static const String enableSpansLogEnv = 'OTEL_LOG_SPANS';
  static const String enableExportLogEnv = 'OTEL_LOG_EXPORT';

  /// Initialize logging based on environment variables
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

  /// Get environment variable
  static String? _getEnv(String name) {
    try {
      return io.Platform.environment[name];
    } catch (e) {
      // In case we're in a browser environment where Platform is not available
      return null;
    }
  }

  /// Get boolean environment variable (true if value is '1', 'true', 'yes', or 'on')
  static bool _getEnvBool(String name) {
    final value = _getEnv(name)?.toLowerCase();
    return value == '1' || value == 'true' || value == 'yes' || value == 'on';
  }
}
