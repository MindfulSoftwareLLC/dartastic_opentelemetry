// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'sampler.dart';

/// A sampler that always samples every trace.
///
/// This sampler implements the "always on" sampling strategy, which means
/// it will record and sample every span regardless of any other factors.
/// This is useful for debugging and development environments where you
/// want to see all spans.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/trace/sdk/#alwayson
class AlwaysOnSampler implements Sampler {
  /// Gets a description of this sampler.
  ///
  /// @return The string "AlwaysOnSampler"
  @override
  String get description => 'AlwaysOnSampler';

  /// Creates a new AlwaysOnSampler.
  const AlwaysOnSampler();

  /// Always returns a decision to record and sample the span.
  ///
  /// This method ignores all parameters and always returns a decision
  /// to record and sample the span.
  ///
  /// @param parentContext Ignored
  /// @param traceId Ignored
  /// @param name Ignored
  /// @param spanKind Ignored
  /// @param attributes Ignored
  /// @param links Ignored
  /// @return A sampling result with decision set to recordAndSample
  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    return const SamplingResult(
      decision: SamplingDecision.recordAndSample,
      source: SamplingDecisionSource.tracerConfig,
    );
  }
}
