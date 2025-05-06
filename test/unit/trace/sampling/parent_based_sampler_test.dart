// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('ParentBasedSampler Tests', () {
    late ParentBasedSampler sampler;
    late Sampler rootSampler;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
      );
      // Use TraceIdRatioSampler(0.5) as the root sampler for testing
      rootSampler = TraceIdRatioSampler(0.5);
      sampler = ParentBasedSampler(rootSampler);
    });

    test('description returns expected value', () {
      expect(sampler.description,
          equals('ParentBased{root=${rootSampler.description}}'));
    });

    test('uses root sampler when parent is absent', () {
      final emptyContext = OTelAPI.context();
      const traceId =
          '00000000000000000000000000000001'; // A low trace ID that should be sampled by 0.5 ratio sampler

      final result = sampler.shouldSample(
        parentContext: emptyContext,
        traceId: traceId,
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      // The result should match what the root sampler would decide
      final rootResult = rootSampler.shouldSample(
        parentContext: emptyContext,
        traceId: traceId,
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result.decision, equals(rootResult.decision));
    });

    test('uses remoteParentSampled for remote sampled parent', () {
      // Create a context with a remote sampled parent
      final spanContext = OTel.spanContext(
        traceId: OTel.traceIdFrom('00000000000000000000000000000001'),
        spanId: OTel.spanIdFrom('0000000000000001'),
        traceFlags: TraceFlags.sampled,
        traceState: OTel.traceState({}),
        isRemote: true,
      );

      final parentContext = OTelAPI.context().withSpanContext(spanContext);

      final result = sampler.shouldSample(
        parentContext: parentContext,
        traceId: spanContext.traceId.hexString,
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      // Should always sample because default remoteParentSampled is AlwaysOnSampler
      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('uses remoteParentNotSampled for remote not-sampled parent', () {
      // Create a context with a remote not-sampled parent
      final spanContext = OTel.spanContext(
        traceId: OTel.traceIdFrom('00000000000000000000000000000001'),
        spanId:  OTel.spanIdFrom('0000000000000001'),
        traceFlags: OTel.traceFlags(0),
        // Not sampled
        traceState: OTel.traceState({}),
        isRemote: true,
      );

      final parentContext = OTelAPI.context().withSpanContext(spanContext);

      final result = sampler.shouldSample(
        parentContext: parentContext,
        traceId: spanContext.traceId.hexString,
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      // Should never sample because default remoteParentNotSampled is AlwaysOffSampler
      expect(result.decision, equals(SamplingDecision.drop));
    });

    test('uses localParentSampled for local sampled parent', () {
      // Create a context with a local sampled parent
      final spanContext = OTel.spanContext(
        traceId: OTel.traceIdFrom('00000000000000000000000000000001'),
        spanId:  OTel.spanIdFrom('0000000000000001'),
        traceFlags: TraceFlags.sampled,
        traceState: OTel.traceState({}),
        isRemote: false,
      );

      final parentContext = OTelAPI.context().withSpanContext(spanContext);

      final result = sampler.shouldSample(
        parentContext: parentContext,
        traceId: spanContext.traceId.hexString,
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      // Should always sample because default localParentSampled is AlwaysOnSampler
      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('uses localParentNotSampled for local not-sampled parent', () {
      // Create a context with a local not-sampled parent
      final spanContext = OTel.spanContext(
        traceId: OTel.traceIdFrom('00000000000000000000000000000001'),
        spanId: OTel.spanIdFrom('0000000000000001'),
        traceFlags: OTel.traceFlags(0),
        // Not sampled
        traceState: OTel.traceState({}),
        isRemote: false,
      );

      final parentContext = OTelAPI.context().withSpanContext(spanContext);

      final result = sampler.shouldSample(
        parentContext: parentContext,
        traceId: spanContext.traceId.hexString,
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      // Should never sample because default localParentNotSampled is AlwaysOffSampler
      expect(result.decision, equals(SamplingDecision.drop));
    });

    test('custom samplers are used when provided', () {
      // Create sampler with custom behavior for different parent states
      final customSampler = ParentBasedSampler(
        const AlwaysOffSampler(), // root - never samples
        remoteParentSampled: const AlwaysOnSampler(),
        // remote+sampled - always samples
        remoteParentNotSampled: const AlwaysOnSampler(),
        // remote+not-sampled - always samples
        localParentSampled: const AlwaysOffSampler(),
        // local+sampled - never samples
        localParentNotSampled:
            const AlwaysOnSampler(), // local+not-sampled - always samples
      );

      // Test the custom behaviors

      // 1. Remote + Sampled parent -> Should sample
      final remoteParentSampledContext =
          OTelAPI.context().withSpanContext(OTel.spanContext(
            traceId: OTel.traceIdFrom('00000000000000000000000000000001'),
            spanId: OTel.spanIdFrom('0000000000000001'),
        traceFlags: TraceFlags.sampled,
        traceState: OTel.traceState({}),
        isRemote: true,
      ));

      expect(
          customSampler
              .shouldSample(
                parentContext: remoteParentSampledContext,
                traceId: '00000000000000000000000000000001',
                name: 'test-span',
                spanKind: SpanKind.internal,
                attributes: null,
                links: null,
              )
              .decision,
          equals(SamplingDecision.recordAndSample));

      // 2. Remote + Not Sampled parent -> Should sample (custom behavior)
      final remoteParentNotSampledContext =
          OTelAPI.context().withSpanContext(OTel.spanContext(
        traceId: OTel.traceIdFrom('00000000000000000000000000000001'),
        spanId: OTel.spanIdFrom('0000000000000001'),
        traceFlags: OTel.traceFlags(0),
        traceState: OTel.traceState({}),
        isRemote: true,
      ));

      expect(
          customSampler
              .shouldSample(
                parentContext: remoteParentNotSampledContext,
                traceId: '00000000000000000000000000000001',
                name: 'test-span',
                spanKind: SpanKind.internal,
                attributes: null,
                links: null,
              )
              .decision,
          equals(SamplingDecision.recordAndSample));

      // 3. Local + Sampled parent -> Should NOT sample (custom behavior)
      final localParentSampledContext =
          OTelAPI.context().withSpanContext(OTel.spanContext(
        traceId: OTel.traceIdFrom('00000000000000000000000000000001'),
        spanId: OTel.spanIdFrom('0000000000000001'),
        traceFlags: TraceFlags.sampled,
        traceState: OTel.traceState({}),
        isRemote: false,
      ));

      expect(
          customSampler
              .shouldSample(
                parentContext: localParentSampledContext,
                traceId: '00000000000000000000000000000001',
                name: 'test-span',
                spanKind: SpanKind.internal,
                attributes: null,
                links: null,
              )
              .decision,
          equals(SamplingDecision.drop));
    });
  });
}
