// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io' as io;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../environment/environment_service.dart';
import 'resource.dart';
import 'web_detector.dart';

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

/// Detects process-related resource information.
///
/// This detector populates resource attributes with information about the
/// current process, such as executable name, command line, and runtime information.
///
/// Semantic conventions:
/// https://opentelemetry.io/docs/specs/semconv/resource/process/
class ProcessResourceDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    if (OTelFactory.otelFactory == null) {
      throw 'OTel initialize must be called first.';
    }
    return ResourceCreate.create(OTelFactory.otelFactory!.attributesFromMap({
      'process.executable.name': io.Platform.executable,
      'process.command_line': io.Platform.executableArguments.join(' '),
      'process.runtime.name': 'dart',
      'process.runtime.version': io.Platform.version,
      'process.num_threads': io.Platform.numberOfProcessors.toString(),
    }));
  }
}

/// Detects host-related resource information.
///
/// This detector populates resource attributes with information about the
/// host machine, such as hostname, architecture, and operating system details.
///
/// Semantic conventions:
/// https://opentelemetry.io/docs/specs/semconv/resource/host/
class HostResourceDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    if (OTelFactory.otelFactory == null) {
      throw 'OTel initialize must be called first.';
    }
    final Map<String, Object> attributes = {
      'host.name': io.Platform.localHostname,
      'host.arch': io.Platform.localHostname,
      'host.processors': io.Platform.numberOfProcessors,
      'host.os.name': io.Platform.operatingSystem,
      'host.locale': io.Platform.localeName,
    };

    // Add OS-specific information
    if (io.Platform.isLinux) {
      attributes['os.type'] = 'linux';
    } else if (io.Platform.isWindows) {
      attributes['os.type'] = 'windows';
    } else if (io.Platform.isMacOS) {
      attributes['os.type'] = 'macos';
    } else if (io.Platform.isAndroid) {
      attributes['os.type'] = 'android';
    } else if (io.Platform.isIOS) {
      attributes['os.type'] = 'ios';
    }

    attributes['os.version'] = io.Platform.operatingSystemVersion;

    return ResourceCreate.create(OTelFactory.otelFactory!.attributesFromMap(attributes));
  }
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
      throw 'OTel initialize must be called first.';
    }

    //TODO - OTEL_RESOURCE_ATTRIBUTES?
    final resourceAttrs = _environmentService.getValue('OTEL_RESOURCE_ATTRIBUTES');
    if (resourceAttrs == null || resourceAttrs.isEmpty) {
      return Resource.empty;
    }

    final attributes = _parseResourceAttributes(resourceAttrs);
    return ResourceCreate.create(attributes);
  }

  /// Parses the OTEL_RESOURCE_ATTRIBUTES environment variable.
  ///
  /// The format is a comma-separated list of key=value pairs.
  /// For example: key1=value1,key2=value2
  ///
  /// Commas can be escaped with a backslash, and the values can be
  /// percent-encoded.
  ///
  /// @param envValue The value of the OTEL_RESOURCE_ATTRIBUTES environment variable
  /// @return Attributes parsed from the environment variable
  Attributes _parseResourceAttributes(String envValue) {
    final Map<String, Object> attributes = {};

    // Split on commas, but handle escaped commas
    final parts = envValue.split(RegExp(r'(?<!\\),'));

    for (var part in parts) {
      // Remove any leading/trailing whitespace
      part = part.trim();

      // Split on first equals sign
      final keyValue = part.split('=');
      if (keyValue.length != 2) continue;

      final key = keyValue[0].trim();
      var value = keyValue[1].trim();

      // Handle percent-encoded characters
      value = Uri.decodeComponent(value);

      // Remove escape characters
      value = value.replaceAll(r'\,', ',');

      attributes[key] = value;
    }

    return OTelFactory.otelFactory!.attributesFromMap(attributes);
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
      throw 'OTel initialize must be called first.';
    }
    Resource result = Resource.empty;

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
    final detectors = <ResourceDetector>[
      EnvVarResourceDetector(),
    ];

    // For non-web platforms (native)
    if (!const bool.fromEnvironment('dart.library.js_interop')) {
      try {
        detectors.addAll([
          ProcessResourceDetector(),
          HostResourceDetector(),
        ]);
      } catch (e) {
        if (OTelLog.isError()) OTelLog.error('Error adding native detectors: $e');
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
