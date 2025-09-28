// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/trace/sampling/composite_sampler.dart';
import 'package:dartastic_opentelemetry/src/trace/sampling/counting_sampler.dart';
import 'package:dartastic_opentelemetry/src/trace/sampling/probability_sampler.dart';
import 'package:dartastic_opentelemetry/src/trace/sampling/rate_limiting_sampler.dart';
import 'package:dartastic_opentelemetry/src/trace/sampling/sampler.dart';
import 'package:dartastic_opentelemetry/src/trace/sampling/trace_id_ratio_sampler.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  late Context emptyContext;

  setUp(() async {
    await OTel.initialize(
      endpoint: 'http://localhost:4317',
      serviceName: 'test-service',
    );
    emptyContext = OTel.context();
  });

  tearDown(() async {
    await OTel.reset();
  });

  group('TraceIdRatioSampler', () {
    test('samples consistently for same trace ID', () {
      final sampler = TraceIdRatioSampler(0.5);
      final traceId = '1234567890abcdef1234567890abcdef';

      final result1 = sampler.shouldSample(
        parentContext: emptyContext,
        traceId: traceId,
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      final result2 = sampler.shouldSample(
        parentContext: emptyContext,
        traceId: traceId,
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result1.decision, equals(result2.decision));
    });

    test('samples at roughly the configured ratio', () {
      final sampler = TraceIdRatioSampler(0.5);
      var sampledCount = 0;
      const iterations = 1000;

      for (var i = 0; i < iterations; i++) {
        final traceId = OTel.traceId().toString();
        final result = sampler.shouldSample(
          parentContext: emptyContext,
          traceId: traceId,
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );
        if (result.decision == SamplingDecision.recordAndSample) {
          sampledCount++;
        }
      }

      // Should be roughly 50% with some margin for randomness
      final ratio = sampledCount / iterations;
      expect(ratio, closeTo(0.5, 0.1));
    });
  });

  group('CountingSampler', () {
    test('samples every Nth request', () {
      final sampler = CountingSampler(3);
      final decisions = List.generate(
          9,
          (index) => sampler
              .shouldSample(
                parentContext: emptyContext,
                traceId: 'trace$index',
                name: 'test',
                spanKind: SpanKind.internal,
                attributes: null,
                links: null,
              )
              .decision);

      // Should sample every 3rd request (indices 2, 5, 8)
      expect(
          decisions,
          equals([
            SamplingDecision.drop,
            SamplingDecision.drop,
            SamplingDecision.recordAndSample,
            SamplingDecision.drop,
            SamplingDecision.drop,
            SamplingDecision.recordAndSample,
            SamplingDecision.drop,
            SamplingDecision.drop,
            SamplingDecision.recordAndSample,
          ]));
    });

    test('overrides count based on error condition', () {
      final sampler = CountingSampler(
        3,
        overrideConditions: [ErrorSamplingCondition()],
      );

      // This would normally be dropped but has an error
      final result = sampler.shouldSample(
        parentContext: emptyContext,
        traceId: 'trace1',
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: OTel.attributesFromMap({
          'otel.status_code': 'ERROR',
          'otel.status_description': 'Something went wrong',
        }),
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('overrides count based on name pattern', () {
      final sampler = CountingSampler(
        3,
        overrideConditions: [NamePatternSamplingCondition('important')],
      );

      // This would normally be dropped but matches the pattern
      final result = sampler.shouldSample(
        parentContext: emptyContext,
        traceId: 'trace1',
        name: 'important-operation',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('overrides count based on attribute value', () {
      final sampler = CountingSampler(
        3,
        overrideConditions: [
          AttributeSamplingCondition('priority', stringValue: 'high')
        ],
      );

      // This would normally be dropped but has high priority
      final result = sampler.shouldSample(
        parentContext: emptyContext,
        traceId: 'trace1',
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: OTel.attributesFromMap({'priority': 'high'}),
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });
  });

  group('RateLimitingSampler', () {
    test('limits sampling rate', () async {
      final sampler = RateLimitingSampler(10,
          timeWindow: const Duration(milliseconds: 100)); // 10 per second
      var sampledCount = 0;

      // Try to sample 100 times in rapid succession
      for (var i = 0; i < 100; i++) {
        final result = sampler.shouldSample(
          parentContext: emptyContext,
          traceId: 'trace$i',
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );
        if (result.decision == SamplingDecision.recordAndSample) {
          sampledCount++;
        }
      }

      // Should be limited to roughly 1 sample (10 per second * 0.1 seconds)
      expect(
          sampledCount, lessThanOrEqualTo(2)); // Allow some margin for timing

      // Clean up
      sampler.dispose();
    });

    test('replenishes tokens over time', () async {
      final sampler = RateLimitingSampler(10,
          timeWindow: const Duration(milliseconds: 100));
      var initialSampledCount = 0;
      var laterSampledCount = 0;

      // Sample initial burst
      for (var i = 0; i < 10; i++) {
        final result = sampler.shouldSample(
          parentContext: emptyContext,
          traceId: 'trace$i',
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );
        if (result.decision == SamplingDecision.recordAndSample) {
          initialSampledCount++;
        }
      }

      // Wait for tokens to replenish
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Try sampling again
      for (var i = 0; i < 10; i++) {
        final result = sampler.shouldSample(
          parentContext: emptyContext,
          traceId: 'trace$i',
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );
        if (result.decision == SamplingDecision.recordAndSample) {
          laterSampledCount++;
        }
      }

      // Should have some samples in both periods
      expect(initialSampledCount, greaterThan(0));
      expect(laterSampledCount, greaterThan(0));

      // Clean up
      sampler.dispose();
    });
  });

  group('ProbabilitySampler', () {
    test('samples at roughly the configured probability', () {
      final sampler = ProbabilitySampler(0.5);
      var sampledCount = 0;
      const iterations = 1000;

      for (var i = 0; i < iterations; i++) {
        final result = sampler.shouldSample(
          parentContext: emptyContext,
          traceId: 'trace$i',
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );
        if (result.decision == SamplingDecision.recordAndSample) {
          sampledCount++;
        }
      }

      // Should be roughly 50% with some margin for randomness
      final ratio = sampledCount / iterations;
      expect(ratio, closeTo(0.5, 0.1));
    });

    test('is deterministic with seed', () {
      final sampler1 = ProbabilitySampler(0.5, seed: 42);
      final sampler2 = ProbabilitySampler(0.5, seed: 42);

      for (var i = 0; i < 100; i++) {
        final result1 = sampler1.shouldSample(
          parentContext: emptyContext,
          traceId: 'trace$i',
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );
        final result2 = sampler2.shouldSample(
          parentContext: emptyContext,
          traceId: 'trace$i',
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );
        expect(result1.decision, equals(result2.decision));
      }
    });
  });

  group('CompositeSampler', () {
    test('AND composition requires all samplers to accept', () {
      final sampler = CompositeSampler.and([
        CountingSampler(2),
        ProbabilitySampler(1.0), // Always accepts
      ]);

      final decisions = List.generate(
          4,
          (index) => sampler
              .shouldSample(
                parentContext: emptyContext,
                traceId: 'trace$index',
                name: 'test',
                spanKind: SpanKind.internal,
                attributes: null,
                links: null,
              )
              .decision);

      // Should only sample every 2nd request due to CountingSampler
      expect(
          decisions,
          equals([
            SamplingDecision.drop,
            SamplingDecision.recordAndSample,
            SamplingDecision.drop,
            SamplingDecision.recordAndSample,
          ]));
    });

    test('OR composition accepts if any sampler accepts', () {
      final sampler = CompositeSampler.or([
        CountingSampler(3), // Samples every 3rd
        AttributeSamplingCondition('priority',
            stringValue: 'high'), // Samples high priority
      ]);

      final results = [
        sampler
            .shouldSample(
              // Regular request - dropped
              parentContext: emptyContext,
              traceId: 'trace1',
              name: 'test',
              spanKind: SpanKind.internal,
              attributes: OTel.attributesFromMap({'priority': 'low'}),
              links: null,
            )
            .decision,
        sampler
            .shouldSample(
              // High priority - sampled
              parentContext: emptyContext,
              traceId: 'trace2',
              name: 'test',
              spanKind: SpanKind.internal,
              attributes: OTel.attributesFromMap({'priority': 'high'}),
              links: null,
            )
            .decision,
        sampler
            .shouldSample(
              // Third request - sampled
              parentContext: emptyContext,
              traceId: 'trace3',
              name: 'test',
              spanKind: SpanKind.internal,
              attributes: OTel.attributesFromMap({'priority': 'low'}),
              links: null,
            )
            .decision,
      ];

      expect(
          results,
          equals([
            SamplingDecision.drop,
            SamplingDecision.recordAndSample,
            SamplingDecision.recordAndSample,
          ]));
    });
  });
}
