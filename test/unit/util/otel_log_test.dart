// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('OTelLog Tests', () {
    // Save original log settings
    LogFunction? originalLogFunction;
    LogLevel originalLogLevel = OTelLog.currentLevel;
    
    setUp(() {
      // Save original logging state
      originalLogFunction = OTelLog.logFunction;
      originalLogLevel = OTelLog.currentLevel;
      
      // Reset for testing
      OTelLog.logFunction = null;
      OTelLog.currentLevel = LogLevel.error; // Default
    });
    
    tearDown(() {
      // Restore original logging state
      OTelLog.logFunction = originalLogFunction;
      OTelLog.currentLevel = originalLogLevel;
    });
    
    test('OTelLog functions correctly set log level', () {
      // Test all log level setting functions
      OTelLog.enableTraceLogging();
      expect(OTelLog.currentLevel, equals(LogLevel.trace));
      
      OTelLog.enableDebugLogging();
      expect(OTelLog.currentLevel, equals(LogLevel.debug));
      
      OTelLog.enableInfoLogging();
      expect(OTelLog.currentLevel, equals(LogLevel.info));
      
      OTelLog.enableWarnLogging();
      expect(OTelLog.currentLevel, equals(LogLevel.warn));
      
      OTelLog.enableErrorLogging();
      expect(OTelLog.currentLevel, equals(LogLevel.error));
      
      OTelLog.enableFatalLogging();
      expect(OTelLog.currentLevel, equals(LogLevel.fatal));
    });
    
    test('OTelLog only logs messages at or above current level', () {
      // Capture logs
      List<String> logs = [];
      OTelLog.logFunction = (String message) {
        logs.add(message);
      };
      
      // Set to INFO level
      OTelLog.enableInfoLogging();
      
      // Log at all levels
      OTelLog.trace('Trace message');
      OTelLog.debug('Debug message');
      OTelLog.info('Info message');
      OTelLog.warn('Warn message');
      OTelLog.error('Error message');
      OTelLog.fatal('Fatal message');
      
      // Verify only the right messages are logged
      expect(logs.length, equals(4)); // info, warn, error, fatal
      expect(logs.any((log) => log.contains('INFO') && log.contains('Info message')), isTrue);
      expect(logs.any((log) => log.contains('WARN') && log.contains('Warn message')), isTrue);
      expect(logs.any((log) => log.contains('ERROR') && log.contains('Error message')), isTrue);
      expect(logs.any((log) => log.contains('FATAL') && log.contains('Fatal message')), isTrue);
      expect(logs.any((log) => log.contains('TRACE')), isFalse);
      expect(logs.any((log) => log.contains('DEBUG')), isFalse);
    });
    
    test('OTelLog functions respect isXxx() convenience methods', () {
      // Initially no logging
      expect(OTelLog.isTrace(), isFalse); 
      expect(OTelLog.isDebug(), isFalse);
      expect(OTelLog.isInfo(), isFalse);
      expect(OTelLog.isWarn(), isFalse);
      expect(OTelLog.isError(), isFalse);
      expect(OTelLog.isFatal(), isFalse);
      
      // Set log function but keep high level
      OTelLog.logFunction = (_) {};
      OTelLog.currentLevel = LogLevel.error;
      
      expect(OTelLog.isTrace(), isFalse);
      expect(OTelLog.isDebug(), isFalse);
      expect(OTelLog.isInfo(), isFalse);
      expect(OTelLog.isWarn(), isFalse);
      expect(OTelLog.isError(), isTrue);
      expect(OTelLog.isFatal(), isTrue);
      
      // Set to lowest level
      OTelLog.currentLevel = LogLevel.trace;
      
      expect(OTelLog.isTrace(), isTrue);
      expect(OTelLog.isDebug(), isTrue);
      expect(OTelLog.isInfo(), isTrue);
      expect(OTelLog.isWarn(), isTrue);
      expect(OTelLog.isError(), isTrue);
      expect(OTelLog.isFatal(), isTrue);
    });
    
    test('OTelLog log() method includes timestamp and level', () {
      // Capture logs
      List<String> logs = [];
      OTelLog.logFunction = (String message) {
        logs.add(message);
      };
      
      // Log using direct log method
      OTelLog.log(LogLevel.info, 'Direct log message');
      
      // Verify format
      expect(logs.length, equals(1));
      expect(logs.first, matches(r'\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d+\]')); // timestamp
      expect(logs.first, contains('[INFO]'));
      expect(logs.first, contains('Direct log message'));
    });
    
    test('OTelLog specialized logging methods work correctly', () {
      // Test specialized logging methods
      List<String> metricLogs = [];
      List<String> spanLogs = [];
      List<String> exportLogs = [];
      
      // Set specialized logging functions
      OTelLog.metricLogFunction = (String message) {
        metricLogs.add(message);
      };
      OTelLog.spanLogFunction = (String message) {
        spanLogs.add(message);
      };
      OTelLog.exportLogFunction = (String message) {
        exportLogs.add(message);
      };
      
      // Verify isLogX methods
      expect(OTelLog.isLogMetrics(), isTrue);
      expect(OTelLog.isLogSpans(), isTrue);
      expect(OTelLog.isLogExport(), isTrue);
      
      // Use logging methods
      OTelLog.logMetric('Test metric');
      OTelLog.logSpan(createTestSpan(), 'Test span message');
      OTelLog.logSpans([createTestSpan()], 'Test spans message');
      OTelLog.logExport('Test export');
      
      // Verify logs captured
      expect(metricLogs.length, equals(1));
      expect(metricLogs.first, contains('[metric]'));
      expect(metricLogs.first, contains('Test metric'));
      
      expect(spanLogs.length, equals(1));
      expect(spanLogs.first, contains('[spans]'));
      expect(spanLogs.first, contains('Test spans message'));
      
      expect(exportLogs.length, equals(1));
      expect(exportLogs.first, contains('[export]'));
      expect(exportLogs.first, contains('Test export'));
      
      // When function is null, logging is disabled
      OTelLog.metricLogFunction = null;
      OTelLog.spanLogFunction = null;
      OTelLog.exportLogFunction = null;
      
      expect(OTelLog.isLogMetrics(), isFalse);
      expect(OTelLog.isLogSpans(), isFalse);
      expect(OTelLog.isLogExport(), isFalse);
    });
  });
}

/// Create a test span for testing
Span createTestSpan() {
  final tracer = OTel.tracer();
  return tracer.startSpan('test-span');
}
