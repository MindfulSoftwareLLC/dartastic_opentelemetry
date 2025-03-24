// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'package:dartastic_opentelemetry/src/trace/span.dart';
import 'package:dartastic_opentelemetry/src/util/otel_log.dart';
import 'span_exporter.dart';

/// A simple file-based SpanExporter for debugging purposes.
/// This exporter writes spans directly to a file in JSON format.
class TestFileExporter implements SpanExporter {
  final String _filePath;
  bool _isShutdown = false;

  TestFileExporter(this._filePath) {
    // Make sure file exists
    final file = File(_filePath);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Created with file path $_filePath');
  }

  @override
  Future<void> export(List<Span> spans) async {
    if (_isShutdown) {
      if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Cannot export - exporter is shut down');
      throw StateError('Exporter is shutdown');
    }

    if (spans.isEmpty) {
      if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: No spans to export');
      return;
    }

    try {
      final file = File(_filePath);
      
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
          'attributes': span.attributes?.toJson(),
        };
      }).toList();

      // Write to file, appending new spans
      final existingContent = file.existsSync() ? await file.readAsString() : '';
      final content = existingContent.isEmpty 
          ? jsonEncode(jsonSpans) 
          : existingContent + '\n' + jsonEncode(jsonSpans);
      
      await file.writeAsString(content + '\n');
      
      if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Successfully exported ${spans.length} spans');
    } catch (e, stackTrace) {
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
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Force flush requested (no-op)');
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Shutting down');
    _isShutdown = true;
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Shutdown complete');
  }
}
