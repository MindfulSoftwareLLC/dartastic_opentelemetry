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
    print('TestFileExporter: Created with file path $_filePath');
  }

  @override
  Future<void> export(List<Span> spans) async {
    if (_isShutdown) {
      print('TestFileExporter: Cannot export - exporter is shut down');
      throw StateError('Exporter is shutdown');
    }

    if (spans.isEmpty) {
      print('TestFileExporter: No spans to export');
      return;
    }

    try {
      final file = File(_filePath);
      
      print('TestFileExporter: Exporting ${spans.length} spans to $_filePath');
      
      // Convert spans to JSON
      final jsonSpans = spans.map((span) {
        final attrs = <String, dynamic>{};
        if (span.attributes != null) {
          span.attributes!.forEach((key, value) {
            attrs[key] = value;
          });
        }
        
        return {
          'name': span.name,
          'spanId': span.spanContext.spanId.toString(),
          'traceId': span.spanContext.traceId.toString(),
          'kind': span.kind.toString(),
          'startTime': span.startTime?.toIso8601String(),
          'endTime': span.endTime?.toIso8601String(),
          'attributes': attrs,
          'status': span.status != null 
              ? {'code': span.status!.code.index, 'description': span.status!.description} 
              : null,
          'events': span.events.map((e) => {
            'name': e.name,
            'timestamp': e.timestamp?.toIso8601String(),
          }).toList(),
        };
      }).toList();
      
      // Write to file, appending if it exists
      final jsonString = jsonEncode(jsonSpans);
      
      // Append to file, with each export on a new line
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        file.writeAsStringSync(content + '\n' + jsonString);
      } else {
        file.writeAsStringSync(jsonString);
      }
      
      print('TestFileExporter: Successfully exported ${spans.length} spans to $_filePath');
      
    } catch (e, stackTrace) {
      print('TestFileExporter: Error exporting spans: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> forceFlush() async {
    // No buffering in this exporter, so nothing to flush
    print('TestFileExporter: Force flush requested (no-op)');
    return;
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }
    print('TestFileExporter: Shutting down');
    _isShutdown = true;
  }
}
