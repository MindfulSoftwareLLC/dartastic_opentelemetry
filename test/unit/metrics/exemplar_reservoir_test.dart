// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

class _ThrowingRandom implements Random {
  @override
  int nextInt(int max) => throw StateError('nextInt should not be called');
  @override
  bool nextBool() => throw StateError('nextBool should not be called');
  @override
  double nextDouble() => throw StateError('nextDouble should not be called');
}

void main() {
  setUp(() async {
    await OTel.reset();
    await OTel.initialize();
  });
  tearDown(() async {
    await OTel.shutdown();
  });

  group('SimpleFixedSizeExemplarReservoir tests', () {
    test('samples correctly using deterministic random', () {
      // Use a seeded random for deterministic tests.
      // Random(42) produces a specific sequence of ints.
      final random = Random(42);
      final reservoir = SimpleFixedSizeExemplarReservoir(2, random: random);

      final attributes = Attributes.of({});
      final context = Context.current;

      // Offer first two measurements, they should both fit in the size=2 reservoir
      reservoir.offerMeasurement(10, attributes, context, DateTime.now());
      reservoir.offerMeasurement(20, attributes, context, DateTime.now());

      var exemplars = reservoir.collectAndReset(attributes);
      expect(exemplars.length, equals(2));
      expect(exemplars.map((e) => e.value).toSet(), equals({10, 20}));

      // The reservoir was reset, so measurementsSeen is 0.
      // The first two measurements (10, 20) are stored unconditionally.
      // The next three (30, 40, 50) will trigger random sampling replacement.
      for (var i = 1; i <= 5; i++) {
        reservoir.offerMeasurement(i * 10, attributes, context, DateTime.now());
      }
      exemplars = reservoir.collectAndReset(attributes);

      // Since it's deterministic and fixed size is 2, length is always 2.
      // With Random(42) and this exact sequence (after a reset), the surviving values are known:
      expect(exemplars.length, equals(2));
      expect(exemplars.map((e) => e.value).toSet(), equals({10, 30}));

      // Reset is called so the reservoir should be empty if collected again
      expect(reservoir.collectAndReset(attributes).length, equals(0));
    });

    test('collectAndReset clears measurementsSeen', () {
      final random = _ThrowingRandom();
      final reservoir = SimpleFixedSizeExemplarReservoir(2, random: random);
      final attributes = Attributes.of({});
      final context = Context.current;

      // Offer exactly size measurements (no random needed)
      reservoir.offerMeasurement(10, attributes, context, DateTime.now());
      reservoir.offerMeasurement(20, attributes, context, DateTime.now());
      reservoir.collectAndReset(attributes);

      // Offer again exactly size measurements
      // If _measurementsSeen was NOT reset, it would call random.nextInt and throw
      expect(
        () {
          reservoir.offerMeasurement(30, attributes, context, DateTime.now());
          reservoir.offerMeasurement(40, attributes, context, DateTime.now());
        },
        returnsNormally,
      );

      final exemplars = reservoir.collectAndReset(attributes);
      expect(exemplars.map((e) => e.value).toSet(), equals({30, 40}));
    });
  });

  group('AlignedHistogramBucketExemplarReservoir tests', () {
    test('probabilistic replacement per bucket', () {
      final random = Random(123);
      final boundaries = [10.0, 20.0];
      final reservoir =
          AlignedHistogramBucketExemplarReservoir(boundaries, random: random);

      final attributes = Attributes.of({});
      final context = Context.current;

      // Bucket 0: <= 10.0
      reservoir.offerMeasurement(5, attributes, context, DateTime.now());
      // Bucket 1: <= 20.0
      reservoir.offerMeasurement(15, attributes, context, DateTime.now());
      // Bucket 2: > 20.0
      reservoir.offerMeasurement(25, attributes, context, DateTime.now());

      var exemplars = reservoir.collectAndReset(attributes);
      expect(exemplars.length, equals(3));
      expect(exemplars.map((e) => e.value).toSet(), equals({5, 15, 25}));

      // Test multiple measurements in the same bucket
      for (var i = 0; i < 10; i++) {
        reservoir.offerMeasurement(
            5 + (i * 0.1), attributes, context, DateTime.now());
      }
      exemplars = reservoir.collectAndReset(attributes);
      // Still only one exemplar for that bucket
      expect(exemplars.length, equals(1));

      // With Random(123) and this exact sequence (after a reset), the surviving value is known:
      expect(exemplars.first.value, equals(5.2));
    });

    test('collectAndReset clears per-bucket counts', () {
      final random = _ThrowingRandom();
      final boundaries = [10.0];
      final reservoir =
          AlignedHistogramBucketExemplarReservoir(boundaries, random: random);
      final attributes = Attributes.of({});
      final context = Context.current;

      // First offer in bucket 0, no random needed
      reservoir.offerMeasurement(5, attributes, context, DateTime.now());
      reservoir.collectAndReset(attributes);

      // Offer again in bucket 0
      // If counts[0] was NOT reset (still 1), it would try to roll random.nextInt(2) and throw
      expect(
        () =>
            reservoir.offerMeasurement(5, attributes, context, DateTime.now()),
        returnsNormally,
      );

      final exemplars = reservoir.collectAndReset(attributes);
      expect(exemplars.length, equals(1));
    });

    test('trusts pre-computed bucketIndex', () {
      final boundaries = [10.0, 20.0];
      final reservoir = AlignedHistogramBucketExemplarReservoir(boundaries);
      final attributes = Attributes.of({});
      final context = Context.current;

      // A value of 5 belongs in bucket 0 (<= 10.0) normally.
      // If we pass bucketIndex: 2 (> 20.0), it should unconditionally trust the index.
      reservoir.offerMeasurement(5, attributes, context, DateTime.now(), 2);

      // Now offer another value of 5 to bucket 0.
      reservoir.offerMeasurement(5, attributes, context, DateTime.now(), 0);

      // Since they landed in distinct buckets, there should be 2 exemplars collected.
      // If it ignored the pre-computed index, both would be in bucket 0,
      // resulting in only 1 exemplar collected.
      final exemplars = reservoir.collectAndReset(attributes);
      expect(exemplars.length, equals(2));
    });
  });
}
