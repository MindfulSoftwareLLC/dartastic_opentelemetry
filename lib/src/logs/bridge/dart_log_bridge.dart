// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../logger.dart';
import '../logger_provider.dart';

/// A bridge that intercepts Dart's built-in logging and sends it to OpenTelemetry.
///
/// This bridge provides integration with Dart's `dart:developer` log function
/// by allowing you to configure a callback that converts Dart log calls to
/// OpenTelemetry log records.
///
/// Note: Dart's built-in `print` function cannot be intercepted directly.
/// For `print` interception, you must replace `print` with a custom function
/// in your zone or use a logging framework.
///
/// Example usage:
/// ```dart
/// // Initialize OTel and set up the bridge
/// await OTel.initialize(...);
/// final logger = OTel.logger('my-app');
///
/// // Install the bridge
/// DartLogBridge.install(logger);
///
/// // Now developer.log calls will be captured
/// developer.log('Hello from dart:developer', name: 'my-app');
/// ```
class DartLogBridge {
  /// The logger provider to use for creating loggers.
  final LoggerProvider _loggerProvider;

  /// Default logger name for logs without a name.
  final String _defaultLoggerName;

  /// Minimum severity level to capture.
  final Severity _minimumSeverity;

  /// Whether the bridge is active.
  bool _isActive = false;

  /// Singleton instance for the installed bridge.
  static DartLogBridge? _instance;

  /// Creates a new DartLogBridge.
  ///
  /// @param loggerProvider The LoggerProvider to use for creating loggers
  /// @param defaultLoggerName Default name for logs without a name
  /// @param minimumSeverity Minimum severity level to capture
  DartLogBridge({
    required LoggerProvider loggerProvider,
    String defaultLoggerName = 'dart.developer',
    Severity minimumSeverity = Severity.DEBUG,
  })  : _loggerProvider = loggerProvider,
        _defaultLoggerName = defaultLoggerName,
        _minimumSeverity = minimumSeverity;

  /// Installs the bridge using a specific Logger.
  ///
  /// This is a convenience method for simple use cases where you want
  /// all dart:developer logs to go to a single logger.
  ///
  /// @param logger The logger to send all logs to
  /// @param minimumSeverity Minimum severity level to capture
  /// @return The installed DartLogBridge instance
  static DartLogBridge install(
    Logger logger, {
    Severity minimumSeverity = Severity.DEBUG,
  }) {
    _instance = DartLogBridge(
      loggerProvider: logger.provider,
      defaultLoggerName: logger.name,
      minimumSeverity: minimumSeverity,
    );
    _instance!.activate();
    return _instance!;
  }

  /// Installs the bridge using a LoggerProvider.
  ///
  /// This allows logs to be routed to different loggers based on the
  /// log name in dart:developer.log().
  ///
  /// @param loggerProvider The LoggerProvider to use
  /// @param defaultLoggerName Default name for logs without a name
  /// @param minimumSeverity Minimum severity level to capture
  /// @return The installed DartLogBridge instance
  static DartLogBridge installWithProvider(
    LoggerProvider loggerProvider, {
    String defaultLoggerName = 'dart.developer',
    Severity minimumSeverity = Severity.DEBUG,
  }) {
    _instance = DartLogBridge(
      loggerProvider: loggerProvider,
      defaultLoggerName: defaultLoggerName,
      minimumSeverity: minimumSeverity,
    );
    _instance!.activate();
    return _instance!;
  }

  /// Uninstalls the current bridge.
  static void uninstall() {
    _instance?.deactivate();
    _instance = null;
  }

  /// Gets the currently installed bridge, if any.
  static DartLogBridge? get current => _instance;

  /// Activates the bridge to start capturing logs.
  void activate() {
    _isActive = true;
    if (OTelLog.isDebug()) {
      OTelLog.debug('DartLogBridge: Activated');
    }
  }

  /// Deactivates the bridge to stop capturing logs.
  void deactivate() {
    _isActive = false;
    if (OTelLog.isDebug()) {
      OTelLog.debug('DartLogBridge: Deactivated');
    }
  }

  /// Whether the bridge is currently active.
  bool get isActive => _isActive;

