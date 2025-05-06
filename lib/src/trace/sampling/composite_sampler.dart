// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import '../../otel.dart';
import 'sampler.dart';

/// A sampler that combines multiple samplers using a specified operation.
class CompositeSampler implements Sampler {
  final List<Sampler> _samplers;
  final _Operation _operation;

  @override
  String get description => 'CompositeSampler{${_operation.name},[${_samplers.map((s) => s.description).join(',')}]}';

  /// Creates a CompositeSampler that requires all samplers to accept.
  const CompositeSampler.and(List<Sampler> samplers) : this._(samplers, _Operation.and);

  /// Creates a CompositeSampler that requires any sampler to accept.
  const CompositeSampler.or(List<Sampler> samplers) : this._(samplers, _Operation.or);

  const CompositeSampler._(this._samplers, this._operation);

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    if (_samplers.isEmpty) {
      return const SamplingResult(
        decision: SamplingDecision.recordAndSample,
        source: SamplingDecisionSource.tracerConfig,
      );
    }

    Attributes? combinedAttributes;

    for (final sampler in _samplers) {
      final result = sampler.shouldSample(
        parentContext: parentContext,
        traceId: traceId,
        name: name,
        spanKind: spanKind,
        attributes: attributes,
        links: links,
      );

      // For AND, if any sampler drops, return drop
      // For OR, if any sampler samples, return sample
      if (_operation == _Operation.and && result.decision == SamplingDecision.drop) {
        return result;
      } else if (_operation == _Operation.or && result.decision == SamplingDecision.recordAndSample) {
        return result;
      }

      // Combine attributes if present
      if (result.attributes != null) {
        combinedAttributes ??  OTel.attributes(); //TODO simplify
        combinedAttributes!.copyWithAttributes(result.attributes!);
      }
    }

    // For AND, all samplers accepted, return recordAndSample
    // For OR, no sampler accepted, return drop
    return SamplingResult(
      decision: _operation == _Operation.and
          ? SamplingDecision.recordAndSample
          : SamplingDecision.drop,
      source: SamplingDecisionSource.tracerConfig,
      attributes: combinedAttributes,
    );
  }
}

enum _Operation {
  and,
  or,
}
