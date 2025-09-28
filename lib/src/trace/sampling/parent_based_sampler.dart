// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'always_off_sampler.dart';
import 'always_on_sampler.dart';
import 'sampler.dart';

/// A sampler that respects the parent span's sampling decision.
///
/// This sampler implements a composite sampling strategy that bases its
/// decision on the parent span's sampling decision. If there is no parent
/// span, or if the parent is not valid, it uses a root sampler to make
/// the decision.
///
/// This is particularly important for maintaining complete traces across
/// service boundaries, ensuring that a trace is either fully sampled or
/// not sampled at all across its entire path.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/trace/sdk/#parentbased
class ParentBasedSampler implements Sampler {
  final Sampler _root;
  final Sampler _remoteParentSampled;
  final Sampler _remoteParentNotSampled;
  final Sampler _localParentSampled;
  final Sampler _localParentNotSampled;

  /// Gets a description of this sampler.
  ///
  /// @return A description including the root sampler's description
  @override
  String get description => 'ParentBased{root=${_root.description}}';

  /// Creates a parent-based sampler with the specified configuration.
  ///
  /// @param root The sampler to use when there is no parent span
  /// @param remoteParentSampled The sampler to use when the remote parent is sampled (defaults to AlwaysOnSampler)
  /// @param remoteParentNotSampled The sampler to use when the remote parent is not sampled (defaults to AlwaysOffSampler)
  /// @param localParentSampled The sampler to use when the local parent is sampled (defaults to AlwaysOnSampler)
  /// @param localParentNotSampled The sampler to use when the local parent is not sampled (defaults to AlwaysOffSampler)
  ParentBasedSampler(
    this._root, {
    Sampler? remoteParentSampled,
    Sampler? remoteParentNotSampled,
    Sampler? localParentSampled,
    Sampler? localParentNotSampled,
  })  : _remoteParentSampled = remoteParentSampled ?? const AlwaysOnSampler(),
        _remoteParentNotSampled =
            remoteParentNotSampled ?? const AlwaysOffSampler(),
        _localParentSampled = localParentSampled ?? const AlwaysOnSampler(),
        _localParentNotSampled =
            localParentNotSampled ?? const AlwaysOffSampler();

  /// Makes a sampling decision based on the parent context.
  ///
  /// This method checks if there's a valid parent span context in the parent context.
  /// If there is, it uses the appropriate sampler based on whether the parent is
  /// remote or local, and whether it is sampled or not. If there's no valid parent,
  /// it uses the root sampler.
  ///
  /// @param parentContext The parent context containing the parent span
  /// @param traceId The trace ID of the span
  /// @param name The name of the span
  /// @param spanKind The kind of the span
  /// @param attributes The attributes of the span
  /// @param links The links to other spans
  /// @return A sampling result based on the appropriate sampler's decision
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
