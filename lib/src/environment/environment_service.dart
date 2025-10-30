// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

export 'environment_service_io.dart'
    if (dart.library.js_interop) 'environment_service_web.dart';

/// Interface for accessing environment variables in a platform-independent manner.
///
/// The Dart platform respects POSIX environmental variables (env vars) while
/// also creating a second env var namespace when compiling or running with
/// --dart-define flags.
///
/// The OpenTelemetry Specification requires the support of env vars. This Dart
/// implementation extends the meaning of env vars to include --dart-define
/// constants that are "baked into" the Dart compilation or interpreter.
///
/// If a value is defined with --dart-define, it takes precedence over POSIX
/// env vars. If a value is not defined with --dart-define, the system env var
/// is used. If neither is defined, null is returned.
///
/// For the web platform, only --dart-define values are available since
/// io.Platform is not accessible in browsers.
///
/// Environment variable lookup priority (non-web):
/// 1. String.fromEnvironment (--dart-define values)
/// 2. io.Platform.environment (system environment variables)
///
/// Environment variable lookup priority (web):
/// 1. String.fromEnvironment (--dart-define values only)
///
/// Example usages:
/// ```bash
/// # Using system environment variables (non-web only)
/// export OTEL_SERVICE_NAME=my-app
/// dart run
///
/// # Using --dart-define (works on all platforms including web)
/// flutter run --dart-define=OTEL_SERVICE_NAME=my-app \
///             --dart-define=OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318
///
/// # Mixing both (--dart-define takes precedence)
/// export OTEL_SERVICE_NAME=from-env
/// dart run --dart-define=OTEL_SERVICE_NAME=from-dart-define
/// # Result: "from-dart-define" is used
/// ```
///
abstract interface class EnvironmentServiceInterface {
  const EnvironmentServiceInterface._();

  /// Gets the value of an environment variable.
  ///
  /// Returns the value from the first available source based on platform.
  ///
  /// @param key The name of the environment variable to retrieve
  /// @return The value of the environment variable, or null if not found
  String? getValue(String key);
}
