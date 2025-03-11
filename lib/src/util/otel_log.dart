// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import '../../dartastic_opentelemetry.dart';

enum LogLevel {
  trace(6),
  debug(4),
  info(3),
  warn(2),
  error(1),
  fatal(0);

  final int level;

  const LogLevel(this.level);
}

typedef LogFunction = void Function(String);

/// A simple log service that logs messages and signals to the console.
/// It filters messages based on the current log level.
/// Signals are not filtered based on log level
/// Defaults to noop,
class OTelLog {
  static LogLevel currentLevel = LogLevel.error;

  /// To turn on logging at the current level, set this
  /// to `print` (Dart) or `debugPrint` (Flutter) or any other LogFunction.
  static LogFunction? logFunction;

  /// To turn on logging for spans, set this
  /// to `print` (Dart) or `debugPrint` (Flutter) or any other LogFunction.
  static LogFunction? spanLogFunction;

  /// To turn on logging for metrics, set this
  /// to `print` (Dart) or `debugPrint` (Flutter) or any other LogFunction.
  static LogFunction? metricLogFunction;

  /// To turn on logging for export, set this
  /// to `print` (Dart) or `debugPrint` (Flutter) or any other LogFunction.
  static LogFunction? exportLogFunction;

  static bool isTrace() =>
      logFunction != null && currentLevel.level >= LogLevel.trace.level;

  static bool isDebug() =>
      logFunction != null && currentLevel.level >= LogLevel.debug.level;

  static bool isInfo() =>
      logFunction != null && currentLevel.level >= LogLevel.info.level;

  static bool isWarn() =>
      logFunction != null && currentLevel.level >= LogLevel.warn.level;

  static bool isError() =>
      logFunction != null && currentLevel.level >= LogLevel.error.level;

  static bool isFatal() =>
      logFunction != null && currentLevel.level >= LogLevel.fatal.level;

  static bool isLogSpans() => spanLogFunction != null;

  static bool isLogMetrics() => metricLogFunction != null;

  static bool isLogExport() => exportLogFunction != null;

      /// Generic log method. It prints the message if the [level] is at or above
  /// the [currentLevel].
  static void log(LogLevel level, String message) {
    if (logFunction == null) {
      return;
    } else {
      // Only log messages that are of high enough priority.
      if (level.index >= currentLevel.index) {
        final timestamp = DateTime.now().toIso8601String();
        // Extract just the log level name (e.g., 'DEBUG').
        final levelName = level.toString().split('.').last.toUpperCase();
        logFunction!('[$timestamp] [$levelName] $message');
      }
    }
  }

  /// Log a span with an optional message.
  static void logSpan(Span span, [String? message]) {
    if (logFunction == null) {
      return;
    } else {
      final timestamp = DateTime.now().toIso8601String();
      String msg = message ?? '';
      logFunction!('[$timestamp] [message] $msg [span] $span');
    }
  }

  /// Log a span with an optional message.
  static void logSpans(List<Span> spans, [String? message]) {
    if (isLogSpans()) {
      final timestamp = DateTime.now().toIso8601String();
      String msg = message ?? '';
      spanLogFunction!('[$timestamp] [message] $msg [spans] $spans');
    }
  }

  /// Log a span with an optional message.
  static void logMetric(String message) {
    if (isLogMetrics()) {
      final timestamp = DateTime.now().toIso8601String();
      String msg = message;
      metricLogFunction!('[$timestamp] [metric] $msg ');
    }
  }

  /// Log a span with an optional message.
  static void logExport(String message) {
    if (isLogExport()) {
      final timestamp = DateTime.now().toIso8601String();
      String msg = message;
      exportLogFunction!('[$timestamp] [metric] $msg ');
    }
  }

  static void trace(String message) => log(LogLevel.trace, message);

  static void debug(String message) => log(LogLevel.debug, message);

  static void info(String message) => log(LogLevel.info, message);

  static void warn(String message) => log(LogLevel.warn, message);

  static void error(String message) => log(LogLevel.error, message);

}
