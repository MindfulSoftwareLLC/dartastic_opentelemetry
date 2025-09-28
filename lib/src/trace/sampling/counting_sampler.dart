// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'sampler.dart';

/// A sampler that samples every Nth request.
/// Optionally can be combined with conditions to override the count-based decision.
class CountingSampler implements Sampler {
  final int _countInterval;
  final List<SamplingCondition> _overrideConditions;
  int _currentCount = 0;

  @override
  String get description => 'CountingSampler{interval=$_countInterval}';

  /// Creates a sampler that samples every Nth request.
  /// [countInterval] must be positive.
  /// [overrideConditions] are optional conditions that can force sampling regardless of count.
  CountingSampler(
    int countInterval, {
    List<SamplingCondition>? overrideConditions,
  })  : _countInterval = countInterval,
        _overrideConditions = overrideConditions ?? [] {
    if (countInterval <= 0) {
      throw ArgumentError('countInterval must be positive');
    }
  }

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    // Check override conditions first
    for (final condition in _overrideConditions) {
      if (condition.shouldSampleCondition(
        name: name,
        spanKind: spanKind,
        attributes: attributes,
      )) {
        return const SamplingResult(
          decision: SamplingDecision.recordAndSample,
          source: SamplingDecisionSource.tracerConfig,
        );
      }
    }

    // Increment counter and check if we should sample
    _currentCount = (_currentCount + 1) % _countInterval;
    final shouldSample = _currentCount == 0;

    return SamplingResult(
      decision: shouldSample
          ? SamplingDecision.recordAndSample
          : SamplingDecision.drop,
      source: SamplingDecisionSource.tracerConfig,
    );
  }
}

/// Base class for sampling conditions that can be used with the CountingSampler
/// to override its default behavior based on span properties.
abstract class SamplingCondition implements Sampler {
  /// Determines whether a span should be sampled based on its properties.
  ///
  /// @param name The name of the span
  /// @param spanKind The kind of span
  /// @param attributes The attributes of the span
  /// @return true if the span should be sampled, false otherwise
  bool shouldSampleCondition({
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
  });

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    final shouldRecord = shouldSampleCondition(
      name: name,
      spanKind: spanKind,
      attributes: attributes,
    );

    return SamplingResult(
      decision: shouldRecord
          ? SamplingDecision.recordAndSample
          : SamplingDecision.drop,
      source: SamplingDecisionSource.tracerConfig,
    );
  }
}

/// A sampling condition that forces sampling when a span has an error status.
///
/// This condition can be used to ensure that all spans with errors are sampled,
/// regardless of other sampling decisions.
class ErrorSamplingCondition extends SamplingCondition {
  /// Creates a new ErrorSamplingCondition.
  ///
  /// This condition samples spans that have an error status, ensuring that all
  /// spans with errors are recorded even when other sampling strategies might skip them.
  ErrorSamplingCondition();

  /// Returns the string description of this sampling condition.
  ///
  /// This is used for logging and debugging purposes.
  @override
  String get description => 'ErrorSamplingCondition';

  @override

  /// Determines whether a span should be sampled based on its properties.
  ///
  /// @param name The name of the span
  /// @param spanKind The kind of span
  /// @param attributes The attributes of the span
  /// @return true if the span should be sampled, false otherwise
  bool shouldSampleCondition({
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
  }) {
    if (attributes == null) return false;

    // Check for error status
    final statusCode = attributes.getString('otel.status_code');
    final statusMessage = attributes.getString('otel.status_description');

    return (statusCode == 'ERROR' ||
        (statusMessage != null && statusMessage.isNotEmpty));
  }
}

/// A sampling condition that forces sampling when a span's name matches a pattern.
///
/// This condition can be used to ensure that spans with names matching a specific
/// pattern are always sampled, regardless of other sampling decisions.
class NamePatternSamplingCondition extends SamplingCondition {
  /// the pattern to match
  final Pattern pattern;

  /// Creates a new NamePatternSamplingCondition with the specified pattern.
  ///
  /// This condition samples spans whose names match the given pattern, allowing
  /// targeted sampling of specific operations.
  ///
  /// @param pattern The pattern to match against span names
  NamePatternSamplingCondition(this.pattern);

  /// Returns a string description of this sampling condition.
  @override
  String get description => 'NamePatternSamplingCondition{$pattern}';

  @override

  /// Determines whether a span should be sampled based on its properties.
  ///
  /// This method checks if the span name matches the pattern specified in the constructor.
  ///
  /// @param name The name of the span to check against the pattern
  /// @param spanKind The kind of span (not used in this implementation)
  /// @param attributes The attributes of the span (not used in this implementation)
  /// @return true if the span's name matches the pattern, false otherwise
  bool shouldSampleCondition({
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
  }) {
    return name.contains(pattern);
  }
}

/// A sampling condition that forces sampling when a span has a specific attribute value.
///
/// This condition can be used to ensure that spans with particular attribute values
/// are always sampled, regardless of other sampling decisions.
class AttributeSamplingCondition extends SamplingCondition {
  /// The attribute key to check when determining whether to sample.
  final String key;

  /// The string value to match against the attribute, if this is a string attribute.
  final String? stringValue;

  /// The boolean value to match against the attribute, if this is a boolean attribute.
  final bool? boolValue;

  /// The integer value to match against the attribute, if this is an integer attribute.
  final int? intValue;

  /// The double value to match against the attribute, if this is a double attribute.
  final double? doubleValue;

  /// Returns a string description of this sampling condition.
  ///
  /// Used for logging and debugging purposes.
  @override
  String get description => 'AttributeSamplingCondition{$key}';

  /// Creates a new AttributeSamplingCondition that matches spans with a specific attribute value.
  ///
  /// This condition samples spans that have an attribute with the specified key and value.
  /// Only one of the type-specific values (stringValue, boolValue, intValue, doubleValue)
  /// should be provided.
  ///
  /// @param key The attribute key to match
  /// @param stringValue Optional string value to match
  /// @param boolValue Optional boolean value to match
  /// @param intValue Optional integer value to match
  /// @param doubleValue Optional double value to match
  AttributeSamplingCondition(this.key,
      {this.stringValue, this.boolValue, this.intValue, this.doubleValue}) {
    int nonNullCount = 0;
    if (stringValue != null) {
      nonNullCount++;
    }
    if (boolValue != null) {
      nonNullCount++;
    }
    if (intValue != null) {
      nonNullCount++;
    }
    if (doubleValue != null) {
      nonNullCount++;
    }
    if (nonNullCount != 1) {
      throw ArgumentError(
          'One of the type values must be non-null. string: $stringValue, bool: $boolValue, int: $intValue, double: $doubleValue');
    }
  }

  @override

  /// Determines whether a span should be sampled based on its properties.
  ///
  /// This method checks if the span has attributes matching the specific key and value
  /// configured in this condition.
  ///
  /// @param name The name of the span
  /// @param spanKind The kind of span
  /// @param attributes The attributes of the span
  /// @return true if the span's attributes match the configured values, false otherwise
  bool shouldSampleCondition({
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
  }) {
    if (attributes == null) {
      return false;
    }
    if (stringValue != null) {
      return attributes.getString(key) == stringValue;
    }
    if (boolValue != null) {
      return attributes.getBool(key) == boolValue;
    }
    if (intValue != null) {
      return attributes.getInt(key) == intValue;
    }
    if (doubleValue != null) {
      return attributes.getDouble(key) == doubleValue;
    }
    return false;
  }
}
