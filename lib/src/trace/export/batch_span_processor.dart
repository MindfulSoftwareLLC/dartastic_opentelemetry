// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:collection';

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';
import 'package:synchronized/synchronized.dart';

import '../../util/otel_log.dart';
import '../span_processor.dart';
import 'span_exporter.dart';

/// Configuration for the [BatchSpanProcessor].
class BatchSpanProcessorConfig {
  /// The maximum queue size for spans. After this is reached,
  /// spans will be dropped.
  final int maxQueueSize;

  /// The delay between two consecutive exports.
  final Duration scheduleDelay;

  /// The maximum batch size of spans that can be exported at once.
  final int maxExportBatchSize;

  /// The amount of time to wait for an export to complete before timing out.
  final Duration exportTimeout;

  const BatchSpanProcessorConfig({
    this.maxQueueSize = 2048,
    this.scheduleDelay = const Duration(milliseconds: 5000),
    this.maxExportBatchSize = 512,
    this.exportTimeout = const Duration(seconds: 30),
  });
}

/// A [SpanProcessor] that batches spans before export.
class BatchSpanProcessor implements SpanProcessor {
  final SpanExporter _exporter;
  final BatchSpanProcessorConfig _config;
  final Queue<Span> _spanQueue = Queue<Span>();
  bool _isShutdown = false;
  Timer? _timer;
  final _lock = Lock();

  BatchSpanProcessor(this._exporter, [BatchSpanProcessorConfig? config])
      : _config = config ?? const BatchSpanProcessorConfig() {
    _timer = Timer.periodic(_config.scheduleDelay, (_) async {
      try {
        await _exportBatch();
      } catch (e) {
        if (OTelLog.isError()) OTelLog.error('Error in batch export timer: $e');
      }
    });
  }

  @override
  Future<void> onEnd(Span span) async {
    if (_isShutdown) {
      return;
    }

    return _lock.synchronized(() {
      if (_spanQueue.length >= _config.maxQueueSize) {
        if (OTelLog.isDebug()) OTelLog.debug('BatchSpanProcessor queue full - dropping span');
        return;
      }
      _spanQueue.add(span);
    });
  }

  @override
  Future<void> onStart(Span span,Context? parentContext) async {
    // Nothing to do on start
  }

  @override
  Future<void> onNameUpdate(Span span, String newName) async {
    // Nothing to do on name update
  }

  Future<void> _exportBatch() async {
    if (_isShutdown) {
      return;
    }

    List<Span> spansToExport = [];

    await _lock.synchronized(() {
      final batchSize = _spanQueue.length > _config.maxExportBatchSize
          ? _config.maxExportBatchSize
          : _spanQueue.length;

      for (var i = 0; i < batchSize; i++) {
        if (_spanQueue.isEmpty) break;
        spansToExport.add(_spanQueue.removeFirst());
      }
    });

    if (spansToExport.isEmpty) {
      return;
    }

    try {
      await _exporter.export(spansToExport);
    } catch (e) {
      if (OTelLog.isError()) OTelLog.error('Error exporting batch of spans: $e');
      // Consider implementing retry logic here
    }
  }

  @override
  Future<void> forceFlush() async {
    if (_isShutdown) {
      return;
    }

    await _exportBatch();
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }

    _isShutdown = true;
    _timer?.cancel();

    // Export any remaining spans
    await forceFlush();

    // Shutdown the exporter
    await _exporter.shutdown();
  }
}
