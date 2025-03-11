// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'sampler.dart';

/// A sampler that samples traces based on a probability defined by the ratio of
/// traces that should be sampled. The ratio must be in the range [0.0, 1.0].
///
/// Uses the lowest 8 bytes of the trace ID to make a sampling decision.
class TraceIdRatioSampler implements Sampler {
  final double ratio;
  final double _upperBound;

  @override
  String get description => 'TraceIdRatioSampler{$ratio}';

  /// Creates a TraceIdRatioSampler with the given ratio.
  /// [ratio] must be in the range [0.0, 1.0].
  TraceIdRatioSampler(this.ratio) : _upperBound = _calculateUpperBound(ratio) {
    if (ratio < 0.0 || ratio > 1.0) {
      throw ArgumentError('ratio must be in range [0.0, 1.0]');
    }
  }

  static double _calculateUpperBound(double ratio) {
    // Use max uint64 value: 18446744073709551615
    return ratio * (1 << 64 - 1);
  }

  double _traceIdToDouble(String traceId) {
    // Use last 16 chars (8 bytes) of trace ID
    final lastBytes = traceId.substring(traceId.length - 16);
    var value = 0.0;
    for (var i = 0; i < lastBytes.length; i++) {
      value = (value * 16) + int.parse(lastBytes[i], radix: 16);
    }
    return value;
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

    // Convert trace ID to number and compare with upper bound
    final idValue = _traceIdToDouble(traceId);
    final shouldSample = idValue < _upperBound;

    return SamplingResult(
      decision: shouldSample
          ? SamplingDecision.recordAndSample
          : SamplingDecision.drop,
      source: SamplingDecisionSource.tracerConfig,
    );
  }
}
