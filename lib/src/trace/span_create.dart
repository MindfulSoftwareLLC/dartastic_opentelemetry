// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

part of 'span.dart';

/// Factory for creating Span instances.
///
/// This factory class provides a static create method for constructing
/// properly configured Span instances. It follows the factory pattern
/// to separate the construction logic from the Span class itself.
class SDKSpanCreate {
  /// Creates a new Span with the specified delegate and tracer.
  ///
  /// @param delegateSpan The API Span implementation to delegate to
  /// @param sdkTracer The SDK Tracer that created this Span
  /// @return A new Span instance
  static Span create({
    required APISpan delegateSpan,
    required Tracer sdkTracer
  }) {
    return Span._(delegateSpan, sdkTracer);
  }
}
