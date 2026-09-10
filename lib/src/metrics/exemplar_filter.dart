// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// An ExemplarFilter evaluates a measurement to determine if an Exemplar should
/// be sampled.
abstract class ExemplarFilter {
  /// Evaluates whether an exemplar should be sampled for the given measurement.
  ///
  /// @param value The value of the measurement.
  /// @param attributes The attributes associated with the measurement.
  /// @param context The Context associated with the measurement.
  /// @return true if the measurement should be sampled as an exemplar, false otherwise.
  bool shouldSample(num value, Attributes attributes, Context context);
}

/// An ExemplarFilter which samples all measurements.
class AlwaysOnExemplarFilter implements ExemplarFilter {
  const AlwaysOnExemplarFilter();

  @override
  bool shouldSample(num value, Attributes attributes, Context context) {
    return true;
  }
}

/// An ExemplarFilter which samples no measurements.
class AlwaysOffExemplarFilter implements ExemplarFilter {
  const AlwaysOffExemplarFilter();

  @override
  bool shouldSample(num value, Attributes attributes, Context context) {
    return false;
  }
}

/// An ExemplarFilter which makes its sampling decisions based on the trace context.
///
/// It only samples measurements if the context contains a sampled trace.
class TraceBasedExemplarFilter implements ExemplarFilter {
  const TraceBasedExemplarFilter();

  @override
  bool shouldSample(num value, Attributes attributes, Context context) {
    final spanContext = context.spanContext;
    return spanContext != null &&
        spanContext.isValid &&
        spanContext.traceFlags.isSampled;
  }
}
