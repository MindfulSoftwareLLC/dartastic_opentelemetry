// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:math';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'sampler.dart';

/// A sampler that randomly samples traces based on a probability.
///
/// This sampler makes a random decision for each span, with the specified
/// probability of sampling. Unlike the TraceIdRatioSampler, which uses the
/// trace ID to make a consistent decision for all spans in a trace, this
/// sampler uses a fresh random number for each decision.
///
/// Note that this means the same trace ID might get different sampling
/// decisions if evaluated multiple times, which could lead to inconsistent
/// sampling within a trace. For consistent sampling across a trace, use
/// TraceIdRatioSampler or ParentBasedSampler.
class ProbabilitySampler implements Sampler {
  /// The probability of sampling a span, in the range [0.0, 1.0].
  final double probability;
  
  /// Random number generator for sampling decisions.
  late final Random _random;

  /// Gets a description of this sampler.
  ///
  /// @return A description including the sampling probability
  @override
  String get description => 'ProbabilitySampler{$probability}';

  /// Creates a probability sampler with the given probability.
  ///
  /// @param probability The probability of sampling a span, in the range [0.0, 1.0]
  /// @param seed Optional seed for the random number generator (mainly for testing)
  /// @throws ArgumentError if probability is not in the range [0.0, 1.0]
  ProbabilitySampler(this.probability, {int? seed}) {
    // Initialize random with secure random if no seed provided
    _random = seed != null ? Random(seed) : Random.secure();
    if (probability < 0.0 || probability > 1.0) {
      throw ArgumentError('probability must be in range [0.0, 1.0]');
    }
  }

  /// Makes a sampling decision based on random probability.
  ///
  /// This method generates a random number between 0 and 1, and compares
  /// it to the configured probability to make a sampling decision.
  ///
  /// @param parentContext Ignored
  /// @param traceId Ignored
  /// @param name Ignored
  /// @param spanKind Ignored
  /// @param attributes Ignored
  /// @param links Ignored
  /// @return A sampling result based on the random probability
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
