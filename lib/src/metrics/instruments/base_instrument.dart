// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

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
  bool isEnabled();

  /// The meter that created this instrument
  APIMeter get meter;

  /// Collects metrics from this instrument
  ///
  /// This is called by metric readers to gather the current metrics
  List<Metric> collectMetrics();
}

/// An SDK asynchronous instrument that can receive observations from a
/// batch callback registered with [Meter.registerBatchCallback].
///
/// A batch callback runs once per collection, before the instruments it
/// covers collect. Its observations are queued here and drained by the
/// instrument's own `collect()`, after the instrument's single-instrument
/// callbacks, so both sources land in the same collection cycle.
abstract class SDKObservableInstrument
    implements SDKInstrument, APIObservableInstrument {
  /// Queues a measurement observed by a batch callback for the next
  /// collection. The value is converted to the instrument's numeric type.
  void observeFromBatch(num value, Attributes? attributes);
}

/// Converts a [num] to the instrument's numeric type [T].
///
/// Observable callbacks and batch callbacks report [num] values, while the
/// instrument's storage is typed; an `int` instrument truncates a double.
T castNum<T extends num>(num value) {
  if (T == int) return value.toInt() as T;
  if (T == double) return value.toDouble() as T;
  return value as T;
}
