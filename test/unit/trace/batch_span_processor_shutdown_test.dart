// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Regression tests for the `BatchSpanProcessor` shutdown drain bug.
///
/// The original `shutdown()` did:
///   1. `_isShutdown = true`
///   2. `_timer?.cancel()`
///   3. `await forceFlush()`
///   4. `await exporter.shutdown()`
///
/// But `forceFlush()` early-returned on `_isShutdown == true`, so step
/// 3 was a no-op — any spans queued at the moment shutdown was called
/// were silently dropped. (The user's repro for #33 happened to call
/// `forceFlush()` before `shutdown()`, which is why the hang was
/// noticed but the data-loss wasn't.)
///
/// `BatchLogRecordProcessor` was already written correctly: drain in a
/// `while (queue.isNotEmpty)` loop *before* setting `_isShutdown`.
/// `BatchSpanProcessor` should match.
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelAPI, Attributes;
import 'package:test/test.dart';

class _RecordingSpanExporter implements SpanExporter {
  final List<Span> exported = [];
  bool _shutdown = false;

  @override
  Future<void> export(List<Span> spans) async {
    if (_shutdown) return;
    exported.addAll(spans);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _shutdown = true;
  }
}

/// Starts and ends a span on [tracer]. The span automatically flows
/// through whatever span processors the tracer's provider has
/// registered — caller does NOT need to call `processor.onEnd` again.
void _emitSpan(Tracer tracer, String name) {
  tracer.startSpan(name).end();
}

void main() {
  group('BatchSpanProcessor.shutdown drains the queue', () {
    late _RecordingSpanExporter exporter;
    late BatchSpanProcessor processor;
    late TracerProvider tracerProvider;
    late Tracer tracer;

    setUp(() async {
      await OTel.reset();
      // Force the API to install the SDK factory so APITracer.startSpan
      // returns the SDK Span (which the BatchSpanProcessor accepts).
      await OTel.initialize(
        serviceName: 'batch-span-shutdown-test',
        detectPlatformResources: false,
        // Use an unreachable endpoint — we don't care, the spans go
        // through our injected exporter via a custom tracer provider
        // below.
        endpoint: 'http://127.0.0.1:1',
      );

      exporter = _RecordingSpanExporter();
      processor = BatchSpanProcessor(
        exporter,
        // Long scheduleDelay so the periodic timer doesn't sneak an
        // export in before we call shutdown — we want shutdown itself
        // to be the only path that drains the queue.
        const BatchSpanProcessorConfig(
          scheduleDelay: Duration(seconds: 60),
          maxExportBatchSize: 100,
        ),
      );

      tracerProvider = OTel.addTracerProvider('drain-test');
      tracerProvider.addSpanProcessor(processor);
      tracer = tracerProvider.getTracer('drain-test');
    });

    tearDown(() async {
      try {
        await tracerProvider.shutdown();
      } catch (_) {}
      await OTel.shutdown();
      await OTel.reset();
    });

    test(
      'shutdown() exports queued spans even when called without a prior '
      'forceFlush() (regression: forceFlush early-returned on _isShutdown)',
      () async {
        _emitSpan(tracer, 'queued-span');
        // Sanity: still queued, not yet exported (timer hasn't fired).
        expect(exporter.exported, isEmpty);

        await processor.shutdown();

        expect(
          exporter.exported.map((s) => s.name).toList(),
          equals(['queued-span']),
          reason: 'shutdown must drain queued spans, not drop them',
        );
      },
    );

    test(
      'shutdown() drains a queue larger than maxExportBatchSize',
      () async {
        // Construct a processor with a small batch size so we can
        // verify multi-batch drain.
        final smallBatchExporter = _RecordingSpanExporter();
        final smallBatchProcessor = BatchSpanProcessor(
          smallBatchExporter,
          const BatchSpanProcessorConfig(
            scheduleDelay: Duration(seconds: 60),
            maxExportBatchSize: 5,
          ),
        );
        final tp = OTel.addTracerProvider('multi-batch-test');
        tp.addSpanProcessor(smallBatchProcessor);
        final t = tp.getTracer('multi-batch-test');

        const total = 23; // > 4× the batch size
        for (var i = 0; i < total; i++) {
          _emitSpan(t, 'span-$i');
        }
        expect(smallBatchExporter.exported, isEmpty);

        await smallBatchProcessor.shutdown();

        expect(
          smallBatchExporter.exported.length,
          equals(total),
          reason: 'shutdown must continue draining until the queue is empty, '
              'not stop after the first batch',
        );
      },
    );

    test(
      'forceFlush() drains a queue larger than maxExportBatchSize',
      () async {
        // Same expectation as shutdown — forceFlush should drain
        // everything, not just one batch.
        final flushExporter = _RecordingSpanExporter();
        final flushProcessor = BatchSpanProcessor(
          flushExporter,
          const BatchSpanProcessorConfig(
            scheduleDelay: Duration(seconds: 60),
            maxExportBatchSize: 4,
          ),
        );
        final tp = OTel.addTracerProvider('forceflush-multi-batch-test');
        tp.addSpanProcessor(flushProcessor);
        final t = tp.getTracer('forceflush-multi-batch-test');

        const total = 17;
        for (var i = 0; i < total; i++) {
          _emitSpan(t, 'span-$i');
        }

        await flushProcessor.forceFlush();

        expect(
          flushExporter.exported.length,
          equals(total),
          reason: 'forceFlush must drain the whole queue, not one batch',
        );

        await flushProcessor.shutdown();
      },
    );
  });
}

/// Strip an unused-import warning when the test runs with no Span/
/// Attributes references — the SDK exports re-export these via a
/// transitive path so the explicit api import is technically extra.
// ignore: unused_element
Attributes _unused() => OTelAPI.attributesFromMap(const <String, Object>{});
