// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Browser-to-collector integration test for issue #190: the whole pipeline
// runs for real — this test executes in Chrome, initializes the SDK with
// platform resource detection on, exports a span over OTLP/HTTP to a
// capture server running on the VM (see util/otlp_capture_server.dart),
// and asserts the browser.* resource attributes arrive on the wire.

@TestOn('browser')
@Timeout(Duration(seconds: 60))
library;

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  test('browser resource attributes reach the OTLP wire', () async {
    final channel = spawnHybridUri('util/otlp_capture_server.dart');
    final messages = StreamIterator(channel.stream);

    expect(await messages.moveNext(), isTrue);
    // Under dart2wasm, numbers arriving over the hybrid channel are doubles.
    final port = (messages.current as num).toInt();

    await OTel.reset();
    await OTel.initialize(
      serviceName: 'web-e2e',
      endpoint: 'http://localhost:$port',
      // On web this runs EnvVarResourceDetector + WebResourceDetector;
      // the native process/host detectors are skipped by design.
      detectPlatformResources: true,
      enableMetrics: false,
      enableLogs: false,
    );
    OTel.tracer().startSpan('e2e-span').end();
    await OTel.tracerProvider().forceFlush();

    expect(await messages.moveNext(), isTrue,
        reason: 'no OTLP export reached the capture server');
    final attrs = (messages.current as Map).cast<String, Object>();

    expect(attrs['service.name'], equals('web-e2e'));
    expect(attrs['browser.language'], isNotEmpty);
    expect(attrs['browser.platform'], isNotEmpty);
    // A List<String>, not a comma-joined string.
    // ignore: experimental_member_use
    final langs = attrs[BrowserCandidate.browserLanguages.key];
    expect(langs, isA<List>(),
        reason: 'browser.languages must reach the wire as an OTLP array, '
            'not a joined string');
    expect(langs as List, isNotEmpty);
    expect(attrs['user_agent.original'], isNotEmpty);
    // Must arrive as an OTLP boolValue, not the string 'false'.
    expect(attrs[Browser.browserMobile.key], isFalse);

    await OTel.reset();
  });
}
