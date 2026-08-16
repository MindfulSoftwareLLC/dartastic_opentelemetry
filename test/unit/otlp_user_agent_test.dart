// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Regression tests for https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/228
//
// OTLP requests SHOULD carry a `User-Agent` header of the form
// `OTel-OTLP-Exporter-<language>/<version>` (specification/protocol/exporter.md,
// "User agent"). The value is derived from a hand-synced package version.

import 'package:dartastic_opentelemetry/src/export/otlp_user_agent.dart';
import 'package:test/test.dart';

void main() {
  group('otlpUserAgent (issue #228)', () {
    test('matches the spec format OTel-OTLP-Exporter-Dart/<package-version>',
        () {
      expect(otlpUserAgent, equals('OTel-OTLP-Exporter-Dart/$packageVersion'));
      expect(otlpUserAgent, startsWith('OTel-OTLP-Exporter-Dart/'));
      expect(otlpUserAgent, isNot(endsWith('/')));
    });

    test('package version is a non-empty string', () {
      expect(packageVersion, isNotEmpty);
    });
  });
}
