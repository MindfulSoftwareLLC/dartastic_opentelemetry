// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/trace/export/span_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';

/// A simple span exporter that prints spans to the console.
/// 
/// This exporter is primarily used for debugging and testing, as it formats
/// and prints span information to the standard output rather than sending them
/// to a telemetry backend.
/// 
/// The output includes span name, trace ID, span ID, parent span ID, duration,
/// status, and attributes for better debugging visibility.
class ConsoleExporter extends SpanExporter {
  @override
  Future<void> export(List<Span> spans) async {
    for (final span in spans) {
      _printSpan(span);
    }
  }

  void _printSpan(Span span) {
    final buffer = StringBuffer();
    buffer.writeln('=== OpenTelemetry Span ===');
    buffer.writeln('Name: ${span.name}');
    buffer.writeln('Trace ID: ${span.spanContext.traceId}');
    buffer.writeln('Span ID: ${span.spanContext.spanId}');
    
    if (span.spanContext.parentSpanId != null && span.spanContext.parentSpanId!.isValid) {
      buffer.writeln('Parent Span ID: ${span.spanContext.parentSpanId}');
    } else {
      buffer.writeln('Parent Span ID: (root span)');
    }
    
    buffer.writeln('Kind: ${span.kind}');
    buffer.writeln('Status: ${span.status}');
    
    if (span.statusDescription != null) {
      buffer.writeln('Status Description: ${span.statusDescription}');
    }
    
    buffer.writeln('Start Time: ${span.startTime.toIso8601String()}');
    
    if (span.endTime != null) {
      buffer.writeln('End Time: ${span.endTime!.toIso8601String()}');
      final duration = span.endTime!.difference(span.startTime);
      buffer.writeln('Duration: ${duration.inMicroseconds}μs (${duration.inMilliseconds}ms)');
    } else {
      buffer.writeln('End Time: (not ended)');
    }
    
    // Print attributes if any
    // ignore: invalid_use_of_visible_for_testing_member
    final attributes = span.attributes.toList();
    if (attributes.isNotEmpty) {
      buffer.writeln('Attributes:');
      for (final attr in attributes) {
        buffer.writeln('  ${attr.key}: ${attr.value}');
      }
    }
    
    // Print events if any
    final events = span.spanEvents;
    if (events != null && events.isNotEmpty) {
      buffer.writeln('Events:');
      for (final event in events) {
        buffer.writeln('  ${event.timestamp.toIso8601String()}: ${event.name}');
        if (event.attributes != null) {
          for (final attr in event.attributes!.toList()) {
            buffer.writeln('    ${attr.key}: ${attr.value}');
          }
        }
      }
    }
    
    // Print links if any
    final links = span.spanLinks;
    if (links != null && links.isNotEmpty) {
      buffer.writeln('Links:');
      for (final link in links) {
        buffer.writeln('  -> Trace: ${link.spanContext.traceId}, Span: ${link.spanContext.spanId}');
        for (final attr in link.attributes.toList()) {
          buffer.writeln('    ${attr.key}: ${attr.value}');
        }
            }
    }
    
    buffer.writeln('==========================');
    print(buffer);
  }

  @override
  Future<void> forceFlush() async {
    // ConsoleExporter writes immediately, so nothing to flush
  }

  @override
  Future<void> shutdown() async {
    // ConsoleExporter has no resources to clean up
  }
}
