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

      // Convert spans to JSON
      final jsonSpans = spans.map((span) {
        final attributes = <String, dynamic>{};
        span.attributes.forEach((key, value) {
          attributes[key] = value.toString();
        });

        final events = span.events.map((event) {
          final eventAttrs = <String, dynamic>{};
          event.attributes?.forEach((key, value) {
            eventAttrs[key] = value.toString();
          });

          return {
            'name': event.name,
            'timestamp': event.timestamp.microsecondsSinceEpoch,
            'attributes': eventAttrs
          };
        }).toList();

        return {
          'name': span.name,
          'spanId': span.spanContext.spanId.toString(),
          'traceId': span.spanContext.traceId.toString(),
          'parentSpanId': span.parentSpanId?.toString(),
          'kind': span.kind.toString(),
          'startTime': span.startTime.microsecondsSinceEpoch,
          'endTime': span.endTime?.microsecondsSinceEpoch,
          'status': {
            'code': span.status.code.index,
            'description': span.status.description
          },
          'attributes': attributes,
          'events': events
        };
      }).toList();

      // Append to file
      final encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(jsonSpans);

      // Use AppendString to not overwrite previous spans
      await file.writeAsString('$jsonString\n', mode: FileMode.append);

      if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Successfully exported ${spans.length} spans');
    } catch (e, stackTrace) {
      if (OTelLog.isError()) OTelLog.error('TestFileExporter: Error exporting spans: $e');
      if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> forceFlush() async {
    if (_isShutdown) {
      return;
    }

    if (OTelLog.isDebug()) OTelLog.debug('TestFileExporter: Force flush called - nothing to do for file exporter');
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
