// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'package:dartastic_opentelemetry/src/trace/span.dart';
import 'package:dartastic_opentelemetry/src/util/otel_log.dart';
import 'package:dartastic_opentelemetry/src/trace/export/span_exporter.dart';

/// A simple file-based SpanExporter for testing purposes.
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
      
      // Convert spans to JSON
      final jsonSpans = spans.map((span) {
        return {
          'name': span.name,
          'spanId': span.spanContext.spanId.toString(),
          'traceId': span.spanContext.traceId.toString(),
          'kind': span.kind.index,
          'startTime': span.startTime?.millisecondsSinceEpoch,
          'endTime': span.endTime?.millisecondsSinceEpoch,
          'status': span.status.toString(),
          'attributes': span.attributes?.toJson(),
        };
      }).toList();
      
      // Append to file
      final jsonStr = json.encode(jsonSpans);
      await file.writeAsString('$jsonStr\n', mode: FileMode.append);
      
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
    // Nothing to flush in file exporter
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Force flush called (no-op)');
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Shutting down');
    _isShutdown = true;
  }
}
