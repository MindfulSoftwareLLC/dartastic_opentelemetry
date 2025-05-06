// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io' as io;
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/util/span_logger.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart' show LogFunction, LogLevel;
import 'package:test/test.dart';

void main() {
  group('OTelEnv Tests', () {
    // Save original log settings
    LogFunction? originalLogFunction;
    LogFunction? originalMetricLogFunction;
    LogFunction? originalSpanLogFunction;
    LogFunction? originalExportLogFunction;
    LogLevel originalLogLevel = OTelLog.currentLevel;
    
    setUp(() {
      // Save original logging state
      originalLogFunction = OTelLog.logFunction;
      originalMetricLogFunction = OTelLog.metricLogFunction;
      originalSpanLogFunction = OTelLog.spanLogFunction;
      originalExportLogFunction = OTelLog.exportLogFunction;
      originalLogLevel = OTelLog.currentLevel;
      
      // Clear all logging functions
      OTelLog.logFunction = null;
      OTelLog.metricLogFunction = null;
      OTelLog.spanLogFunction = null;
      OTelLog.exportLogFunction = null;
    });
    
    tearDown(() {
      // Restore original logging state
      OTelLog.logFunction = originalLogFunction;
      OTelLog.metricLogFunction = originalMetricLogFunction;
      OTelLog.spanLogFunction = originalSpanLogFunction;
      OTelLog.exportLogFunction = originalExportLogFunction;
      OTelLog.currentLevel = originalLogLevel;
      
      // Clear test environment variables
      unsetEnvVars();
    });
    
    test('OTelEnv.initializeLogging enables logging based on environment variables', () {
      // Set test environment variables
      io.Platform.environment[OTelEnv.logLevelEnv] = 'debug';
      io.Platform.environment[OTelEnv.enableMetricsLogEnv] = 'true';
      io.Platform.environment[OTelEnv.enableSpansLogEnv] = 'yes';
      io.Platform.environment[OTelEnv.enableExportLogEnv] = '1';
      
      // Capture logs
      final List<String> logs = [];
      final List<String> metricLogs = [];
      final List<String> spanLogs = [];
      final List<String> exportLogs = [];
      
      // Set log capture functions
      OTelLog.logFunction = logs.add;
      OTelLog.metricLogFunction = metricLogs.add;
      OTelLog.spanLogFunction = spanLogs.add;
      OTelLog.exportLogFunction = exportLogs.add;
      
      // Initialize logging from environment
      OTelEnv.initializeLogging();
      
      // Verify log settings
      expect(OTelLog.currentLevel, equals(LogLevel.debug));
      expect(OTelLog.isDebug(), isTrue);
      expect(OTelLog.isLogMetrics(), isTrue);
      expect(OTelLog.isLogSpans(), isTrue);
      expect(OTelLog.isLogExport(), isTrue);
      
      // Generate test logs
      OTelLog.debug('Test debug message');
      OTelLog.logMetric('Test metric message');
      logSpans([], 'Test span message');
      OTelLog.logExport('Test export message');
      
      // Verify logs were captured
      expect(logs.length, equals(1));
      expect(logs.first, contains('DEBUG'));
      expect(logs.first, contains('Test debug message'));
      
      expect(metricLogs.length, equals(1));
      expect(metricLogs.first, contains('metric'));
      expect(metricLogs.first, contains('Test metric message'));
      
      expect(spanLogs.length, equals(1));
      expect(spanLogs.first, contains('spans'));
      expect(spanLogs.first, contains('Test span message'));
      
      expect(exportLogs.length, equals(1));
      expect(exportLogs.first, contains('export'));
      expect(exportLogs.first, contains('Test export message'));
    });
    
    test('OTelEnv respects different log levels', () {
      // Test different log levels
      final logLevels = ['trace', 'debug', 'info', 'warn', 'error', 'fatal'];
      
      for (final level in logLevels) {
        // Reset logs for each level
        final List<String> logs = [];
        OTelLog.logFunction = logs.add;
        
        // Set environment variable and initialize
        io.Platform.environment[OTelEnv.logLevelEnv] = level;
        OTelEnv.initializeLogging();
        
        // Generate test logs at all levels
        OTelLog.trace('Trace message');
        OTelLog.debug('Debug message');
        OTelLog.info('Info message');
        OTelLog.warn('Warn message');
        OTelLog.error('Error message');
        OTelLog.fatal('Fatal message');
        
        // Verify logs were captured correctly per level
        switch (level) {
          case 'trace':
            expect(logs.length, equals(6));
            break;
          case 'debug':
            expect(logs.length, equals(5));
            expect(logs.any((log) => log.contains('Debug message')), isTrue);
            expect(logs.any((log) => log.contains('Trace message')), isFalse);
            break;
          case 'info':
            expect(logs.length, equals(4));
            expect(logs.any((log) => log.contains('Info message')), isTrue);
            expect(logs.any((log) => log.contains('Debug message')), isFalse);
            break;
          case 'warn':
            expect(logs.length, equals(3));
            expect(logs.any((log) => log.contains('Warn message')), isTrue);
            expect(logs.any((log) => log.contains('Info message')), isFalse);
            break;
          case 'error':
            expect(logs.length, equals(2));
            expect(logs.any((log) => log.contains('Error message')), isTrue);
            expect(logs.any((log) => log.contains('Warn message')), isFalse);
            break;
          case 'fatal':
            expect(logs.length, equals(1));
            expect(logs.any((log) => log.contains('Fatal message')), isTrue);
            expect(logs.any((log) => log.contains('Error message')), isFalse);
            break;
        }
      }
    });
    
    test('OTelEnv ignores unknown log levels', () {
      // Set logging function
      bool logFunctionCalled = false;
      OTelLog.logFunction = (String message) {
        logFunctionCalled = true;
      };
      
      // Set invalid log level
      io.Platform.environment[OTelEnv.logLevelEnv] = 'invalid_level';
      
      // Initialize logging
      OTelEnv.initializeLogging();
      
      // Verify log function wasn't affected
      expect(OTelLog.logFunction, isNotNull);
      
      // Default level should be used
      OTelLog.error('Test error message');
      expect(logFunctionCalled, isTrue);
    });
  });
}

/// Helper to unset environment variables used in tests
void unsetEnvVars() {
  // Clear test environment variables
  try {
    io.Platform.environment.remove(OTelEnv.logLevelEnv);
    io.Platform.environment.remove(OTelEnv.enableMetricsLogEnv);
    io.Platform.environment.remove(OTelEnv.enableSpansLogEnv);
    io.Platform.environment.remove(OTelEnv.enableExportLogEnv);
  } catch (e) {
    // Platform.environment might be unmodifiable in some environments
    // Just ignore the error in those cases
  }
}
