// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'sampler.dart';

/// A sampler that never samples any traces.
class AlwaysOffSampler implements Sampler {
  @override
  String get description => 'AlwaysOffSampler';

  const AlwaysOffSampler();

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
