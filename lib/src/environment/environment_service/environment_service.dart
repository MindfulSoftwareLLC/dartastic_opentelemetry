// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

export 'environment_service_io.dart'
    if (dart.library.js_interop) 'environment_service_web.dart';

/// Interface for accessing environment variables in a consistent manner.
///
/// This abstraction allows accessing environment variables while providing
/// the ability to mock environment variables during testing, making the
/// code more testable.
abstract interface class EnvironmentServiceInterface {
  const EnvironmentServiceInterface._();

  /// Gets the value of an environment variable.
  ///
  /// If a test environment is set up, retrieves the value from the test
  /// environment. Otherwise, retrieves the value from the system environment.
  ///
  /// @param key The name of the environment variable to retrieve
  /// @return The value of the environment variable, or null if not found
  String? getValue(String key);

  /// Sets up a test environment for unit testing.
  ///
  /// This method allows you to provide mock environment variables for testing
  /// purposes without modifying the actual system environment.
  ///
  /// @param testEnv A map of environment variable names to their mock values
  void setupTestEnvironment(Map<String, String> testEnv);

  /// Clears the test environment and reverts to using the system environment.
  ///
  /// This should be called after tests that use setupTestEnvironment to
  /// ensure the test environment doesn't affect other tests.
  void clearTestEnvironment();
}
