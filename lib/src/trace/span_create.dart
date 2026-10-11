// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

part of 'span.dart';

/// Factory for creating Span instances.
///
/// This factory class provides a static create method for constructing
/// properly configured Span instances. It follows the factory pattern
/// to separate the construction logic from the Span class itself.
@internal
class SDKSpanCreate {
  /// Creates a new Span with the specified delegate and tracer.
  ///
  /// @param delegateSpan The API Span implementation to delegate to
  /// @param sdkTracer The SDK Tracer that created this Span
  /// @param isRecording Whether the span records data, per the sampling
  ///   decision made at creation time (see the Trace SDK spec, ShouldSample).
  /// @return A new Span instance
  static Span create({
    required APISpan delegateSpan,
    required Tracer sdkTracer,
    SpanLimits? spanLimits,
    SpanLimitEnforcer? enforcer,
    bool isRecording = true,
  }) {
    final effectiveLimits = spanLimits ?? sdkTracer.provider.spanLimits;
    return Span._(
      delegateSpan,
      sdkTracer,
      enforcer:
          enforcer ?? (isRecording ? SpanLimitEnforcer(effectiveLimits) : null),
      isRecording: isRecording,
    );
  }
}
