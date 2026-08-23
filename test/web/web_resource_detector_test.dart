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
      expect(attrs[Browser.browserLanguage.key], isNotEmpty);
      expect(attrs[Browser.browserPlatform.key], isNotEmpty);
      expect(attrs['browser.languages'], isNotEmpty);
      expect(attrs[UserAgent.userAgentOriginal.key], isNotEmpty);

      // Headless desktop Chrome is not mobile; this must be computed, not
      // the catch-path fallback.
      expect(attrs[Browser.browserMobile.key], equals('false'));
    });

    group('isMobileBrowser', () {
      test('recognises the obvious mobile user agents', () {
        for (final ua in [
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
          'Mozilla/5.0 (Linux; Android 14; Pixel 8)',
          'Mozilla/5.0 (Windows Phone 10.0)',
          'Mozilla/5.0 (Mobile; rv:120.0)',
        ]) {
          expect(isMobileBrowser(ua, 5), isTrue, reason: ua);
        }
      });

      test('an iPad reporting a DESKTOP user agent is still mobile', () {
        // iPadOS 13+ requests desktop sites by default and sends a Mac
        // user agent, so the UA test alone reports every iPad as desktop.
        // maxTouchPoints is what separates it from a real Mac.
        const iPadOnDesktopUa =
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15';
        expect(isMobileBrowser(iPadOnDesktopUa, 5), isTrue);
      });

      test('a real Mac is not mobile', () {
        const macUa = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';
        expect(isMobileBrowser(macUa, 0), isFalse);
        expect(isMobileBrowser(macUa, null), isFalse,
            reason: 'a browser that does not report maxTouchPoints must not '
                'be guessed into the mobile bucket');
      });

      test('a touchscreen Windows laptop is not mobile on touch alone', () {
        const winUa = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';
        expect(isMobileBrowser(winUa, 10), isFalse,
            reason: 'touch capability alone is not a mobile device');
      });
    });
  });
}
