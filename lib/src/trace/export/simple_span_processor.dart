// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/trace/span.dart';
import 'package:dartastic_opentelemetry/src/trace/span_processor.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'span_exporter.dart';

/// A simple SpanProcessor that exports spans synchronously when they end.
///
/// This processor should only be used for testing or debugging purposes as it
/// blocks until the export is complete.
class SimpleSpanProcessor implements SpanProcessor {
  final SpanExporter _spanExporter;
  bool _isShutdown = false;
  final List<Future<void>> _pendingExports = [];

  /// Creates a new SimpleSpanProcessor that exports spans using the given [SpanExporter].
  SimpleSpanProcessor(this._spanExporter);

  @override
  Future<void> onStart(Span span, Context? parentContext) async {
    if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: onStart called for span ${span.spanContext.spanId}, traceId: ${span.spanContext.traceId}');
  }

  @override
  Future<void> onEnd(Span span) async {
    if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: onEnd called for span ${span.name} with ID ${span.spanContext.spanId}');
    if (_isShutdown) {
      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Skipping export - processor is shutdown');
      print('SimpleSpanProcessor: Skipping export - processor is shutdown');
      return;
    }

    // Verify the span has a valid end time
    if (span.endTime == null) {
      if (OTelLog.isWarn()) OTelLog.warn('SimpleSpanProcessor: Span ${span.name} with ID ${span.spanContext.spanId} has no end time, which suggests it may not be properly ended');
      // Continue with export anyway
    }

    if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Exporting span ${span.spanContext.spanId} with name ${span.name}');

    try {
      // Create a copy of the span list to avoid concurrent modification issues
      final spanToExport = [span];
      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Created list of spans to export');

      final Future<void> pendingExport = _spanExporter.export(spanToExport);
      _pendingExports.add(pendingExport);
      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Added export to pending exports list');

      // Directly await the export for better reliability in tests
      try {
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Awaiting export completion for span ${span.name}');
        await pendingExport;
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Successfully exported span ${span.name} with ID ${span.spanContext.spanId}');
      } catch (e, stackTrace) {
        if (OTelLog.isError()) {
          OTelLog.error('SimpleSpanProcessor: Export error while processing span ${span.spanContext.spanId}: $e');
          OTelLog.error('Stack trace: $stackTrace');
        }
      } finally {
        _pendingExports.remove(pendingExport);
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Removed export from pending list');
      }
    } catch (e, stackTrace) {
      if (OTelLog.isError()) {
        OTelLog.error('SimpleSpanProcessor: Failed to start export for span ${span.spanContext.spanId}: $e');
        OTelLog.error('Stack trace: $stackTrace');
      }
    }
  }

  @override
  Future<void> onNameUpdate(Span span, String newName) async {
    // Simple processor doesn't need to do anything for name updates
    // since it only processes spans when they end
    if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Name updated for span ${span.spanContext.spanId} to $newName');
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Already shut down');
      return;
    }

    if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Shutting down - waiting for ${_pendingExports.length} pending exports');
    _isShutdown = true;

    try {
      if (_pendingExports.isNotEmpty) {
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Waiting for ${_pendingExports.length} pending exports to complete');
        try {
          await Future.wait(_pendingExports);
          if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: All pending exports completed');
        } catch (e) {
          if (OTelLog.isError()) OTelLog.error('SimpleSpanProcessor: Error waiting for pending exports: $e');
        }
      }

      try {
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Shutting down exporter');
        await _spanExporter.shutdown();
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Exporter shutdown complete');
      } catch (e) {
        if (OTelLog.isError()) OTelLog.error('SimpleSpanProcessor: Error shutting down exporter: $e');
      }

      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Shutdown complete');
    } catch (e, stackTrace) {
      if (OTelLog.isError()) {
        OTelLog.error('SimpleSpanProcessor: Error during shutdown: $e');
        OTelLog.error('Stack trace: $stackTrace');
      }
    }
  }

  @override
  Future<void> forceFlush() async {
    if (_isShutdown) {
      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Cannot force flush - processor is shut down');
      return;
    }

    if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Force flushing - waiting for ${_pendingExports.length} pending exports');

    try {
      if (_pendingExports.isEmpty) {
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: No pending exports to flush');
        // If there are no pending exports, just force flush the exporter
        await _spanExporter.forceFlush();
      } else {
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Waiting for ${_pendingExports.length} pending exports');
        await Future.wait(_pendingExports);
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: All pending exports completed');

        // Also force flush the exporter
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Force flushing exporter');
        await _spanExporter.forceFlush();
      }

      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Force flush complete');
    } catch (e, stackTrace) {
      if (OTelLog.isError()) {
        OTelLog.error('SimpleSpanProcessor: Error during force flush: $e');
        OTelLog.error('Stack trace: $stackTrace');
      }
    }
  }
}
