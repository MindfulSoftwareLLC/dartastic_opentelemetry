// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

part of 'meter.dart';

/// Factory for creating Meter instances.
///
/// This factory class provides a static create method for constructing
/// properly configured Meter instances. It follows the factory pattern
/// to separate the construction logic from the Meter class itself.
class MeterCreate {
  /// Creates a new Meter with the specified delegate and provider.
  ///
  /// @param delegate The API Meter implementation to delegate to
  /// @param provider The MeterProvider that created this Meter
  /// @return A new Meter instance
  static Meter create({
    required APIMeter delegate,
    required MeterProvider provider,
  }) {
    return Meter._(
      delegate: delegate,
      provider: provider,
    );
  }
}
