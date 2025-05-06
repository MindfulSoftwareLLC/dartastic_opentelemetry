// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:math';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('TraceIdRatioSampler Tests', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
      );
    });
    test('constructor throws ArgumentError for invalid ratio values', () {
      expect(() => TraceIdRatioSampler(-0.1), throwsArgumentError);
      expect(() => TraceIdRatioSampler(1.1), throwsArgumentError);
    });

    test('constructor accepts valid ratio values', () {
      expect(() => TraceIdRatioSampler(0.0), returnsNormally);
      expect(() => TraceIdRatioSampler(0.5), returnsNormally);
      expect(() => TraceIdRatioSampler(1.0), returnsNormally);
    });

    test('description returns expected value', () {
      final sampler = TraceIdRatioSampler(0.5);
      expect(sampler.description, equals('TraceIdRatioSampler{0.5}'));
    });

    test('sampler with ratio 0.0 never samples', () {
      final sampler = TraceIdRatioSampler(0.0);
      final parentContext = OTelAPI.context();

      // Try with 10 different trace IDs
      for (int i = 0; i < 10; i++) {
        final traceId = '000000000000000000000000000000${i.toRadixString(16).padLeft(2, '0')}';

        final result = sampler.shouldSample(
          parentContext: parentContext,
          traceId: traceId,
          name: 'test-span',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );

        expect(result.decision, equals(SamplingDecision.drop));
      }
    });

    test('sampler with ratio 1.0 always samples', () {
      final sampler = TraceIdRatioSampler(1.0);
      final parentContext = OTelAPI.context();

      // Try with 10 different trace IDs
      for (int i = 0; i < 10; i++) {
        final traceId = '000000000000000000000000000000${i.toRadixString(16).padLeft(2, '0')}';

        final result = sampler.shouldSample(
          parentContext: parentContext,
          traceId: traceId,
          name: 'test-span',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );

        expect(result.decision, equals(SamplingDecision.recordAndSample));
      }
    });

    test('sampler with ratio 0.5 samples approximately half the time', () {
      final sampler = TraceIdRatioSampler(0.5);
      final parentContext = OTelAPI.context();

      // Create predictable trace IDs that will cover both sides of the decision boundary
      // The sampler uses the last 16 hex chars (8 bytes) of the trace ID
      final lowTraceId = '00000000000000000000000000000000'; // Should be sampled
      final highTraceId = 'ffffffffffffffffffffffffffffffff'; // Should not be sampled

      final lowResult = sampler.shouldSample(
        parentContext: parentContext,
        traceId: lowTraceId,
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      final highResult = sampler.shouldSample(
        parentContext: parentContext,
        traceId: highTraceId,
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(lowResult.decision, equals(SamplingDecision.recordAndSample));
      expect(highResult.decision, equals(SamplingDecision.drop));
    });

    test('statistical distribution test with ratio 0.3', () {
      final sampler = TraceIdRatioSampler(0.3);
      final parentContext = OTelAPI.context();

      int sampledCount = 0;
      const totalRuns = 1000;
      final random = Random();

      // Generate truly random trace IDs for accurate sampling distribution
      for (int i = 0; i < totalRuns; i++) {
        // Create a random trace ID using random bytes
        final buffer = StringBuffer();
        for (int j = 0; j < 32; j++) {
          buffer.write(random.nextInt(16).toRadixString(16)); // Random hex digit
        }
        final traceId = buffer.toString();

        final result = sampler.shouldSample(
          parentContext: parentContext,
          traceId: traceId,
          name: 'test-span',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );

        if (result.decision == SamplingDecision.recordAndSample) {
          sampledCount++;
        }
      }

      // Check if the sampling rate is roughly within expected bounds
      // Allow for some statistical variation (±10%)
      final samplingRate = sampledCount / totalRuns;
      print('Sampled $sampledCount out of $totalRuns traces (rate: $samplingRate)');
      expect(samplingRate, closeTo(0.3, 0.1));
    });
  });
}
