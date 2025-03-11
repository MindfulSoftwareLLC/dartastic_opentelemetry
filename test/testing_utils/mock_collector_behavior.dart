// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:grpc/grpc.dart' as grpc;

class MockCollectorBehavior {
  final int initialFailures;
  final List<bool>? failurePattern;
  final int failureType;
  final Duration? artificialDelay;
  
  // Track attempts per unique span export, based on name+id combination
  final Map<String, int> _attemptsPerSpan = {};

  MockCollectorBehavior({
    this.initialFailures = 0,
    this.failurePattern,
    this.failureType = grpc.StatusCode.unavailable,
    this.artificialDelay,
  });

  bool shouldFail(String exportId) {
    _attemptsPerSpan[exportId] = (_attemptsPerSpan[exportId] ?? 0) + 1;
    final currentAttempt = _attemptsPerSpan[exportId]! - 1;

    if (failurePattern != null) {
      return failurePattern![currentAttempt % failurePattern!.length];
    }
    return currentAttempt < initialFailures;
  }

  void reset() {
    _attemptsPerSpan.clear();
  }
}