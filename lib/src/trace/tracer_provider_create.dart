// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

part of 'tracer_provider.dart';

/// Factory for creating TracerProvider instances.
///
/// This factory class provides a static create method for constructing
/// properly configured TracerProvider instances. It follows the factory
/// pattern to separate the construction logic from the TracerProvider
/// class itself.
class SDKTracerProviderCreate {
  /// Creates a new TracerProvider with the specified delegate and resource.
  ///
  /// @param delegate The API TracerProvider implementation to delegate to
  /// @param resource Optional Resource describing the entity producing telemetry
  /// @return A new TracerProvider instance
  static TracerProvider create(
      {required APITracerProvider delegate, Resource? resource}) {
    return TracerProvider._(delegate: delegate, resource: resource);
  }
}
