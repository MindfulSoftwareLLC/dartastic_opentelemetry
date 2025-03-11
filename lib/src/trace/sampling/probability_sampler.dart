// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:math';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'sampler.dart';

/// A sampler that randomly samples traces based on a probability.
/// Unlike TraceIdRatioSampler, this uses random numbers for each decision,
/// meaning the same trace ID might get different decisions.
class ProbabilitySampler implements Sampler {
  final double probability;
  final Random _random;

  @override
  String get description => 'ProbabilitySampler{$probability}';

  /// Creates a probability sampler with the given probability.
  /// [probability] must be in range [0.0, 1.0].
  /// [seed] can be provided for deterministic sampling (mainly for testing).
  ProbabilitySampler(this.probability, {int? seed})
      : _random = Random(seed) {
    if (probability < 0.0 || probability > 1.0) {
      throw ArgumentError('probability must be in range [0.0, 1.0]');
    }
  }

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    // Short circuit for always/never sample
    if (probability >= 1.0) {
      return const SamplingResult(
        decision: SamplingDecision.recordAndSample,
        source: SamplingDecisionSource.tracerConfig,
      );
    }
    if (probability <= 0.0) {
      return const SamplingResult(
        decision: SamplingDecision.drop,
        source: SamplingDecisionSource.tracerConfig,
      );
    }

    final decision = _random.nextDouble() < probability;

    return SamplingResult(
      decision: decision
          ? SamplingDecision.recordAndSample
          : SamplingDecision.drop,
      source: SamplingDecisionSource.tracerConfig,
    );
  }
}
