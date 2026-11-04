// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

part of 'tracer_provider.dart';

/// Factory for creating TracerProvider instances.
///
/// This factory class provides a static create method for constructing
/// properly configured TracerProvider instances. It follows the factory
/// pattern to separate the construction logic from the TracerProvider
/// class itself.
@internal
class SDKTracerProviderCreate {
  /// Creates a new TracerProvider with the specified delegate and resource.
  ///
  /// @param delegate The API TracerProvider implementation to delegate to
  /// @param resource Optional Resource describing the entity producing telemetry
  /// @param spanLimits Optional span limits configuration for this provider
  /// @return A new TracerProvider instance
  static TracerProvider create({
    required APITracerProvider delegate,
    Resource? resource,
    SpanLimits? spanLimits,
  }) {
    return TracerProvider._(
      delegate: delegate,
      resource: resource,
      spanLimits: spanLimits,
    );
  }
}
