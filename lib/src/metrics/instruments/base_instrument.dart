// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../../../dartastic_opentelemetry.dart';

/// BaseInstrument is the base class for all metric instruments.
///
/// It provides common functionality for collecting metrics from instruments.
abstract class SDKInstrument {
  /// The name of the instrument
  String get name;

  /// The description of the instrument
  String? get description;

  /// The unit of the instrument
  String? get unit;

  /// Whether the instrument is enabled
  bool get enabled;

  /// The meter that created this instrument
  APIMeter get meter;

  /// Collects metrics from this instrument
  ///
  /// This is called by metric readers to gather the current metrics
  List<Metric> collectMetrics();
}
