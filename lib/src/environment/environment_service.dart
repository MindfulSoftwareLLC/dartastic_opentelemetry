// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io' as io;

/// Service for accessing environment variables
/// This abstraction allows for testing with mock environment variables
class EnvironmentService {
  static final EnvironmentService _instance = EnvironmentService._();
  static EnvironmentService get instance => _instance;

  Map<String, String> _testEnvironment = {};
  bool _useTestEnvironment = false;

  EnvironmentService._();

  /// Gets the environment variable value
  String? getValue(String key) {
    if (_useTestEnvironment) {
      return _testEnvironment[key];
    }
    return io.Platform.environment[key];
  }

  /// For testing: sets up a test environment
  void setupTestEnvironment(Map<String, String> testEnv) {
    _testEnvironment = Map.from(testEnv);
    _useTestEnvironment = true;
  }

  /// For testing: clears the test environment
  void clearTestEnvironment() {
    _testEnvironment.clear();
    _useTestEnvironment = false;
  }
}