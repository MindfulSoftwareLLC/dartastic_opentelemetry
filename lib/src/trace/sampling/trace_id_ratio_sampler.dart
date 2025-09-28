// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:math' as math;

import '../../../dartastic_opentelemetry.dart';

/// A sampler that samples traces based on a probability defined by the ratio of
/// traces that should be sampled. The ratio must be in the range [0.0, 1.0].
///
/// Uses the lowest 8 bytes of the trace ID to make a sampling decision.
class TraceIdRatioSampler implements Sampler {
  /// The sampling ratio, a value between 0.0 and 1.0 that determines
  /// the probability that a trace will be sampled.
  final double ratio;

  @override
  String get description => 'TraceIdRatioSampler{$ratio}';

  /// Creates a TraceIdRatioSampler with the given ratio.
  /// [ratio] must be in the range [0.0, 1.0].
  TraceIdRatioSampler(this.ratio) {
    if (ratio < 0.0 || ratio > 1.0) {
      throw ArgumentError('ratio must be in range [0.0, 1.0]');
    }
  }

  /// Converts a trace ID to a value between 0.0 and 1.0 for sampling decisions.
  /// Uses the lowest 8 bytes (16 hex characters) of the trace ID as per the specification.
  ///
  /// @param traceId The trace ID as a hex string
  /// @return A value between 0.0 and 1.0 based on the trace ID
  double _traceIdToValue(String traceId) {
    // Get the last 16 hex chars (8 bytes) of trace ID
    final lastBytes = traceId.substring(math.max(0, traceId.length - 16));

    // Parse hex string to integer with BigInt to avoid precision issues
    final value = BigInt.parse(lastBytes, radix: 16);

    // Maximum possible value for 8 bytes (64 bits) is 2^64 - 1
    final maxValue = BigInt.parse('ffffffffffffffff', radix: 16);

    // Convert to a double between 0.0 and 1.0
    return value.toDouble() / maxValue.toDouble();
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
    // If ratio is 0, never sample
    if (ratio == 0.0) {
      return const SamplingResult(
        decision: SamplingDecision.drop,
        source: SamplingDecisionSource.tracerConfig,
      );
    }

    // If ratio is 1, always sample
    if (ratio == 1.0) {
      return const SamplingResult(
        decision: SamplingDecision.recordAndSample,
        source: SamplingDecisionSource.tracerConfig,
      );
    }

    // Convert trace ID to a value between 0.0 and 1.0
    final value = _traceIdToValue(traceId);

    // If the value is less than our ratio, we should sample
    final shouldSample = value < ratio;

    return SamplingResult(
      decision: shouldSample
          ? SamplingDecision.recordAndSample
          : SamplingDecision.drop,
      source: SamplingDecisionSource.tracerConfig,
    );
  }
}
