// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Guard for issue #249: lib/src/version.dart is stamped by the release
// tooling; this test fails the suite — and release.dart itself, which runs
// the tests after rewriting pubspec.yaml — whenever the two drift.

import 'dart:io';

import 'package:dartastic_opentelemetry/src/version.dart';
import 'package:test/test.dart';

void main() {
  test('packageVersion matches the version in pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final pubspecVersion = line.substring('version:'.length).trim();
    expect(packageVersion, equals(pubspecVersion));
  });
}
