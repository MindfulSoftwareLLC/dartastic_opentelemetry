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
/// TraceState).
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

/// A spec-conformant custom sampler that rewrites the TraceState, in the
/// style of a consistent-probability sampler writing `ot=th:...`.
class TraceStateWritingSampler implements Sampler {
  /// When null, returns an empty TraceState (which clears the span's).
  final Map<String, String> Function(TraceState? parent)? rewrite;

  TraceStateWritingSampler({this.rewrite});

  @override
  String get description => 'TraceStateWritingSampler';

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    final parent = parentContext.spanContext?.traceState;
    return SamplingResult(
      decision: SamplingDecision.recordAndSample,
      source: SamplingDecisionSource.tracerConfig,
      traceState: OTel.traceState(rewrite?.call(parent) ?? const {}),
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

    test('reaction table row (false, true) is unreachable', () async {
      // The spec marks IsRecording==false with Sampled==true "Not
      // allowed"; the sweep below plus the dedicated tests above pin it.
      await initWith(sampler: const AlwaysOffSampler());
      final span = OTel.tracer().startSpan('unreachable-row');
      expect(
        !span.isRecording && span.spanContext.traceFlags.isSampled,
        isFalse,
      );
      span.end();
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

  group('recording/sampled reaction table (#122)', () {
    // Trace SDK spec, Sampling:
    // | IsRecording | Sampled | Processor receives? | Exporter receives? |
    // | true        | true    | true                | true               |
    // | true        | false   | true                | false              |
    // | false       | true    | Not allowed         | Not allowed        |
    // | false       | false   | false               | false              |

    test('RECORD_AND_SAMPLE: processors and exporters receive the span',
        () async {
      await initWith(
        sampler: FixedDecisionSampler(SamplingDecision.recordAndSample),
      );
      final span = OTel.tracer().startSpan('row-true-true');
      span.end();
      await OTel.tracerProvider().forceFlush();

      expect(recorder.started, hasLength(1));
      expect(recorder.ended, hasLength(1));
      expect(exporter.spans.map((s) => s.name), contains('row-true-true'));
    });

    test('RECORD_ONLY: processors receive the span, exporters do not',
        () async {
      await initWith(
        sampler: FixedDecisionSampler(SamplingDecision.recordOnly),
      );
      final span = OTel.tracer().startSpan('row-true-false');
      expect(span.isRecording, isTrue);
      expect(span.spanContext.traceFlags.isSampled, isFalse);
      span.end();
      await OTel.tracerProvider().forceFlush();

      expect(recorder.started, hasLength(1));
      expect(recorder.ended, hasLength(1));
      expect(exporter.spans, isEmpty,
          reason: 'exporters SHOULD NOT receive unsampled spans');
    });

    test('DROP: neither processors nor exporters receive the span', () async {
      await initWith(sampler: FixedDecisionSampler(SamplingDecision.drop));
      final span = OTel.tracer().startSpan('row-false-false');
      span.end();
      await OTel.tracerProvider().forceFlush();

      expect(recorder.started, isEmpty);
      expect(recorder.ended, isEmpty);
      expect(exporter.spans, isEmpty);
    });

    test('BatchSpanProcessor also gates unsampled spans off the exporter',
        () async {
      await OTel.reset();
      final batchExporter = InMemorySpanExporter();
      await OTel.initialize(
        serviceName: 'sampling-pipeline-test',
        spanProcessor: BatchSpanProcessor(
          batchExporter,
          const BatchSpanProcessorConfig(
            scheduleDelay: Duration(milliseconds: 20),
          ),
        ),
        sampler: FixedDecisionSampler(SamplingDecision.recordOnly),
        enableMetrics: false,
        enableLogs: false,
      );

      OTel.tracer().startSpan('batch-unsampled').end();
      await OTel.tracerProvider().forceFlush();
      expect(batchExporter.spans, isEmpty);

      // Sanity check: a sampled span does flow through the same pipeline.
      OTel.tracerProvider().sampler =
          FixedDecisionSampler(SamplingDecision.recordAndSample);
      OTel.tracer().startSpan('batch-sampled').end();
      await OTel.tracerProvider().forceFlush();
      expect(batchExporter.spans.map((s) => s.name), contains('batch-sampled'));
    });

    test('onStart receives the resolved parent context, never null', () async {
      await initWith();
      final parentContext = parentContextWith(sampled: true);
      final span = OTel.tracer().startSpan('ctx-check', context: parentContext);
      expect(recorder.startContexts, hasLength(1));
      expect(recorder.startContexts.single, isNotNull);
      expect(
        recorder.startContexts.single!.spanContext,
        equals(parentContext.spanContext),
      );
      span.end();

      // With no explicit context the resolved Context.current is passed.
      recorder.startContexts.clear();
      final rootSpan = OTel.tracer().startSpan('ctx-check-root');
      expect(recorder.startContexts.single, isNotNull);
      rootSpan.end();
    });
  });

  group('TraceState inheritance (#124)', () {
    test('child spans inherit the parent TraceState', () async {
      await initWith();
      final traceState = OTel.traceState({'vendor': 'value', 'ot': 'th:0'});

      // Remote parent (e.g. extracted from W3C headers).
      final remoteCtx = parentContextWith(
        sampled: true,
        isRemote: true,
        traceState: traceState,
      );
      final childOfRemote =
          OTel.tracer().startSpan('child-of-remote', context: remoteCtx);
      expect(childOfRemote.spanContext.traceState?.get('vendor'), 'value');
      expect(childOfRemote.spanContext.traceState?.get('ot'), 'th:0');

      // Local parent: the child of childOfRemote inherits transitively.
      final grandChild = OTel.tracer().startSpan(
        'grandchild',
        parentSpan: childOfRemote,
      );
      expect(grandChild.spanContext.traceState?.get('vendor'), 'value');
      grandChild.end();
      childOfRemote.end();
    });

    test('span without a parent has no inherited TraceState', () async {
      await initWith();
      final root = OTel.tracer().startSpan('root');
      expect(root.spanContext.traceState?.entries ?? const <String, String>{},
          isEmpty);
      root.end();
    });
  });

  group('SamplingResult.traceState (#125)', () {
    test('built-in samplers return the passed-in TraceState unchanged', () {
      final parentTraceState = OTel.traceState({'vendor': 'value'});
      final parentContext =
          parentContextWith(sampled: true, traceState: parentTraceState);

      final samplers = <Sampler>[
        const AlwaysOnSampler(),
        const AlwaysOffSampler(),
        ParentBasedSampler(const AlwaysOnSampler()),
        TraceIdRatioSampler(1.0),
        ProbabilitySampler(1.0),
        CountingSampler(1),
        const CompositeSampler.and([AlwaysOnSampler()]),
      ];
      for (final sampler in samplers) {
        final result = sampler.shouldSample(
          parentContext: parentContext,
          traceId: OTel.traceId().toString(),
          name: 'span',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );
        expect(result.traceState?.get('vendor'), 'value',
            reason: '${sampler.description} must return the passed-in '
                'TraceState');
      }
    });

    test('the sampler-returned TraceState lands on the new SpanContext',
        () async {
      await initWith(
        sampler: TraceStateWritingSampler(
          rewrite: (parent) => {...?parent?.entries, 'ot': 'th:8'},
        ),
      );
      final parentCtx = parentContextWith(
        sampled: true,
        traceState: OTel.traceState({'vendor': 'value'}),
      );
      final span = OTel.tracer().startSpan('rewritten', context: parentCtx);

      expect(span.spanContext.traceState?.get('ot'), 'th:8');
      expect(span.spanContext.traceState?.get('vendor'), 'value');
      span.end();
    });

    test('an empty returned TraceState clears the inherited one', () async {
      await initWith(sampler: TraceStateWritingSampler());
      final parentCtx = parentContextWith(
        sampled: true,
        traceState: OTel.traceState({'vendor': 'value'}),
      );
      final span = OTel.tracer().startSpan('cleared', context: parentCtx);

      expect(span.spanContext.traceState?.entries ?? const <String, String>{},
          isEmpty);
      span.end();
    });

    test('a null traceState (legacy sampler) keeps parent inheritance',
        () async {
      await initWith(
        sampler: FixedDecisionSampler(SamplingDecision.recordAndSample),
      );
      final parentCtx = parentContextWith(
        sampled: true,
        traceState: OTel.traceState({'vendor': 'value'}),
      );
      final span = OTel.tracer().startSpan('inherited', context: parentCtx);

      expect(span.spanContext.traceState?.get('vendor'), 'value');
      span.end();
    });
  });

  group('default sampler is ParentBased(root=AlwaysOn) (#126)', () {
    /// Initializes without a sampler argument so the SDK default applies.
    Future<void> initWithDefaults() async {
      await OTel.reset();
      exporter = InMemorySpanExporter();
      recorder = RecordingSpanProcessor();
      await OTel.initialize(
        serviceName: 'sampling-pipeline-test',
        spanProcessor: SimpleSpanProcessor(exporter),
        enableMetrics: false,
        enableLogs: false,
      );
      OTel.tracerProvider().addSpanProcessor(recorder);
    }

    test('the default sampler is ParentBased with an AlwaysOn root', () async {
      await initWithDefaults();
      final sampler = OTel.tracerProvider().sampler;
      expect(sampler, isA<ParentBasedSampler>());
      expect(sampler!.description, 'ParentBased{root=AlwaysOnSampler}');
    });

    test('root spans are sampled', () async {
      await initWithDefaults();
      final span = OTel.tracer().startSpan('root');
      expect(span.spanContext.traceFlags.isSampled, isTrue);
      expect(span.isRecording, isTrue);
      span.end();
      expect(exporter.spans.map((s) => s.name), contains('root'));
    });

    // The ParentBased decision table, end to end through startSpan:
    // remote/local x sampled/unsampled.
    for (final isRemote in [true, false]) {
      final kindDesc = isRemote ? 'remote' : 'local';

      test('child of a $kindDesc sampled parent is sampled', () async {
        await initWithDefaults();
        final span = OTel.tracer().startSpan(
          'child-$kindDesc-sampled',
          context: parentContextWith(sampled: true, isRemote: isRemote),
        );
        expect(span.spanContext.traceFlags.isSampled, isTrue);
        expect(span.isRecording, isTrue);
        span.end();
        expect(exporter.spans, hasLength(1));
      });

      test('child of a $kindDesc unsampled parent is dropped', () async {
        await initWithDefaults();
        final span = OTel.tracer().startSpan(
          'child-$kindDesc-unsampled',
          context: parentContextWith(sampled: false, isRemote: isRemote),
        );
        expect(span.spanContext.traceFlags.isSampled, isFalse);
        expect(span.isRecording, isFalse);
        span.end();
        expect(recorder.started, isEmpty);
        expect(exporter.spans, isEmpty);
      });
    }
  });

  group('createSpan goes through the sampling pipeline (#129)', () {
    test('createSpan queries the sampler - a DROP span is inert', () async {
      await initWith(sampler: const AlwaysOffSampler());
      final span = OTel.tracer().createSpan(name: 'created-dropped');

      expect(span.isRecording, isFalse);
      expect(span.spanContext.traceFlags.isSampled, isFalse);
      span.setStringAttribute<String>('key', 'value');
      expect(span.attributes.toList(), isEmpty);

      span.end();
      expect(recorder.started, isEmpty);
      expect(recorder.ended, isEmpty);
      expect(exporter.spans, isEmpty);
    });

    test('createSpan notifies processors and exports sampled spans', () async {
      await initWith();
      final span = OTel.tracer().createSpan(name: 'created-sampled');

      expect(span.isRecording, isTrue);
      expect(span.spanContext.traceFlags.isSampled, isTrue);
      expect(recorder.started, hasLength(1),
          reason: 'processors must see createSpan spans start');

      span.end();
      await OTel.tracerProvider().forceFlush();
      expect(recorder.ended, hasLength(1));
      expect(exporter.spans.map((s) => s.name), contains('created-sampled'));
    });

    test('createSpan RECORD_ONLY reaches processors but not exporters',
        () async {
      await initWith(
        sampler: FixedDecisionSampler(SamplingDecision.recordOnly),
      );
      final span = OTel.tracer().createSpan(name: 'created-record-only');
      expect(span.isRecording, isTrue);
      expect(span.spanContext.traceFlags.isSampled, isFalse);
      span.end();
      await OTel.tracerProvider().forceFlush();

      expect(recorder.started, hasLength(1));
      expect(recorder.ended, hasLength(1));
      expect(exporter.spans, isEmpty);
    });

    test('an explicit spanContext is honored verbatim', () async {
      await initWith();
      final explicit = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556677'),
      );
      final span = OTel.tracer().createSpan(
        name: 'created-explicit',
        spanContext: explicit,
      );

      expect(span.spanContext.traceId, equals(explicit.traceId));
      expect(span.spanContext.spanId, equals(explicit.spanId));
      // The sampler still ran and the processors saw the span.
      expect(span.isRecording, isTrue);
      expect(recorder.started, hasLength(1));
      span.end();
    });
  });
}
