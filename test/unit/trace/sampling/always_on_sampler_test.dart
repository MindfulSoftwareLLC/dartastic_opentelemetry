// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('AlwaysOnSampler Tests', () {
    late AlwaysOnSampler sampler;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
      );
      sampler = const AlwaysOnSampler();
    });

    test('description returns expected value', () {
      expect(sampler.description, equals('AlwaysOnSampler'));
    });

    test('shouldSample always returns recordAndSample decision', () {
      // Create test parameters
      final parentContext = OTelAPI.context();
      const traceId = '00000000000000000000000000000001';
      const name = 'test-span';
      const spanKind = SpanKind.internal;
      final attributes = {'key': 'value'}.toAttributes();
      final links = <SpanLink>[];

      // Call shouldSample
      final result = sampler.shouldSample(
        parentContext: parentContext,
        traceId: traceId,
        name: name,
        spanKind: spanKind,
        attributes: attributes,
        links: links,
      );

      // Verify the result
      expect(result.decision, equals(SamplingDecision.recordAndSample));
      expect(result.source, equals(SamplingDecisionSource.tracerConfig));
      expect(result.attributes, isNull);
    });

    test('shouldSample returns recordAndSample decision with null parameters',
        () {
      // Call shouldSample with null for optional parameters
      final result = sampler.shouldSample(
        parentContext: OTelAPI.context(),
        traceId: '00000000000000000000000000000001',
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      // Verify the result
      expect(result.decision, equals(SamplingDecision.recordAndSample));
      expect(result.source, equals(SamplingDecisionSource.tracerConfig));
      expect(result.attributes, isNull);
    });
  });
}
