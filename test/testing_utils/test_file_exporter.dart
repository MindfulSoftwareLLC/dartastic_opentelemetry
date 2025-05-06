// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// A simple file-based SpanExporter for debugging purposes.
/// This exporter writes spans directly to a file in JSON format.
class TestFileExporter implements SpanExporter {
  final String _filePath;
  bool _isShutdown = false;

  TestFileExporter(this._filePath) {
    // Make sure directory exists
    final dir = File(_filePath).parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // Make sure file exists and is empty
    final file = File(_filePath);
    if (!file.existsSync()) {
      file.createSync();
    } else {
      // Clear the file
      file.writeAsStringSync('');
    }
    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Created with file path $_filePath');
  }

  @override
  Future<void> export(List<Span> spans) async {
    print('TestFileExporter: export called with ${spans.length} spans');
    if (_isShutdown) {
      if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Cannot export - exporter is shut down');
      print('TestFileExporter: Cannot export - exporter is shut down');
      throw StateError('Exporter is shutdown');
    }

    if (spans.isEmpty) {
      if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: No spans to export');
      print('TestFileExporter: No spans to export');
      return;
    }

    // Debug information about the spans
    for (var span in spans) {
      print('TestFileExporter: Exporting span ${span.name} with ID ${span.spanContext.spanId} and traceID ${span.spanContext.traceId}');
      print('TestFileExporter:   isRecording: ${span.isRecording}');
      print('TestFileExporter:   isEnded: ${span.isEnded}');
      print('TestFileExporter:   status: ${span.status}');
      print('TestFileExporter:   endTime: ${span.endTime}');

      // Check if the span is properly ended
      if (!span.isEnded) {
        print('TestFileExporter: WARNING - Span ${span.name} is not properly ended, which may cause export issues');
      }
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
          'attributes': span.attributes.toJson(),
          'isEnded': span.isEnded,
        };
      }).toList();

      // Wrap spans in a batch array to match expected format: [[span1, span2, ...], ...]
      final batchedSpans = [jsonSpans];

      // Write to file, appending new spans
      final String newContent = '${jsonEncode(batchedSpans)}\n';

      // Use sync operations to guarantee it gets written
      file.writeAsStringSync(newContent, mode: FileMode.append, flush: true);

      // Verify file was written
      final fileSize = file.lengthSync();
      print('TestFileExporter: Wrote ${newContent.length} bytes to file. File size is now $fileSize bytes');
      print('TestFileExporter: File path: ${file.absolute.path}');

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
