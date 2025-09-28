// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

part of 'tracer.dart';

/// Factory for creating Tracer instances.
///
/// This factory class provides a static create method for constructing
/// properly configured Tracer instances. It follows the factory pattern
/// to separate the construction logic from the Tracer class itself.
class SDKTracerCreate {
  /// Creates a new Tracer with the specified delegate, provider, and optional sampler.
  ///
  /// @param delegate The API Tracer implementation to delegate to
  /// @param provider The TracerProvider that created this Tracer
  /// @param sampler Optional custom sampler for this Tracer
  /// @return A new APITracer instance (actually a Tracer implementation)
  static APITracer create(
      {required APITracer delegate,
      required TracerProvider provider,
      Sampler? sampler}) {
    return Tracer._(delegate: delegate, provider: provider, sampler: sampler);
  }
}
