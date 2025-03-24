// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'sampler.dart';

/// A sampler that respects the parent span's sampling decision.
/// If there is no parent or parent is not remote, it uses the root sampler.
/// 
/// This is important for maintaining complete traces across service boundaries.
/// Follows the OpenTelemetry specification for parent-based sampling.
class ParentBasedSampler implements Sampler {
  final Sampler _root;
  final Sampler _remoteParentSampled;
  final Sampler _remoteParentNotSampled;
  final Sampler _localParentSampled;
  final Sampler _localParentNotSampled;

  @override
  String get description => 'ParentBased{root=${_root.description}}';

  /// Creates a parent-based sampler.
  /// 
  /// [root] is the sampler to use when there is no parent.
  /// The other samplers are optional and will default to AlwaysOn/AlwaysOff
  /// based on the sampling state they represent.
  ParentBasedSampler(
    this._root, {
    Sampler? remoteParentSampled,
    Sampler? remoteParentNotSampled,
    Sampler? localParentSampled,
    Sampler? localParentNotSampled,
  })  : _remoteParentSampled = remoteParentSampled ?? const AlwaysOnSampler(),
        _remoteParentNotSampled = remoteParentNotSampled ?? const AlwaysOffSampler(),
        _localParentSampled = localParentSampled ?? const AlwaysOnSampler(),
        _localParentNotSampled = localParentNotSampled ?? const AlwaysOffSampler();

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    // Extract SpanContext from the parent context
    final parentSpanContext = parentContext.spanContext;

    // If no parent, use root sampler
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

    // Parent exists, use appropriate sampler based on parent's state
    final isRemote = parentSpanContext.isRemote;
    final isSampled = parentSpanContext.traceFlags.isSampled;

    if (isRemote) {
      return isSampled
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
    } else {
      return isSampled
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
}
