// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io' as io;
import '../environment/environment_service.dart';
import '../util/otel_log.dart';
import 'web_detector.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'resource.dart';

abstract class ResourceDetector {
  Future<Resource> detect();
}

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

class EnvVarResourceDetector implements ResourceDetector {
  final EnvironmentService _environmentService;

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

// Composite detector that combines multiple detectors
class CompositeResourceDetector implements ResourceDetector {
  final List<ResourceDetector> _detectors;

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

// Factory for creating platform-appropriate detectors
class PlatformResourceDetector {
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
