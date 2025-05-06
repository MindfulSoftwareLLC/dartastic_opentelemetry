// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' show OTelLog;
import 'package:dartastic_opentelemetry/src/trace/span.dart';
import 'span_exporter.dart';

/// A simple file-based SpanExporter for debugging purposes.
/// This exporter writes spans directly to a file in JSON format.
class TestFileExporter implements SpanExporter {
  final String _filePath;
  bool _isShutdown = false;

  /// Creates a new TestFileExporter that writes spans to the specified file path.
  /// 
  /// This constructor creates or clears the target file and writes an initialization
  /// marker. It also creates parent directories if they don't exist.
  /// 
  /// @param filePath The path to the file where spans will be written
  TestFileExporter(this._filePath) {
    print('Creating TestFileExporter with path: $_filePath');
    
    // Create parent directories if they don't exist
    final dir = Directory(File(_filePath).parent.path);
    if (!dir.existsSync()) {
      print('Creating parent directory: ${dir.path}');
      dir.createSync(recursive: true);
    }
    
    // Create or clear the file
    try {
      final file = File(_filePath);
      if (!file.existsSync()) {
        print('Creating new file at: $_filePath');
        file.createSync(recursive: true);
      } else {
        print('File already exists, clearing content');
        file.writeAsStringSync('');
      }
      
      // Test file access
      file.writeAsStringSync('TestFileExporter initialized\n');
      print('Successfully wrote initialization marker to file');
    } catch (e) {
      print('Error initializing file: $e');
    }
    
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Created with file path $_filePath');
  }

  @override
  Future<void> export(List<Span> spans) async {
    if (_isShutdown) {
      print('TestFileExporter: Cannot export - exporter is shut down');
      if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Cannot export - exporter is shut down');
      throw StateError('Exporter is shutdown');
    }

    if (spans.isEmpty) {
      print('TestFileExporter: No spans to export');
      if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: No spans to export');
      return;
    }

    try {
      final file = File(_filePath);
      
      print('TestFileExporter: Exporting ${spans.length} spans to $_filePath');
      if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Exporting ${spans.length} spans to $_filePath');
      
      // Convert spans to simplified JSON - avoiding properties that might not be accessible
      final jsonSpans = spans.map((span) {
        return {
          'name': span.name,
          'spanId': span.spanContext.spanId.toString(),
          'traceId': span.spanContext.traceId.toString(),
          'kind': span.kind.toString(),
          'startTime': span.startTime.toIso8601String(),
          'endTime': span.endTime?.toIso8601String(),
          'status': span.status.toString(),
          // ignore: invalid_use_of_visible_for_testing_member
          'attributes': span.attributes.toJson(),
        };
      }).toList();

      // Write to file, using synchronous operations to ensure completion
      final jsonStr = jsonEncode(jsonSpans);
      file.writeAsStringSync('$jsonStr\n', mode: FileMode.append, flush: true);
      
      print('TestFileExporter: Successfully exported ${spans.length} spans');
      if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Successfully exported ${spans.length} spans');
    } catch (e, stackTrace) {
      print('TestFileExporter ERROR: Failed to export spans: $e');
      print('Stack trace: $stackTrace');
      if (OTelLog.isError()) {
        OTelLog.error('TestFileExporter: Failed to export spans: $e');
        OTelLog.error('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  @override
  Future<void> forceFlush() async {
    // No buffering in this exporter, so nothing to flush
    print('TestFileExporter: Force flush requested (no-op)');
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Force flush requested (no-op)');
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    
    print('TestFileExporter: Shutting down');
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Shutting down');
    _isShutdown = true;
    print('TestFileExporter: Shutdown complete');
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Shutdown complete');
  }
}
