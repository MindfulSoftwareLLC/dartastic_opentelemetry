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
    // Keys come from the generated registry enums (never string literals),
    // so a typo is a compile error — the class of bug that put the hostname
    // in host.arch (#90).
    return ResourceCreate.create(
      OTelFactory.otelFactory!.attributesFromMap(<String, Object>{
        ProcessAttributes.processExecutableName.key: io.Platform.executable,
        ProcessAttributes.processCommandLine.key:
            io.Platform.executableArguments.join(' '),
        ProcessAttributes.processRuntimeName.key: 'dart',
        ProcessAttributes.processRuntimeVersion.key: io.Platform.version,
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
      Host.hostName.key: io.Platform.localHostname,
      if (_hostArch() case final arch?) Host.hostArch.key: arch,
      Os.osName.key: io.Platform.operatingSystem,
      Os.osVersion.key: io.Platform.operatingSystemVersion,
    };

    final osType = switch (io.Platform.operatingSystem) {
      'linux' => 'linux',
      'windows' => 'windows',
      'macos' => 'macos',
      'android' => 'android',
      'ios' => 'ios',
      _ => null,
    };
    if (osType != null) {
      attributes[Os.osType.key] = osType;
    }

    return ResourceCreate.create(
      OTelFactory.otelFactory!.attributesFromMap(attributes),
    );
  }
}

/// Resolves `host.arch` to a registry value (`amd64`, `arm64`, `arm32`,
/// `x86`, `riscv64`, …) from the runtime's `Platform.version`, whose tail
/// reads `on "<os>_<arch>"`. Pure Dart, no `dart:ffi`. Returns `null` when
/// the token can't be parsed, so the attribute is simply omitted.
String? _hostArch() {
  final match =
      RegExp(r'on "[a-z0-9]+_([a-z0-9]+)"').firstMatch(io.Platform.version);
  return switch (match?.group(1)) {
    'arm64' => 'arm64',
    'arm' => 'arm32',
    'x64' => 'amd64',
    'ia32' => 'x86',
    'riscv64' => 'riscv64',
    'riscv32' => 'riscv32',
    final other => other, // pass through unknown tokens; null omits it
  };
}
