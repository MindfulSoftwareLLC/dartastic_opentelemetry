// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Aggregation defines how measurements for a metric are aggregated.
enum AggregationType {
  /// Sum aggregation accumulates the sum of measurements.
  sum,

  /// LastValue aggregation stores the last reported value.
  lastValue,

  /// Histogram aggregation computes statistics over measurements.
  histogram,

  /// Drop aggregation discards all measurements.
  drop,

  /// Default aggregation selects the appropriate aggregation based on instrument type.
  defaultAggregation,
}

/// View allows for customizing how metrics are collected and exported.
///
/// A View can:
/// - Filter which instruments are processed
/// - Customize aggregation
/// - Specify which attributes to include
/// - Rename metrics
class View {
  /// The name to use for the metric stream.
  /// If null, the original instrument name is used.
  final String? name;

  /// The description to use for the metric.
  /// If null, the original instrument description is used.
  final String? description;

  /// The instrument name pattern to match.
  /// Supports * as a wildcard.
  final String instrumentNamePattern;

  /// The instrument type to match.
  /// If null, all instrument types are matched.
  final Type? instrumentType;

  /// The meter name to match.
  /// If null, all meter names are matched.
  final String? meterName;

  /// The aggregation type to use.
  final AggregationType aggregationType;

  /// The attributes to include.
  /// If null, all attributes are included.
  final List<String>? attributeKeys;

  /// Creates a new View.
  ///
  /// [instrumentNamePattern] The pattern to match instrument names against.
  /// Use * as a wildcard to match multiple instruments.
  View({
    this.name,
    this.description,
    required this.instrumentNamePattern,
    this.instrumentType,
    this.meterName,
    this.aggregationType = AggregationType.defaultAggregation,
    this.attributeKeys,
  });

  /// Creates a view that matches all instruments.
  factory View.all({
    String? name,
    String? description,
    AggregationType aggregationType = AggregationType.defaultAggregation,
    List<String>? attributeKeys,
  }) {
    return View(
      name: name,
      description: description,
      instrumentNamePattern: '*',
      aggregationType: aggregationType,
      attributeKeys: attributeKeys,
    );
  }

  /// Checks if this view matches the given instrument.
  bool matches(String instrumentName, APIInstrument instrument) {
    // Check instrument name pattern
    if (!_matchesPattern(instrumentName, instrumentNamePattern)) {
      return false;
    }

    // Check instrument type if specified
    if (instrumentType != null) {
      if (instrumentType == APICounter && !_isCounter(instrument)) {
        return false;
      } else if (instrumentType == APIUpDownCounter &&
          !_isUpDownCounter(instrument)) {
        return false;
      } else if (instrumentType == APIHistogram && !_isHistogram(instrument)) {
        return false;
      } else if (instrumentType == APIGauge && !_isGauge(instrument)) {
        return false;
      } else if (instrumentType == APIObservableCounter &&
          !_isObservableCounter(instrument)) {
        return false;
      } else if (instrumentType == APIObservableUpDownCounter &&
          !_isObservableUpDownCounter(instrument)) {
        return false;
      } else if (instrumentType == APIObservableGauge &&
          !_isObservableGauge(instrument)) {
        return false;
      }
    }

    // Check meter name if specified
    if (meterName != null && meterName != instrument.meter.name) {
      return false;
    }

    return true;
  }

  bool _matchesPattern(String name, String pattern) {
    if (pattern == '*') {
      return true;
    }

    // Simple pattern matching for * wildcards
    if (pattern.contains('*')) {
      final regex = RegExp('^${pattern.replaceAll('*', '.*')}\$');
      return regex.hasMatch(name);
    }

    return name == pattern;
  }

  bool _isCounter(APIInstrument instrument) {
    return instrument is APICounter;
  }

  bool _isUpDownCounter(APIInstrument instrument) {
    return instrument is APIUpDownCounter;
  }

  bool _isHistogram(APIInstrument instrument) {
    return instrument is APIHistogram;
  }

  bool _isGauge(APIInstrument instrument) {
    return instrument is APIGauge;
  }

  bool _isObservableCounter(APIInstrument instrument) {
    return instrument is APIObservableCounter;
  }

  bool _isObservableUpDownCounter(APIInstrument instrument) {
    return instrument is APIObservableUpDownCounter;
  }

  bool _isObservableGauge(APIInstrument instrument) {
    return instrument is APIObservableGauge;
  }
}
