// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

part of 'meter_provider.dart';

/// Internal constructor access for TracerProvider
class SDKMeterProviderCreate {
  /// Creates a TracerProvider, only accessible within library
  static MeterProvider create(
      {required APIMeterProvider delegate, Resource? resource}) {
    return MeterProvider._(delegate: delegate, resource: resource);
  }
}
