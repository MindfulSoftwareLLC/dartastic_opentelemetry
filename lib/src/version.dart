// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// The package's own version, for code that must identify the SDK at
/// runtime (e.g. the OTLP `User-Agent` header).
///
/// Dart has no runtime API for a library's own version, and reading
/// pubspec.yaml works only when running JIT from source — not in Flutter
/// AOT builds or on the web. So the release tooling stamps this constant:
/// `tool/release.dart` and `tool/backport_release.dart` rewrite it in the
/// same step that rewrites the pubspec `version:` line, and
/// `test/unit/version_sync_test.dart` fails whenever the two drift.
library;

/// Synced with the `version:` line in pubspec.yaml by the release tooling.
/// Do not edit by hand — see tool/release.dart.
const String packageVersion = '0.10.0';
