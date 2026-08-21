// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Regression tests for https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/228
//
// OTLP requests SHOULD carry a `User-Agent` header of the form
// `OTel-OTLP-Exporter-<language>/<version>` (specification/protocol/exporter.md,
// "User agent"). The version is the release-stamped `packageVersion` from
// lib/src/version.dart, whose sync with pubspec.yaml is guarded by
// test/unit/version_sync_test.dart (#249).

import 'package:dartastic_opentelemetry/src/export/otlp_user_agent.dart';
import 'package:dartastic_opentelemetry/src/version.dart';
import 'package:test/test.dart';

void main() {
  group('otlpUserAgent (issue #228)', () {
    test('derives from the release-stamped packageVersion', () {
      expect(otlpUserAgent, equals('OTel-OTLP-Exporter-Dart/$packageVersion'));
    });

    test('matches the spec format OTel-OTLP-Exporter-Dart/<version>', () {
      expect(otlpUserAgent, startsWith('OTel-OTLP-Exporter-Dart/'));
      expect(otlpUserAgent, isNot(endsWith('/')));
    });
  });
}
