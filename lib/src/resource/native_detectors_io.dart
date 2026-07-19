// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Native (VM / Flutter mobile / Flutter desktop) implementations of the
// resource detectors that read from `dart:io`. Imported only on
// non-web platforms via the conditional export in `native_detectors.dart`.

import 'dart:io' as io;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'resource.dart';
import 'resource_detector.dart';

/// Detects process-related resource information.
///
/// Populates resource attributes with information about the current process
/// (executable name, command line, runtime). Native-only — `dart:io` is
/// not available in the browser.
///
/// Semantic conventions:
/// https://opentelemetry.io/docs/specs/semconv/resource/process/
class ProcessResourceDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    if (OTelFactory.otelFactory == null) {
      throw StateError('OTel initialize must be called first.');
    }
    return ResourceCreate.create(
      OTelFactory.otelFactory!.attributesFromMap({
        'process.executable.name': io.Platform.executable,
        'process.command_line': io.Platform.executableArguments.join(' '),
        'process.runtime.name': 'dart',
        'process.runtime.version': io.Platform.version,
        'process.num_threads': io.Platform.numberOfProcessors.toString(),
      }),
    );
  }
}

/// Detects host-related resource information.
///
/// Populates resource attributes with information about the host machine
/// (hostname, architecture, OS details). Native-only — `dart:io` is not
/// available in the browser.
///
/// Semantic conventions:
/// https://opentelemetry.io/docs/specs/semconv/resource/host/
class HostResourceDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    if (OTelFactory.otelFactory == null) {
      throw StateError('OTel initialize must be called first.');
    }
    final attributes = <String, Object>{
      'host.name': io.Platform.localHostname,
      'host.arch': io.Platform.localHostname,
      'host.processors': io.Platform.numberOfProcessors,
      'host.os.name': io.Platform.operatingSystem,
      'host.locale': io.Platform.localeName,
    };

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

    return ResourceCreate.create(
      OTelFactory.otelFactory!.attributesFromMap(attributes),
    );
  }
}
