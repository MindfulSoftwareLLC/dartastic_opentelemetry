// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

part of 'logger_provider.dart';

/// Factory for creating LoggerProvider instances.
///
/// This factory class provides a static create method for constructing
/// properly configured LoggerProvider instances. It follows the factory
/// pattern to separate the construction logic from the LoggerProvider
/// class itself.
@internal
class SDKLoggerProviderCreate {
  /// Creates a new LoggerProvider with the specified delegate and resource.
  ///
  /// @param delegate The API LoggerProvider implementation to delegate to
  /// @param resource Optional Resource describing the entity producing telemetry
  /// @return A new LoggerProvider instance
  static LoggerProvider create({
    required APILoggerProvider delegate,
    Resource? resource,
  }) {
    return LoggerProvider._(delegate: delegate, resource: resource);
  }
}
