// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:collection';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:synchronized/synchronized.dart';

import '../span.dart';
import '../span_processor.dart';
import 'span_exporter.dart';

/// Configuration for the [BatchSpanProcessor].
///
/// This class configures how the batch span processor behaves, including
/// queue size limits, export scheduling, and batch size parameters.
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

  /// Creates a new configuration for a [BatchSpanProcessor].
  ///
  /// [maxQueueSize] The maximum number of spans that can be queued for export. Default is 2048.
  ///    If this limit is reached, additional spans will be dropped.
  /// [scheduleDelay] The time interval between two consecutive exports. Default is 5 seconds.
  ///    This controls how frequently batches are sent to the exporter.
  /// [maxExportBatchSize] The maximum number of spans to export in a single batch. Default is 512.
  ///    This helps control resource usage during export operations.
  /// [exportTimeout] The maximum time to wait for an export operation to complete. Default is 30 seconds.
  ///    After this time, export operations will be considered failed.
  const BatchSpanProcessorConfig({
    this.maxQueueSize = 2048,
    this.scheduleDelay = const Duration(milliseconds: 5000),
    this.maxExportBatchSize = 512,
    this.exportTimeout = const Duration(seconds: 30),
  });
}

/// A [SpanProcessor] that batches spans before export.
///
/// This processor collects finished spans in a queue and exports them in batches
/// at regular intervals, improving efficiency compared to exporting each span
/// individually. Spans are added to a queue when they end, and periodically sent
/// to the configured exporter in batches according to the configured schedule.
///
/// The batch behavior can be tuned using [BatchSpanProcessorConfig] to control
/// batch size, queue limits, and export timing.
class BatchSpanProcessor implements SpanProcessor {
  /// The exporter used to send spans to the backend
  final SpanExporter exporter;

  /// Configuration for the batch processor behavior
  final BatchSpanProcessorConfig _config;

  /// Queue of spans waiting to be exported
  final Queue<Span> _spanQueue = Queue<Span>();

  /// Whether the processor has been shut down
  bool _isShutdown = false;

  /// Timer for scheduling periodic exports
  Timer? _timer;

  /// Lock for synchronizing queue access
  final _lock = Lock();

  /// Creates a new BatchSpanProcessor with the specified exporter and configuration.
  ///
  /// The BatchSpanProcessor collects finished spans in a queue and exports them in batches
  /// at regular intervals. This improves efficiency compared to exporting each span individually.
  ///
  /// A timer is started when this processor is created based on the [config]'s scheduleDelay.
  /// The timer triggers periodic batch exports of completed spans to the configured exporter.
  ///
  /// When the maximum queue size is reached, new spans will be dropped and not exported.
  ///
  /// This processor does not modify spans on start or when their names are updated,
  /// it only processes spans when they end.
  ///
  /// If an error occurs during export, it will be logged but not propagated.
  ///
  /// [exporter] The SpanExporter to use for exporting batches of spans
  /// [config] Optional configuration for the batch processor
  BatchSpanProcessor(this.exporter, [BatchSpanProcessorConfig? config])
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
        if (OTelLog.isDebug()) {
          OTelLog.debug('BatchSpanProcessor queue full - dropping span');
        }
        return;
      }
      _spanQueue.add(span);
    });
  }

  @override
  Future<void> onStart(Span span, Context? parentContext) async {
    // Nothing to do on start
  }

  @override
  Future<void> onNameUpdate(Span span, String newName) async {
    // Nothing to do on name update
  }

  /// Periodic export path: called by the timer. Exports up to one batch
  /// of [BatchSpanProcessorConfig.maxExportBatchSize] spans and returns.
  /// No-op once [_isShutdown] is set.
  Future<void> _exportBatch() async {
    if (_isShutdown) {
      return;
    }
    await _exportSingleBatch();
  }

  /// Pulls up to [BatchSpanProcessorConfig.maxExportBatchSize] spans
  /// off the queue and hands them to the exporter. Bypasses the
  /// [_isShutdown] check so it remains usable from inside [shutdown]
  /// (which sets the flag last). Returns true if any spans were
  /// exported, false if the queue was empty or the exporter threw.
  Future<bool> _exportSingleBatch() async {
    final spansToExport = <Span>[];

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
      return false;
    }

    try {
      await exporter.export(spansToExport);
      return true;
    } catch (e) {
      if (OTelLog.isError()) {
        OTelLog.error('Error exporting batch of spans: $e');
      }
      // Bail out — don't loop forever on a broken exporter.
      return false;
    }
  }

  /// Drains the queue completely, in batches. Used by [forceFlush] and
  /// [shutdown]. Stops on the first export failure (so a broken
  /// exporter can't wedge shutdown forever).
  Future<void> _drainQueue() async {
    while (_spanQueue.isNotEmpty) {
      final exported = await _exportSingleBatch();
      if (!exported) break;
    }
  }

  @override
  Future<void> forceFlush() async {
    if (_isShutdown) {
      return;
    }
    await _drainQueue();
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) {
      return;
    }

    // Stop the periodic timer first so it can't race with our drain.
    _timer?.cancel();

    // Drain queued spans BEFORE setting `_isShutdown` — otherwise the
    // `_isShutdown` early-return inside `_exportBatch` would skip them.
    // `_drainQueue` calls `_exportSingleBatch` directly so it's
    // unaffected by the flag in any case, but the ordering keeps the
    // behavior obvious.
    await _drainQueue();

    _isShutdown = true;

    // Shutdown the exporter
    await exporter.shutdown();
  }
}
