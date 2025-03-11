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

/// A sampler that always makes the same decision.
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

/// A sampler that samples based on the parent span's sampling decision.
class ParentBasedSampler implements Sampler {
  final Sampler _root;
  final Sampler _remoteParentSampled;
  final Sampler _remoteParentNotSampled;
  final Sampler _localParentSampled;
  final Sampler _localParentNotSampled;

  @override
  String get description => 'ParentBased{root=${_root.description}}';

  ParentBasedSampler(
    Sampler root, {
    Sampler? remoteParentSampled,
    Sampler? remoteParentNotSampled,
    Sampler? localParentSampled,
    Sampler? localParentNotSampled,
  })  : _root = root,
        _remoteParentSampled = remoteParentSampled ?? const AlwaysOnSampler(),
        _remoteParentNotSampled =
            remoteParentNotSampled ?? const AlwaysOnSampler(),
        _localParentSampled = localParentSampled ?? const AlwaysOnSampler(),
        _localParentNotSampled =
            localParentNotSampled ?? const AlwaysOnSampler();

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    final parentSpanContext = parentContext.spanContext;

    if (parentSpanContext == null || !parentSpanContext.isValid) {
      return _root.shouldSample(
        parentContext: parentContext,
        traceId: traceId,
        name: name,
        spanKind: spanKind,
        attributes: attributes,
        links: links,
      );
    }

    if (parentSpanContext.isRemote) {
      return parentSpanContext.traceFlags.isSampled
          ? _remoteParentSampled.shouldSample(
              parentContext: parentContext,
              traceId: traceId,
              name: name,
              spanKind: spanKind,
              attributes: attributes,
              links: links,
            )
          : _remoteParentNotSampled.shouldSample(
              parentContext: parentContext,
              traceId: traceId,
              name: name,
              spanKind: spanKind,
              attributes: attributes,
              links: links,
            );
    }

    return parentSpanContext.traceFlags.isSampled
        ? _localParentSampled.shouldSample(
            parentContext: parentContext,
            traceId: traceId,
            name: name,
            spanKind: spanKind,
            attributes: attributes,
            links: links,
          )
        : _localParentNotSampled.shouldSample(
            parentContext: parentContext,
            traceId: traceId,
            name: name,
            spanKind: spanKind,
            attributes: attributes,
            links: links,
          );
  }
}
