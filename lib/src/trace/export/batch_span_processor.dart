// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:collection';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:synchronized/synchronized.dart';

import '../../environment/otel_env.dart';
import '../span.dart';
import '../span_processor.dart';
import 'span_exporter.dart';

/// Configuration for the [BatchSpanProcessor].
///
/// This class configures how the batch span processor behaves, including
/// queue size limits, export scheduling, and batch size parameters.
class BatchSpanProcessorConfig {
  /// Stand-in for "no limit": `OTEL_BSP_EXPORT_TIMEOUT=0` means no timeout
  /// per spec, represented as the max milliseconds in a 32-bit integer
  /// (~24.8 days). Web-safe (as microseconds it is far below JS's 2^53
  /// safe-integer limit, so it behaves identically on VM, dart2js, and wasm)
  /// and within Dart timer limits for `Future.timeout()`.
  static const Duration noLimit = Duration(milliseconds: 0x7FFFFFFF);

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

  /// Creates a configuration by reading `OTEL_BSP_*` environment variables
  /// via [OTelEnv]. Falls back to standard OTel defaults if variables are
  /// missing or invalid.
  ///
  /// | Environment Variable              | Type     | Default  | Notes                                                    |
  /// |-----------------------------------|----------|----------|----------------------------------------------------------|
  /// | `OTEL_BSP_SCHEDULE_DELAY`         | Duration | `5000`   | Delay between exports (ms). 0 is valid (export ASAP).    |
  /// | `OTEL_BSP_EXPORT_TIMEOUT`         | Timeout  | `30000`  | Export timeout (ms). 0 means no limit.                   |
  /// | `OTEL_BSP_MAX_QUEUE_SIZE`         | Integer  | `2048`   | Maximum span queue size.                                 |
  /// | `OTEL_BSP_MAX_EXPORT_BATCH_SIZE`  | Integer  | `512`    | Maximum batch size. Must be ≤ `MAX_QUEUE_SIZE`.          |
  ///
  /// Invalid or out-of-range values emit an [OTelLog.warn] diagnostic and
  /// fall back to the spec default.
  factory BatchSpanProcessorConfig.fromEnvironment() {
    final env = OTelEnv.getBspConfig();

    var queueSize = (env['maxQueueSize'] as int?) ?? 2048;
    var batchSize = (env['maxExportBatchSize'] as int?) ?? 512;

    // --- scheduleDelay ---
    // Spec type: Duration. Zero is valid ("export as fast as possible").
    // Negative values MUST warn and fall back to default.
    Duration scheduleDelay;
    if (env['scheduleDelay'] is Duration) {
      final delay = env['scheduleDelay'] as Duration;
      if (delay.inMilliseconds >= 0) {
        scheduleDelay = delay;
      } else {
        if (OTelLog.isWarn()) {
          OTelLog.warn('BatchSpanProcessorConfig: Negative '
              'OTEL_BSP_SCHEDULE_DELAY (${delay.inMilliseconds} ms) is '
              'invalid per spec, using default 5000 ms.');
        }
        scheduleDelay = const Duration(milliseconds: 5000);
      }
    } else {
      scheduleDelay = const Duration(milliseconds: 5000);
    }

    // --- exportTimeout ---
    // Spec type: Timeout. Zero means "no limit" — substitute a very large
    // duration. Negative values MUST warn and fall back to default.
    Duration exportTimeout;
    if (env['exportTimeout'] is Duration) {
      final timeout = env['exportTimeout'] as Duration;
      if (timeout.inMilliseconds == 0) {
        exportTimeout = noLimit;
      } else if (timeout.inMilliseconds > 0) {
        exportTimeout = timeout;
      } else {
        if (OTelLog.isWarn()) {
          OTelLog.warn('BatchSpanProcessorConfig: Negative '
              'OTEL_BSP_EXPORT_TIMEOUT (${timeout.inMilliseconds} ms) is '
              'invalid per spec, using default 30000 ms.');
        }
        exportTimeout = const Duration(milliseconds: 30000);
      }
    } else {
      exportTimeout = const Duration(milliseconds: 30000);
    }

    // --- Validation Logic ---
    if (queueSize <= 0) {
      if (OTelLog.isWarn()) {
        OTelLog.warn('BatchSpanProcessorConfig: Non-positive '
            'OTEL_BSP_MAX_QUEUE_SIZE ($queueSize) is invalid per spec, '
            'using default 2048.');
      }
      queueSize = 2048;
    }
    if (batchSize <= 0) {
      if (OTelLog.isWarn()) {
        OTelLog.warn('BatchSpanProcessorConfig: Non-positive '
            'OTEL_BSP_MAX_EXPORT_BATCH_SIZE ($batchSize) is invalid per '
            'spec, using default 512.');
      }
      batchSize = 512;
    }
    // Spec rule: maxExportBatchSize must be less than or equal to maxQueueSize
    if (batchSize > queueSize) {
      batchSize = queueSize;
    }

    return BatchSpanProcessorConfig(
      maxQueueSize: queueSize,
      maxExportBatchSize: batchSize,
      scheduleDelay: scheduleDelay,
      exportTimeout: exportTimeout,
    );
  }
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
      await exporter.export(spansToExport).timeout(_config.exportTimeout);
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
