// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.


part of 'tracer.dart';

/// Factory for creating SDKTracerProvider instances
class SDKTracerCreate {
  static APITracer create({
    required APITracer delegate,
    required TracerProvider provider,
    Sampler? sampler
  }) {
    return Tracer._(
      delegate: delegate,
      provider: provider,
      sampler: sampler
    );
  }
}
