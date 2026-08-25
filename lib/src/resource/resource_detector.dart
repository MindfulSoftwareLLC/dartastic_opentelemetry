// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../environment/environment_service.dart';
import '../environment/otel_env.dart';
import 'native_detectors.dart';
import 'resource.dart';
import 'web_detector.dart';

// Re-export the platform-conditional native detectors so existing
// imports of `package:dartastic_opentelemetry/src/resource/resource_detector.dart`
// continue to find `ProcessResourceDetector` and `HostResourceDetector`.
export 'native_detectors.dart'
    show HostResourceDetector, ProcessResourceDetector;

/// Interface for resource detectors that automatically discover resource information.
///
/// Resource detectors are used to automatically populate resource attributes
/// based on the environment (operating system, platform, etc.).
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/resource/sdk/#detecting-resource-information-from-the-environment
abstract class ResourceDetector {
  /// Detects resource information from the environment.
  ///
  /// @return A resource containing the detected attributes
  Future<Resource> detect();
}

/// Detects resource information from environment variables.
///
/// This detector looks for the OTEL_RESOURCE_ATTRIBUTES environment variable
/// and parses its contents into resource attributes.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#general-sdk-configuration
class EnvVarResourceDetector implements ResourceDetector {
  final EnvironmentService _environmentService;

  /// Creates a new EnvVarResourceDetector with the specified environment service.
  ///
  /// If no environment service is provided, the singleton instance will be used.
  ///
  /// @param environmentService Optional service for accessing environment variables
  EnvVarResourceDetector([EnvironmentService? environmentService])
      : _environmentService = environmentService ?? EnvironmentService.instance;

  @override
  Future<Resource> detect() async {
    if (OTelFactory.otelFactory == null) {
      throw StateError('OTel initialize must be called first.');
    }

    //TODO - OTEL_RESOURCE_ATTRIBUTES?
    final resourceAttrs = _environmentService.getValue(
      'OTEL_RESOURCE_ATTRIBUTES',
    );
    if (resourceAttrs == null || resourceAttrs.isEmpty) {
      return Resource.empty;
    }

    final attributes = OTelEnv.parseResourceAttributesString(resourceAttrs);
    return ResourceCreate.create(
        OTelFactory.otelFactory!.attributesFromMap(attributes));
  }
}

/// Composite detector that combines multiple resource detectors.
///
/// This detector runs multiple detectors and merges their results.
/// This is useful for combining resource information from different sources.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/resource/sdk/#resource-creation
class CompositeResourceDetector implements ResourceDetector {
  final List<ResourceDetector> _detectors;

  /// Creates a new CompositeResourceDetector with the specified detectors.
  ///
  /// @param detectors The list of detectors to run
  CompositeResourceDetector(this._detectors);

  @override
  Future<Resource> detect() async {
    if (OTelFactory.otelFactory == null) {
      throw StateError('OTel initialize must be called first.');
    }
    var result = Resource.empty;

    for (final detector in _detectors) {
      try {
        final resource = await detector.detect();
        result = result.merge(resource);
      } catch (e) {
        // Log error but continue with other detectors
        if (OTelLog.isError()) OTelLog.error('Error in resource detector: $e');
      }
    }

    return result;
  }
}

/// Factory for creating platform-appropriate resource detectors.
///
/// This factory creates a composite detector with the appropriate
/// detectors for the current platform (web or native).
class PlatformResourceDetector {
  /// Creates a composite detector with platform-appropriate detectors.
  ///
  /// @return A ResourceDetector that combines all appropriate detectors
  static ResourceDetector create() {
    final detectors = <ResourceDetector>[EnvVarResourceDetector()];

    // For non-web platforms (native)
    if (!const bool.fromEnvironment('dart.library.js_interop')) {
      try {
        detectors.addAll([ProcessResourceDetector(), HostResourceDetector()]);
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error('Error adding native detectors: $e');
        }
      }
    }
    // For web platforms
    else {
      try {
        detectors.add(WebResourceDetector());
      } catch (e) {
        if (OTelLog.isError()) OTelLog.error('Error adding web detector: $e');
      }
    }

    return CompositeResourceDetector(detectors);
  }
}
