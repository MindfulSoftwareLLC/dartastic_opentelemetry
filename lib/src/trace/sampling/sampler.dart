// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';

/// Default sampler configuration decision sources.
enum SamplingDecisionSource {
  parentBased,
  tracerConfig,
}

/// The sampling decision made by a Sampler.
enum SamplingDecision {
  recordAndSample,
  recordOnly,
  drop,
}

/// Result of a sampling decision.
class SamplingResult {
  /// The sampling decision.
  final SamplingDecision decision;

  /// The source of the sampling decision.
  final SamplingDecisionSource source;

  /// Additional attributes to add to the span.
  final Attributes? attributes;

  const SamplingResult({
    required this.decision,
    required this.source,
    this.attributes,
  });
}

/// Base class for samplers.
abstract class Sampler {
  /// Description of the sampler used in the recorded data.
  String get description;

  /// Makes a sampling decision based on the parent context and other parameters.
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  });
}
