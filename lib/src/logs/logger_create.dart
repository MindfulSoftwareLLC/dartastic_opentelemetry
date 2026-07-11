// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

part of 'logger.dart';

/// Factory for creating OTelLogger instances.
///
/// This factory class provides a static create method for constructing
/// properly configured OTelLogger instances. It follows the factory
/// pattern to separate the construction logic from the OTelLogger
/// class itself.
@internal
class SDKLoggerCreate {
  /// Creates a new OTelLogger with the specified delegate and provider.
  ///
  /// @param delegate The API OTelLogger implementation to delegate to
  /// @param provider The LoggerProvider that created this logger
  /// @return A new OTelLogger instance
  static OTelLogger create({
    required APILogger delegate,
    required LoggerProvider provider,
  }) {
    return OTelLogger._(delegate: delegate, provider: provider);
  }
}
