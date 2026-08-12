// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:isolate';

/// Cached result of [packageRoot].
String? _packageRootCache;

/// The absolute path of the package root, resolved from the package URI
/// rather than from [Directory.current].
///
/// The subprocess helper scripts are addressed by paths relative to the
/// package root. Resolving those against the working directory only works
/// when the runner starts at the root, which `dart test` does but IDEs
/// generally do not: IntelliJ and Android Studio default a Dart test run
/// configuration's working directory to the directory holding the test file,
/// and every subprocess test then fails with `Could not find file ...`.
/// Resolving through the package config makes the location of the runner
/// irrelevant.
Future<String> packageRoot() async {
  final cached = _packageRootCache;
  if (cached != null) return cached;
  final libUri = await Isolate.resolvePackageUri(
    Uri.parse('package:dartastic_opentelemetry/dartastic_opentelemetry.dart'),
  );
  if (libUri == null) {
    throw StateError(
      'Could not resolve package:dartastic_opentelemetry. '
      'Run `dart pub get` to regenerate .dart_tool/package_config.json.',
    );
  }
  // libUri is <root>/lib/dartastic_opentelemetry.dart.
  return _packageRootCache = File.fromUri(libUri).parent.parent.path;
}

/// Runs [scriptPath] in a subprocess with [envVars] applied, returning stdout.
///
/// [scriptPath] is relative to the package root. A subprocess is the only
/// reliable way to test code that reads `Platform.environment`, since that
/// map is unmodifiable in-process.
///
/// [args] is passed to the script after its path, for helpers that take the
/// value under test as an argument rather than an environment variable.
///
/// `OTEL_`- and `DAR_`-prefixed variables inherited from the ambient
/// environment are dropped before [envVars] is applied, so the child sees
/// exactly the variables the test asked for and nothing else. Without that, a
/// developer with those variables exported gets failures CI never reproduces.
///
/// Note [Process.run]'s `includeParentEnvironment` must be false for that
/// removal to mean anything: it defaults to true, which merges `environment`
/// *on top of* the parent's, so dropping a key from the map leaves the
/// parent's value visible to the child. `env` below is a full copy of the
/// parent environment, so the child still gets `PATH`, `HOME` and the rest.
///
/// Throws if the script exits non-zero, including its stdout and stderr.
Future<String> runWithEnv(
  String scriptPath,
  Map<String, String> envVars, {
  List<String> args = const <String>[],
}) async {
  final root = await packageRoot();
  final env = Map<String, String>.from(Platform.environment)
    ..removeWhere((key, _) => key.startsWith('OTEL_') || key.startsWith('DAR_'))
    ..addAll(envVars);
  final result = await Process.run(
    Platform.executable,
    [
      'run',
      File.fromUri(Directory(root).uri.resolve(scriptPath)).path,
      ...args,
    ],
    environment: env,
    includeParentEnvironment: false,
    workingDirectory: root,
  );
  if (result.exitCode != 0) {
    throw Exception(
      'Script failed with exit code ${result.exitCode}:\n'
      'stdout: ${result.stdout}\n'
      'stderr: ${result.stderr}',
    );
  }
  return result.stdout as String;
}
