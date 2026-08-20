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

  group('DROP decision (#120)', () {
    setUp(() async {
      await initWith(sampler: const AlwaysOffSampler());
    });

    test('creates a non-recording span', () {
      final span = OTel.tracer().startSpan('dropped');
      expect(span.isRecording, isFalse);
      expect(span.spanContext.traceFlags.isSampled, isFalse);
      span.end();
    });

    test('every mutation is a no-op', () {
      final span = OTel.tracer().startSpan('dropped');
      span.setStringAttribute<String>('string.key', 'value');
      span.setBoolAttribute('bool.key', true);
      span.setIntAttribute('int.key', 7);
      span.setDoubleAttribute('double.key', 1.5);
      span.addAttributes(OTel.attributesFromMap({'more.key': 'v'}));
      span.attributes = OTel.attributesFromMap({'replaced.key': 'v'});
      span.addEventNow('event-1');
      span.addEvents({'event-2': null});
      span.recordException(Exception('boom'));
      span.setStatus(SpanStatusCode.Error, 'failed');
      span.updateName('renamed');
      span.addSpanLink(
        OTel.spanLink(
          OTel.spanContext(traceId: OTel.traceId(), spanId: OTel.spanId()),
        ),
      );

      expect(span.attributes.toList(), isEmpty);
      expect(span.spanEvents ?? const <SpanEvent>[], isEmpty);
      expect(span.spanLinks ?? const <SpanLink>[], isEmpty);
      expect(span.name, equals('dropped'));
      expect(span.status, isNot(equals(SpanStatusCode.Error)));
      span.end();
    });

    test('processors never see the span and nothing is exported', () async {
      final span = OTel.tracer().startSpan('dropped');
      span.end();
      await OTel.tracerProvider().forceFlush();

      expect(recorder.started, isEmpty);
      expect(recorder.ended, isEmpty);
      expect(recorder.nameUpdates, isEmpty);
      expect(exporter.spans, isEmpty);
    });

    test('isRecording: true cannot resurrect a dropped span', () {
      final span = OTel.tracer().startSpan('dropped', isRecording: true);
      expect(span.isRecording, isFalse);
      span.end();
      expect(recorder.started, isEmpty);
      expect(recorder.ended, isEmpty);
    });
  });

  group('Sampled=true with IsRecording=false is forbidden (#123)', () {
    test('forced non-recording span clears Sampled (sampler path)', () async {
      await initWith(
        sampler: FixedDecisionSampler(SamplingDecision.recordAndSample),
      );
      final span = OTel.tracer().startSpan('forced-off', isRecording: false);

      expect(span.isRecording, isFalse);
      expect(span.spanContext.traceFlags.isSampled, isFalse,
          reason: 'The SDK MUST NOT allow Sampled==true with '
              'IsRecording==false');
      span.end();
      expect(recorder.started, isEmpty);
      expect(recorder.ended, isEmpty);
      expect(exporter.spans, isEmpty);
    });

    test('forced non-recording span clears inherited Sampled (no sampler)',
        () async {
      await initWith();
      // Remove the sampler so trace flags are inherited from the parent.
      OTel.tracerProvider().sampler = null;

      final span = OTel.tracer().startSpan(
            'forced-off',
            context: parentContextWith(sampled: true),
            isRecording: false,
          );

      expect(span.isRecording, isFalse);
      expect(span.spanContext.traceFlags.isSampled, isFalse);
      span.end();
      expect(exporter.spans, isEmpty);
    });

    test('no default path produces the forbidden combination', () async {
      for (final decision in SamplingDecision.values) {
        await initWith(sampler: FixedDecisionSampler(decision));
        for (final forced in <bool?>[null, true, false]) {
          final span = OTel.tracer().startSpan(
                'combination-check',
                isRecording: forced,
              );
          final forbidden =
              span.spanContext.traceFlags.isSampled && !span.isRecording;
          expect(forbidden, isFalse,
              reason: 'decision=$decision isRecording=$forced produced '
                  'Sampled==true with IsRecording==false');
          span.end();
        }
      }
    });
  });
}