  /// Logs a message using the bridge.
  ///
  /// This method is called by the zone handler when dart:developer.log is used.
  ///
  /// @param message The log message
  /// @param time The timestamp
  /// @param sequenceNumber The sequence number
  /// @param level The log level (0-2000)
  /// @param name The log name (logger name)
  /// @param zone The zone where the log was made
  /// @param error The error object, if any
  /// @param stackTrace The stack trace, if any
  void log(
    String message, {
    DateTime? time,
    int? sequenceNumber,
    int level = 0,
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_isActive) return;

    // Convert Dart log level to OTel Severity
    // Dart levels: 0 = finest/trace, 500 = fine/debug, 800 = config/info,
    // 900 = info, 1000 = warning, 2000 = severe
    final severity = _levelToSeverity(level);

    // Filter by minimum severity
    if (severity.severityNumber < _minimumSeverity.severityNumber) {
      return;
    }

    // Get the appropriate logger
    final loggerName = name?.isNotEmpty == true ? name! : _defaultLoggerName;
    final logger = _loggerProvider.getLogger(loggerName);

    // Build attributes
    final attributes = <Attribute>[];
    if (sequenceNumber != null) {
      attributes.add(OTelAPI.attributeInt('sequence_number', sequenceNumber));
    }
    if (error != null) {
      attributes.add(OTelAPI.attributeString(
          'exception.type', error.runtimeType.toString()));
      attributes
          .add(OTelAPI.attributeString('exception.message', error.toString()));
    }
    if (stackTrace != null) {
      attributes.add(OTelAPI.attributeString(
          'exception.stacktrace', stackTrace.toString()));
    }

    // Emit the log
    logger.emit(
      timeStamp: time,
      severityNumber: severity,
      severityText: severity.name,
      body: message,
      attributes:
          attributes.isNotEmpty ? OTelAPI.attributesFromList(attributes) : null,
    );
  }

  /// Converts a Dart log level to an OpenTelemetry Severity.
  ///
  /// Dart log levels (from logging package):
  /// - 0: ALL/finest (trace)
  /// - 300: FINEST
  /// - 400: FINER
  /// - 500: FINE (debug)
  /// - 700: CONFIG
  /// - 800: INFO
  /// - 900: WARNING
  /// - 1000: SEVERE (error)
  /// - 1200: SHOUT
  /// - 2000: OFF
  Severity _levelToSeverity(int level) {
    if (level < 300) {
      return Severity.TRACE;
    } else if (level < 500) {
      return Severity.TRACE2;
    } else if (level < 700) {
      return Severity.DEBUG;
    } else if (level < 800) {
      return Severity.DEBUG2;
    } else if (level < 900) {
      return Severity.INFO;
    } else if (level < 1000) {
      return Severity.WARN;
    } else if (level < 1200) {
      return Severity.ERROR;
    } else {
      return Severity.FATAL;
    }
  }

  /// Creates a zone specification that captures dart:developer logs.
  ///
  /// Use this to create a zone that automatically routes all
  /// dart:developer.log calls through the bridge.
  ///
  /// Example:
  /// ```dart
  /// final bridge = DartLogBridge.install(logger);
  /// runZoned(
  ///   () {
  ///     // Your app code here
  ///     developer.log('This will be captured', name: 'my-app');
  ///   },
  ///   zoneSpecification: bridge.createZoneSpecification(),
  /// );
  /// ```
  ZoneSpecification createZoneSpecification() {
    return ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        // Capture print statements as INFO logs
        if (_isActive) {
          log(line, level: 800); // INFO level
        }
        // Still call the original print
        parent.print(zone, line);
      },
    );
  }
}

/// Extension to easily use the logging bridge with dart:developer.
extension DartDeveloperLogBridge on developer.ServiceExtensionHandler {
  /// Helper to emit a log that will be captured by the bridge if installed.
  static void emitLog(
    String message, {
    DateTime? time,
    int? sequenceNumber,
    int level = 0,
    String name = '',
    Object? error,
    StackTrace? stackTrace,
  }) {
    // First, call the original dart:developer log
    developer.log(
      message,
      time: time,
      sequenceNumber: sequenceNumber,
      level: level,
      name: name,
      error: error,
      stackTrace: stackTrace,
    );

    // If bridge is installed, also log via OTel
    DartLogBridge.current?.log(
      message,
      time: time,
      sequenceNumber: sequenceNumber,
      level: level,
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
