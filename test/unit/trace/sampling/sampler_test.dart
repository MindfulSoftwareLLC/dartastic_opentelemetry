// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('AlwaysOnSampler', () {
    setUp(() async {
      await OTel.initialize();
    });

    tearDown(() async {
      await OTel.reset();
    });

    final sampler = const AlwaysOnSampler();

    test('should always sample', () {
      final result = sampler.shouldSample(
        parentContext: OTel.context(),
        traceId: '1234',
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
      expect(result.source, equals(SamplingDecisionSource.tracerConfig));
      expect(result.attributes, isNull);
    });

    test('has correct description', () {
      expect(sampler.description, equals('AlwaysOnSampler'));
    });
  });

  group('ParentBasedSampler', () {
    late ParentBasedSampler sampler;
    late Context rootContext;
    late TraceFlags sampledFlags;
    late TraceFlags notSampledFlags;

    setUp(() async {
      await OTel.initialize();
      sampler = ParentBasedSampler(const AlwaysOnSampler());
      rootContext = OTel.context();
      sampledFlags = OTel.traceFlags(TraceFlags.SAMPLED_FLAG);
      notSampledFlags = OTel.traceFlags(TraceFlags.NONE_FLAG);
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('uses root sampler for invalid parent', () {
      final result = sampler.shouldSample(
        parentContext: rootContext,
        traceId: '1234',
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
      expect(result.source, equals(SamplingDecisionSource.tracerConfig));
    });

    test('respects sampled remote parent', () {
      final parentContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
        traceFlags: sampledFlags,
        isRemote: true,
      );
      final context = rootContext.withSpanContext(parentContext);

      final result = sampler.shouldSample(
        parentContext: context,
        traceId: '1234',
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('respects not sampled remote parent', () {
      final parentContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
        traceFlags: notSampledFlags,
        isRemote: true,
      );
      final context = rootContext.withSpanContext(parentContext);

      final result = sampler.shouldSample(
        parentContext: context,
        traceId: '1234',
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.drop));
    });

    test('respects sampled local parent', () {
      final parentContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
        traceFlags: sampledFlags,
        isRemote: false,
      );
      final context = rootContext.withSpanContext(parentContext);

      final result = sampler.shouldSample(
        parentContext: context,
        traceId: '1234',
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('respects not sampled local parent', () {
      final parentContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
        traceFlags: notSampledFlags,
        isRemote: false,
      );
      final context = rootContext.withSpanContext(parentContext);

      final result = sampler.shouldSample(
        parentContext: context,
        traceId: '1234',
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.drop));
    });

    test('considers parent span kind', () {
      final result = sampler.shouldSample(
        parentContext: rootContext,
        traceId: '1234',
        name: 'test',
        spanKind: SpanKind.server,
        attributes: null,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('considers provided attributes', () {
      final attributes = OTel.attributesFromMap({'test.key': 'test.value'});

      final result = sampler.shouldSample(
        parentContext: rootContext,
        traceId: '1234',
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: attributes,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('considers provided links', () {
      final linkedContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
        traceFlags: sampledFlags,
      );

      final link = OTel.spanLink(linkedContext);

      final result = sampler.shouldSample(
        parentContext: rootContext,
        traceId: '1234',
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: null,
        links: [link],
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });
  });
}
