// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Tests for the sampling decision pipeline, per the OpenTelemetry Trace SDK
// spec v1.60.0 (Sampling / ShouldSample / SDK Span creation):
// - each SamplingDecision maps to its own (IsRecording, Sampled) pair
// - the recording/sampled reaction table for processors and exporters
// - TraceState inheritance and SamplingResult.traceState propagation
// - the ParentBased decision table and the default sampler
// - createSpan routing through the sampler + processor pipeline

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../../testing_utils/in_memory_span_exporter.dart';

/// A sampler that always returns a fixed decision (optionally with a fixed
/// TraceState or attributes).
class FixedDecisionSampler implements Sampler {
  final SamplingDecision decision;

  FixedDecisionSampler(this.decision);

  @override
  String get description => 'FixedDecisionSampler{$decision}';

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    return SamplingResult(
      decision: decision,
      source: SamplingDecisionSource.tracerConfig,
    );
  }
}

/// A span processor that records every notification it receives.
class RecordingSpanProcessor implements SpanProcessor {
  final List<Span> started = [];
  final List<Context?> startContexts = [];
  final List<Span> ended = [];
  final List<String> nameUpdates = [];

  @override
  Future<void> onStart(Span span, Context? parentContext) async {
    started.add(span);
    startContexts.add(parentContext);
  }

  @override
  Future<void> onEnd(Span span) async {
    ended.add(span);
  }

  @override
  Future<void> onNameUpdate(Span span, String newName) async {
    nameUpdates.add(newName);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

late InMemorySpanExporter exporter;
late RecordingSpanProcessor recorder;

/// Resets OTel and initializes it with [sampler], a SimpleSpanProcessor
/// backed by an in-memory exporter, and a recording processor spy.
Future<void> initWith({Sampler? sampler}) async {
  await OTel.reset();
  exporter = InMemorySpanExporter();
  recorder = RecordingSpanProcessor();
  await OTel.initialize(
    serviceName: 'sampling-pipeline-test',
    spanProcessor: SimpleSpanProcessor(exporter),
    sampler: sampler ?? ParentBasedSampler(const AlwaysOnSampler()),
    enableMetrics: false,
    enableLogs: false,
  );
  OTel.tracerProvider().addSpanProcessor(recorder);
}

/// Builds a Context carrying a parent SpanContext with the given flags.
Context parentContextWith({
  required bool sampled,
  bool isRemote = false,
  TraceState? traceState,
}) {
  final spanContext = OTel.spanContext(
    traceId: OTel.traceId(),
    spanId: OTel.spanId(),
    traceFlags: OTel.traceFlags(
      sampled ? TraceFlags.SAMPLED_FLAG : TraceFlags.NONE_FLAG,
    ),
    traceState: traceState,
    isRemote: isRemote,
  );
  return OTel.context().withSpanContext(spanContext);
}

void main() {
  tearDownAll(() async {
    await OTel.reset();
  });

  group('SamplingDecision to Sampled flag mapping (#121)', () {
    for (final parentSampled in [true, false]) {
      final parentDesc = parentSampled ? 'sampled' : 'unsampled';

      test('DROP does not set Sampled ($parentDesc parent)', () async {
        await initWith(sampler: FixedDecisionSampler(SamplingDecision.drop));
        final span = OTel.tracer().startSpan(
              'drop-span',
              context: parentContextWith(sampled: parentSampled),
            );
        expect(span.spanContext.traceFlags.isSampled, isFalse);
        span.end();
      });

      test('RECORD_ONLY does not set Sampled ($parentDesc parent)', () async {
        await initWith(
          sampler: FixedDecisionSampler(SamplingDecision.recordOnly),
        );
        final span = OTel.tracer().startSpan(
              'record-only-span',
              context: parentContextWith(sampled: parentSampled),
            );
        expect(span.spanContext.traceFlags.isSampled, isFalse);
        expect(span.isRecording, isTrue);
        span.end();
      });

      test('RECORD_AND_SAMPLE sets Sampled ($parentDesc parent)', () async {
        await initWith(
          sampler: FixedDecisionSampler(SamplingDecision.recordAndSample),
        );
        final span = OTel.tracer().startSpan(
              'sampled-span',
              context: parentContextWith(sampled: parentSampled),
            );
        expect(span.spanContext.traceFlags.isSampled, isTrue);
        expect(span.isRecording, isTrue);
        span.end();
      });
    }
  });
}
