// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

part of 'tracer_provider.dart';

/// Internal constructor access for TracerProvider
class SDKTracerProviderCreate {
  /// Creates a TracerProvider, only accessible within library
  static TracerProvider create({required APITracerProvider delegate, Resource? resource}) {
    return TracerProvider._(delegate: delegate, resource: resource);
  }
}

