// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'sampler.dart';

/// A sampler that never samples any traces.
///
/// This sampler implements the "always off" sampling strategy, which means
/// it will never record or sample any span regardless of any other factors.
/// This is useful for testing or production environments where you want to
/// temporarily disable sampling without changing the code.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/trace/sdk/#alwaysoff
class AlwaysOffSampler implements Sampler {
  /// Gets a description of this sampler.
  ///
  /// @return The string "AlwaysOffSampler"
  @override
  String get description => 'AlwaysOffSampler';

  /// Creates a new AlwaysOffSampler.
  const AlwaysOffSampler();

  /// Always returns a decision to drop the span.
  ///
  /// This method ignores all parameters and always returns a decision
  /// to drop the span (not record or sample it).
  ///
  /// @param parentContext Ignored
  /// @param traceId Ignored
  /// @param name Ignored
  /// @param spanKind Ignored
  /// @param attributes Ignored
  /// @param links Ignored
  /// @return A sampling result with decision set to drop
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
      decision: SamplingDecision.drop,
      source: SamplingDecisionSource.tracerConfig,
    );
  }
}
