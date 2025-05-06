// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'sampler.dart';

/// A sampler that limits the number of sampled traces per time window.
class RateLimitingSampler implements Sampler {
  final double _maxTracesPerSecond;
  final Duration _timeWindow;
  double _tokenBalance;
  DateTime _lastTokenUpdate;
  late final Timer _tokenReplenishTimer;

  @override
  String get description => 'RateLimitingSampler{$_maxTracesPerSecond per second}';

  /// Creates a rate limiting sampler.
  /// [maxTracesPerSecond] specifies how many traces can be sampled per second.
  /// [timeWindow] specifies how often the token balance is updated (defaults to 100ms).
  RateLimitingSampler(
    double maxTracesPerSecond, {
    Duration timeWindow = const Duration(milliseconds: 100),
  })  : _maxTracesPerSecond = maxTracesPerSecond,
        _timeWindow = timeWindow,
        _tokenBalance = maxTracesPerSecond, // Start with tokens already available
        _lastTokenUpdate = DateTime.now() {
    if (maxTracesPerSecond <= 0) {
      throw ArgumentError('maxTracesPerSecond must be positive');
    }
    _updateTokens();
    _tokenReplenishTimer = Timer.periodic(timeWindow, (_) => _updateTokens());
  }

  void _updateTokens() {
    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastTokenUpdate).inMilliseconds / 1000;
    _lastTokenUpdate = now;

    // Calculate how many tokens to add based on elapsed time and rate
    // Don't use floor() to ensure even small time periods add tokens
    final tokensToAdd = _maxTracesPerSecond * elapsedSeconds;

    // Calculate max tokens based on rate and time window
    final maxTokens = _maxTracesPerSecond * _timeWindow.inMilliseconds / 1000;

    // Update balance, ensuring we don't exceed max
    _tokenBalance = (_tokenBalance + tokensToAdd).clamp(0.0, maxTokens);
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
    // Update tokens first
    _updateTokens();

    // If we have tokens available, sample the trace
    if (_tokenBalance >= 1.0) {
      _tokenBalance -= 1.0;
      return const SamplingResult(
        decision: SamplingDecision.recordAndSample,
        source: SamplingDecisionSource.tracerConfig,
      );
    }

    return const SamplingResult(
      decision: SamplingDecision.drop,
      source: SamplingDecisionSource.tracerConfig,
    );
  }

  /// Clean up timer resources
  void dispose() {
    _tokenReplenishTimer.cancel();
  }
}
