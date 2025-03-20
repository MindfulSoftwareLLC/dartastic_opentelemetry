// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.


part of 'meter.dart';

/// Factory for creating SDKMeterProvider instances
class SDKMeterCreate {
  static APIMeter create({
    required APIMeter delegate,
    required MeterProvider provider,
  }) {
    return Meter._(
      delegate: delegate,
      provider: provider,
    );
  }
}
