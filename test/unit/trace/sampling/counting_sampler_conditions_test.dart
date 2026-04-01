// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    await OTel.reset();
    await OTel.initialize(serviceName: 'test', detectPlatformResources: false);
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  group('CountingSampler', () {
    test('samples every Nth request', () {
      final sampler = CountingSampler(3);
      final decisions = <SamplingDecision>[];

      for (int i = 0; i < 9; i++) {
        final result = sampler.shouldSample(
          parentContext: Context.root,
          traceId: OTel.traceId().toString(),
          name: 'test-span-$i',
          spanKind: SpanKind.internal,
          attributes: null,
          links: null,
        );
        decisions.add(result.decision);
      }

      // With interval=3, the 3rd (index 2), 6th (index 5), 9th (index 8)
      // calls should be sampled (when _currentCount wraps to 0).
      expect(decisions[0], equals(SamplingDecision.drop));
      expect(decisions[1], equals(SamplingDecision.drop));
      expect(decisions[2], equals(SamplingDecision.recordAndSample));
      expect(decisions[3], equals(SamplingDecision.drop));
      expect(decisions[4], equals(SamplingDecision.drop));
      expect(decisions[5], equals(SamplingDecision.recordAndSample));
      expect(decisions[6], equals(SamplingDecision.drop));
      expect(decisions[7], equals(SamplingDecision.drop));
      expect(decisions[8], equals(SamplingDecision.recordAndSample));
    });

    test('throws on non-positive interval', () {
      expect(() => CountingSampler(0), throwsArgumentError);
      expect(() => CountingSampler(-1), throwsArgumentError);
      expect(() => CountingSampler(-100), throwsArgumentError);
    });

    test('description returns expected string', () {
      final sampler = CountingSampler(5);
      expect(sampler.description, equals('CountingSampler{interval=5}'));
    });

    test('override conditions force sampling regardless of count', () {
      final condition = ErrorSamplingCondition();
      final sampler = CountingSampler(
        100, // High interval so count-based sampling won't trigger
        overrideConditions: [condition],
      );

      final errorAttributes = OTel.attributes([
        OTel.attributeString('otel.status_code', 'ERROR'),
      ]);

      final result = sampler.shouldSample(
        parentContext: Context.root,
        traceId: OTel.traceId().toString(),
        name: 'error-span',
        spanKind: SpanKind.internal,
        attributes: errorAttributes,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });
  });

  group('ErrorSamplingCondition', () {
    late ErrorSamplingCondition condition;

    setUp(() {
      condition = ErrorSamplingCondition();
    });

    test('description returns expected string', () {
      expect(condition.description, equals('ErrorSamplingCondition'));
    });

    test('shouldSampleCondition returns true when status_code is ERROR', () {
      final attributes = OTel.attributes([
        OTel.attributeString('otel.status_code', 'ERROR'),
      ]);

      final result = condition.shouldSampleCondition(
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: attributes,
      );

      expect(result, isTrue);
    });

    test(
      'shouldSampleCondition returns true when status_description is non-empty',
      () {
        final attributes = OTel.attributes([
          OTel.attributeString('otel.status_description', 'some error'),
        ]);

        final result = condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: attributes,
        );

        expect(result, isTrue);
      },
    );

    test('shouldSampleCondition returns false with null attributes', () {
      final result = condition.shouldSampleCondition(
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: null,
      );

      expect(result, isFalse);
    });

    test('shouldSampleCondition returns false with no error attributes', () {
      final attributes = OTel.attributes([
        OTel.attributeString('some.key', 'some.value'),
      ]);

      final result = condition.shouldSampleCondition(
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: attributes,
      );

      expect(result, isFalse);
    });

    test('shouldSample delegates to shouldSampleCondition', () {
      final errorAttributes = OTel.attributes([
        OTel.attributeString('otel.status_code', 'ERROR'),
      ]);

      final sampledResult = condition.shouldSample(
        parentContext: Context.root,
        traceId: OTel.traceId().toString(),
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: errorAttributes,
        links: null,
      );
      expect(sampledResult.decision, equals(SamplingDecision.recordAndSample));

      final normalAttributes = OTel.attributes([
        OTel.attributeString('some.key', 'value'),
      ]);

      final droppedResult = condition.shouldSample(
        parentContext: Context.root,
        traceId: OTel.traceId().toString(),
        name: 'test',
        spanKind: SpanKind.internal,
        attributes: normalAttributes,
        links: null,
      );
      expect(droppedResult.decision, equals(SamplingDecision.drop));
    });
  });

  group('NamePatternSamplingCondition', () {
    late NamePatternSamplingCondition condition;

    setUp(() {
      condition = NamePatternSamplingCondition('error');
    });

    test('description includes pattern', () {
      expect(condition.description, contains('error'));
      expect(
        condition.description,
        equals('NamePatternSamplingCondition{error}'),
      );
    });

    test('shouldSampleCondition returns true when name contains pattern', () {
      final result = condition.shouldSampleCondition(
        name: 'handle-error-request',
        spanKind: SpanKind.internal,
        attributes: null,
      );

      expect(result, isTrue);
    });

    test(
      'shouldSampleCondition returns false when name does not contain pattern',
      () {
        final result = condition.shouldSampleCondition(
          name: 'normal-request',
          spanKind: SpanKind.internal,
          attributes: null,
        );

        expect(result, isFalse);
      },
    );

    test('shouldSample delegates correctly', () {
      final matchResult = condition.shouldSample(
        parentContext: Context.root,
        traceId: OTel.traceId().toString(),
        name: 'this-has-error-in-it',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );
      expect(matchResult.decision, equals(SamplingDecision.recordAndSample));

      final noMatchResult = condition.shouldSample(
        parentContext: Context.root,
        traceId: OTel.traceId().toString(),
        name: 'normal-operation',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );
      expect(noMatchResult.decision, equals(SamplingDecision.drop));
    });
  });

  group('AttributeSamplingCondition', () {
    test('description includes key', () {
      final condition = AttributeSamplingCondition(
        'my.key',
        stringValue: 'my-value',
      );
      expect(condition.description, contains('my.key'));
      expect(
        condition.description,
        equals('AttributeSamplingCondition{my.key}'),
      );
    });

    test('throws when no value provided', () {
      expect(() => AttributeSamplingCondition('my.key'), throwsArgumentError);
    });

    test('throws when multiple values provided', () {
      expect(
        () => AttributeSamplingCondition(
          'my.key',
          stringValue: 'hello',
          intValue: 42,
        ),
        throwsArgumentError,
      );
      expect(
        () => AttributeSamplingCondition(
          'my.key',
          boolValue: true,
          doubleValue: 3.14,
        ),
        throwsArgumentError,
      );
      expect(
        () => AttributeSamplingCondition(
          'my.key',
          stringValue: 'hello',
          boolValue: true,
          intValue: 42,
        ),
        throwsArgumentError,
      );
    });

    test('string value matching works', () {
      final condition = AttributeSamplingCondition(
        'env',
        stringValue: 'production',
      );

      final matchAttributes = OTel.attributes([
        OTel.attributeString('env', 'production'),
      ]);
      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: matchAttributes,
        ),
        isTrue,
      );

      final noMatchAttributes = OTel.attributes([
        OTel.attributeString('env', 'staging'),
      ]);
      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: noMatchAttributes,
        ),
        isFalse,
      );
    });

    test('bool value matching works', () {
      final condition = AttributeSamplingCondition(
        'is.critical',
        boolValue: true,
      );

      final matchAttributes = OTel.attributes([
        OTel.attributeBool('is.critical', true),
      ]);
      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: matchAttributes,
        ),
        isTrue,
      );

      final noMatchAttributes = OTel.attributes([
        OTel.attributeBool('is.critical', false),
      ]);
      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: noMatchAttributes,
        ),
        isFalse,
      );
    });

    test('int value matching works', () {
      final condition = AttributeSamplingCondition('priority', intValue: 1);

      final matchAttributes = OTel.attributes([
        OTel.attributeInt('priority', 1),
      ]);
      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: matchAttributes,
        ),
        isTrue,
      );

      final noMatchAttributes = OTel.attributes([
        OTel.attributeInt('priority', 5),
      ]);
      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: noMatchAttributes,
        ),
        isFalse,
      );
    });

    test('double value matching works', () {
      final condition = AttributeSamplingCondition(
        'threshold',
        doubleValue: 0.95,
      );

      final matchAttributes = OTel.attributes([
        OTel.attributeDouble('threshold', 0.95),
      ]);
      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: matchAttributes,
        ),
        isTrue,
      );

      final noMatchAttributes = OTel.attributes([
        OTel.attributeDouble('threshold', 0.5),
      ]);
      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: noMatchAttributes,
        ),
        isFalse,
      );
    });

    test('returns false with null attributes', () {
      final condition = AttributeSamplingCondition(
        'my.key',
        stringValue: 'value',
      );

      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: null,
        ),
        isFalse,
      );
    });

    test('returns false when attribute does not match', () {
      final condition = AttributeSamplingCondition(
        'target.key',
        stringValue: 'expected-value',
      );

      // Attribute key present but different value
      final wrongValueAttributes = OTel.attributes([
        OTel.attributeString('target.key', 'wrong-value'),
      ]);
      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: wrongValueAttributes,
        ),
        isFalse,
      );

      // Attribute key not present at all
      final missingKeyAttributes = OTel.attributes([
        OTel.attributeString('other.key', 'expected-value'),
      ]);
      expect(
        condition.shouldSampleCondition(
          name: 'test',
          spanKind: SpanKind.internal,
          attributes: missingKeyAttributes,
        ),
        isFalse,
      );
    });
  });
}
