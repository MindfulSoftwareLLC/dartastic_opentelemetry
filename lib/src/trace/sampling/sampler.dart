// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Sources of sampling decisions.
///
/// Identifies where a sampling decision originated from.
enum SamplingDecisionSource {
  /// The sampling decision was based on the parent span's sampling decision.
  parentBased,

  /// The sampling decision was based on the tracer's configuration.
  tracerConfig,
}

/// The possible decisions a sampler can make.
///
/// This enum represents the possible decisions a sampler can make
/// when determining whether to sample a span.
enum SamplingDecision {
  /// The span should be recorded and sampled.
  ///
  /// This means the span will be processed by span processors and exporters,
  /// and the sampling bit in the trace flags will be set.
  recordAndSample,

  /// The span should be recorded but not sampled.
  ///
  /// This means the span will be processed by span processors and exporters,
  /// but the sampling bit in the trace flags will not be set.
  recordOnly,

  /// The span should be dropped.
  ///
  /// This means the span will not be processed by span processors or exporters.
  drop,
}

/// Result of a sampling decision.
///
/// This class encapsulates the decision made by a sampler, along with
/// any additional information about the decision.
class SamplingResult {
  /// The sampling decision.
  final SamplingDecision decision;

  /// The source of the sampling decision.
  final SamplingDecisionSource source;

  /// Additional attributes to add to the span.
  ///
  /// Some samplers may add attributes to a span to provide additional
  /// information about the sampling decision.
  final Attributes? attributes;

  /// The TraceState to associate with the Span through the new
  /// SpanContext (Trace SDK spec, ShouldSample).
  ///
  /// Samplers SHOULD normally return the passed-in parent TraceState
  /// (reachable via `parentContext.spanContext?.traceState`) if they do
  /// not intend to change it — all built-in samplers do. Returning an
  /// empty TraceState clears the span's TraceState. Returning null means
  /// the sampler has no opinion and the SDK keeps the TraceState
  /// inherited from the parent, so samplers written before this field
  /// existed keep their inheritance behavior.
  final TraceState? traceState;

  /// Creates a new sampling result.
  ///
  /// @param decision The sampling decision
  /// @param source The source of the sampling decision
  /// @param attributes Optional attributes to add to the span
  /// @param traceState Optional TraceState for the new SpanContext
  const SamplingResult({
    required this.decision,
    required this.source,
    this.attributes,
    this.traceState,
  });
}

/// Interface for sampling decision logic.
///
/// Samplers are responsible for deciding whether a span should be sampled
/// (i.e., recorded and exported) or not. This decision is typically made
/// when a span is started, based on various factors such as the parent
/// context, trace ID, and span attributes.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/trace/sdk/#sampler
abstract class Sampler {
  /// Gets a description of this sampler.
  ///
  /// This description is included in the recorded data to identify
  /// the sampler that made the sampling decision.
  ///
  /// @return A human-readable description of the sampler
  String get description;

  /// Makes a sampling decision based on the provided parameters.
  ///
  /// This method is called when a span is started to determine whether
  /// it should be sampled.
  ///
  /// @param parentContext The parent context containing the parent span
  /// @param traceId The trace ID of the span
  /// @param name The name of the span
  /// @param spanKind The kind of the span
  /// @param attributes The attributes of the span
  /// @param links The links to other spans
  /// @return A sampling result containing the decision and other information
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  });
}
