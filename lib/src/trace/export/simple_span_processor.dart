// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/trace/span_processor.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';

import '../../util/otel_log.dart';
import 'span_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';

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
    if (_isShutdown) {
      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Skipping export - processor is shutdown');
      return;
    }

    if (!span.isRecording) {
      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Skipping export - span is not recording');
      return;
    }
    
    if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Exporting span ${span.spanContext.spanId} with name ${span.name}');
    
    try {
      // Create a copy of the span list to avoid concurrent modification issues
      final spanToExport = [span];
      final Future<void> pendingExport = _spanExporter.export(spanToExport);
      _pendingExports.add(pendingExport);

      // Use unawaited to avoid blocking - we'll still track it in _pendingExports
      pendingExport.then((_) {
        if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Successfully exported span ${span.spanContext.spanId}');
      }).catchError((e, stackTrace) {
        if (OTelLog.isError()) OTelLog.error('SimpleSpanProcessor: Export error while processing span ${span.spanContext.spanId}: $e');
        if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');
      }).whenComplete(() {
        _pendingExports.remove(pendingExport);
      });
    } catch (e, stackTrace) {
      if (OTelLog.isError()) OTelLog.error('SimpleSpanProcessor: Failed to start export for span ${span.spanContext.spanId}: $e');
      if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');
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
      return;
    }
    if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Shutting down - waiting for ${_pendingExports.length} pending exports');
    _isShutdown = true;

    try {
      await Future.wait(_pendingExports);
      await _spanExporter.shutdown();
      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Shutdown complete');
    } catch (e, stackTrace) {
      if (OTelLog.isError()) OTelLog.error('SimpleSpanProcessor: Error during shutdown: $e');
      if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');
    }
  }

  @override
  Future<void> forceFlush() async {
    if (_isShutdown) {
      return;
    }
    if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Force flushing - waiting for ${_pendingExports.length} pending exports');
    try {
      await Future.wait(_pendingExports);
      if (OTelLog.isDebug()) OTelLog.debug('SimpleSpanProcessor: Force flush complete');
    } catch (e, stackTrace) {
      if (OTelLog.isError()) OTelLog.error('SimpleSpanProcessor: Error during force flush: $e');
      if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');
    }
  }
}
