// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Regression test for issue #190: the browser.* resource attributes were
// silently empty on web because two @JS bindings declared a JS function
// body as the binding path; the first call threw, the blanket catch
// swallowed it, and every attribute fell back to ''.

@TestOn('browser')
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('WebResourceDetector (issue #190)', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'web-detector-test',
        detectPlatformResources: false,
      );
    });

    tearDown(OTel.reset);

    test('browser.* attributes are populated from the real navigator',
        () async {
      final resource = await WebResourceDetector().detect();
      final attrs = {
        for (final a in resource.attributes.toList()) a.key: a.value,
      };

      // Chrome always reports these; blank means the detector threw and
      // the catch papered over it.
      expect(attrs['browser.language'], isNotEmpty);
      expect(attrs['browser.platform'], isNotEmpty);
      expect(attrs['browser.languages'], isNotEmpty);
      expect(attrs['user_agent.original'], isNotEmpty);

      // Headless desktop Chrome is not mobile; this must be computed, not
      // the catch-path fallback.
      expect(attrs['browser.mobile'], equals('false'));
    });
  });
}
