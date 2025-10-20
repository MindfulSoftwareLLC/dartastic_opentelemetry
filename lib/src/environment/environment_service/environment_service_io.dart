// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io' as io;

import 'package:dartastic_opentelemetry/src/environment/environment_service/environment_service.dart';

/// Service for accessing environment variables in a consistent manner.
///
/// This abstraction allows accessing environment variables while providing
/// the ability to mock environment variables during testing, making the
/// code more testable.
///
/// The service follows the singleton pattern with a global instance
/// that can be accessed via [EnvironmentService.instance].
class EnvironmentService implements EnvironmentServiceInterface {
  static final EnvironmentService _instance = EnvironmentService._();

  /// The singleton instance of the EnvironmentService.
  static EnvironmentService get instance => _instance;

  Map<String, String> _testEnvironment = {};
  bool _useTestEnvironment = false;

  EnvironmentService._();

  /// Gets the value of an environment variable.
  ///
  /// If a test environment is set up, retrieves the value from the test
  /// environment. Otherwise, retrieves the value from the system environment.
  ///
  /// @param key The name of the environment variable to retrieve
  /// @return The value of the environment variable, or null if not found
  @override
  String? getValue(String key) {
    if (_useTestEnvironment) {
      return _testEnvironment[key];
    }
    return io.Platform.environment[key] ?? String.fromEnvironment(key);
  }

  /// Sets up a test environment for unit testing.
  ///
  /// This method allows you to provide mock environment variables for testing
  /// purposes without modifying the actual system environment.
  ///
  /// @param testEnv A map of environment variable names to their mock values
  @override
  void setupTestEnvironment(Map<String, String> testEnv) {
    _testEnvironment = Map.from(testEnv);
    _useTestEnvironment = true;
  }

  /// Clears the test environment and reverts to using the system environment.
  ///
  /// This should be called after tests that use setupTestEnvironment to
  /// ensure the test environment doesn't affect other tests.
  @override
  void clearTestEnvironment() {
    _testEnvironment.clear();
    _useTestEnvironment = false;
  }
}
