// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

part of 'logger.dart';

/// Factory for creating Logger instances.
///
/// This factory class provides a static create method for constructing
/// properly configured Logger instances. It follows the factory
/// pattern to separate the construction logic from the Logger
/// class itself.
class SDKLoggerCreate {
  /// Creates a new Logger with the specified delegate and provider.
  ///
  /// @param delegate The API Logger implementation to delegate to
  /// @param provider The LoggerProvider that created this logger
  /// @return A new Logger instance
  static Logger create({
    required APILogger delegate,
    required LoggerProvider provider,
  }) {
    return Logger._(delegate: delegate, provider: provider);
  }
}
