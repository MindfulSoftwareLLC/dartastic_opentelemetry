// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
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

/// Base class for sampling conditions
abstract class SamplingCondition implements Sampler {
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

/// Error-based sampling condition
class ErrorSamplingCondition extends SamplingCondition {
  ErrorSamplingCondition();

  @override
  String get description => 'ErrorSamplingCondition';

  @override
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

/// Name pattern-based sampling condition
class NamePatternSamplingCondition extends SamplingCondition {
  final Pattern pattern;

  NamePatternSamplingCondition(this.pattern);

  @override
  String get description => 'NamePatternSamplingCondition{$pattern}';

  @override
  bool shouldSampleCondition({
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
  }) {
    return name.contains(pattern);
  }
}

/// Attribute-based sampling condition
class AttributeSamplingCondition extends SamplingCondition {
  final String key;
  final String? stringValue;
  final bool? boolValue;
  final int? intValue;
  final double? doubleValue;

  @override
  String get description => 'AttributeSamplingCondition{$key}';

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
