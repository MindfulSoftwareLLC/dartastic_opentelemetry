// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'sampler.dart';

/// A sampler that always samples every trace.
class AlwaysOnSampler implements Sampler {
  @override
  String get description => 'AlwaysOnSampler';

  const AlwaysOnSampler();

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
