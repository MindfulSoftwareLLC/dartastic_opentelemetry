// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import '../../../dartastic_opentelemetry.dart';

/// A LogRecordExporter that outputs log records to the console.
///
/// This exporter is useful for debugging and development purposes.
/// It formats log records in a human-readable format and prints them.
class ConsoleLogRecordExporter implements LogRecordExporter {
  /// Whether the exporter has been shut down.
  bool _isShutdown = false;

  /// Custom print function, allowing for testing and redirection.
  final void Function(String) _printFunction;

  /// Creates a new ConsoleLogRecordExporter.
  ///
  /// @param printFunction Optional custom print function (defaults to print)
  ConsoleLogRecordExporter({void Function(String)? printFunction})
      : _printFunction = printFunction ?? print;

  @override
  Future<ExportResult> export(List<ReadableLogRecord> logRecords) async {
    if (_isShutdown) {
      return ExportResult.failure;
    }

    for (final logRecord in logRecords) {
      _printLogRecord(logRecord);
    }

    return ExportResult.success;
  }

  void _printLogRecord(ReadableLogRecord logRecord) {
    final buffer = StringBuffer();

    // Format timestamp
    if (logRecord.observedTimestamp != null) {
      final millis = logRecord.observedTimestamp!.toInt() ~/ 1000000;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      buffer.write('[${dateTime.toIso8601String()}] ');
    }

    // Format severity
    if (logRecord.severityNumber != null) {
      buffer.write(
          '[${logRecord.severityText ?? logRecord.severityNumber!.name}] ');
    }

    // Format instrumentation scope
    buffer.write('[${logRecord.instrumentationScope.name}');
    if (logRecord.instrumentationScope.version != null) {
      buffer.write(':${logRecord.instrumentationScope.version}');
    }
    buffer.write('] ');

    // Format event name
    if (logRecord.eventName != null) {
      buffer.write('{${logRecord.eventName}} ');
    }

    // Format body
    if (logRecord.body != null) {
      buffer.write(logRecord.body);
    }

    // Format trace context
    if (logRecord.traceId != null) {
      buffer.write(' [trace_id=${logRecord.traceId}');
      if (logRecord.spanId != null) {
        buffer.write(', span_id=${logRecord.spanId}');
      }
      buffer.write(']');
    }

    // Format resource
    if (logRecord.resource != null) {
      final serviceName =
          _getResourceAttribute(logRecord.resource!, 'service.name');
      if (serviceName != null) {
        buffer.write(' service=$serviceName');
      }
    }

    // Format attributes
    if (logRecord.attributes != null && logRecord.attributes!.length > 0) {
      buffer.write(' {');
      final attrs = logRecord.attributes!.toList();
      for (var i = 0; i < attrs.length; i++) {
        if (i > 0) buffer.write(', ');
        buffer.write('${attrs[i].key}=${attrs[i].value}');
      }
      buffer.write('}');
    }

    _printFunction(buffer.toString());
  }

  String? _getResourceAttribute(Resource resource, String key) {
    for (final attr in resource.attributes.toList()) {
      if (attr.key == key) {
        return attr.value.toString();
      }
    }
    return null;
  }

  @override
  Future<void> forceFlush() async {
    // Console exporter has no buffering, nothing to flush
  }

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }
}
