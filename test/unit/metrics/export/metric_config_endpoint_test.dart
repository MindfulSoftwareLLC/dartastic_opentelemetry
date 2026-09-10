// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// End-to-end endpoint wiring for the OTLP/HTTP metric exporter.
//
// These bind a local collector and assert on the request path it actually
// receives, so they prove the exporter's URL construction rather than its
// instrumentation. Asserting on debug log output would couple the tests to
// log strings and require a specific OTelLog level to be in effect.
//
// Two requirements are covered, kept in separate groups because different
// changes fix them:
//
//   #229 - OTEL_EXPORTER_OTLP_METRICS_ENDPOINT must be applied at all.
//          Fixed in #72; these tests hold it in place.
//   #219 - a per-signal endpoint MUST be used as-is, while the generic
//          OTEL_EXPORTER_OTLP_ENDPOINT is a base URL that takes the signal
//          path appended. Still open, so the two per-signal cases are
//          skipped rather than red.
//
// Spec: protocol/exporter.md, "Endpoint URLs for OTLP/HTTP"
//   1. For the per-signal variables (OTEL_EXPORTER_OTLP_<signal>_ENDPOINT),
//      the URL MUST be used as-is without any modification. The only
//      exception is that if an URL contains no path part, the root path /
//      MUST be used.
//   2. If signals are sent that have no per-signal configuration,
//      OTEL_EXPORTER_OTLP_ENDPOINT is used as a base URL and the signals
//      are sent to these paths relative to that: Metrics: v1/metrics

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// Reason attached to the cases #219 has to fix before they can run.
const _blockedOn219 =
    'Blocked on #219: OtlpHttpMetricExporter appends /v1/metrics '
    'unconditionally, so a per-signal endpoint is modified instead of being '
    'used as-is. Un-skip when #219 lands.';

void main() {
  late HttpServer server;
  late int port;
  late List<String> requestPaths;

  setUp(() async {
    await OTel.reset();
    requestPaths = [];
    server = await HttpServer.bind('localhost', 0);
    port = server.port;
    server.listen((request) async {
      requestPaths.add(request.uri.path);
      await request.drain<void>();
      request.response.statusCode = 200;
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    try {
      await OTel.shutdown();
    } catch (_) {}
    await OTel.reset();
    EnvironmentService.testOverrides = null;
  });

  /// Initializes with [vars], exports one metric, and waits for the local
  /// collector to receive it.
  ///
  /// forceFlush() can return before the HTTP request has been handled, so
  /// this polls rather than asserting immediately, which would race the
  /// socket and fail intermittently.
  Future<void> initAndFlush(Map<String, String> vars,
      {String? endpoint}) async {
    EnvironmentService.testOverrides = {
      'OTEL_TRACES_EXPORTER': 'none',
      ...vars,
    };
    await OTel.initialize(
      endpoint: endpoint,
      serviceName: 'metrics-endpoint-test',
      detectPlatformResources: false,
      enableLogs: false,
    );
    OTel.meter('endpoint-meter').createCounter<int>(name: 'hits').add(1);
    await OTel.meterProvider().forceFlush();

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (requestPaths.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(requestPaths, isNotEmpty,
        reason: 'the exporter never reached the test collector');
  }

  // Whether the configured endpoint reaches the exporter at all. These match
  // the configured base as a prefix rather than the exact path, so they stay
  // green independently of the #219 signal-path defect covered below.
  group('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT is applied (#229)', () {
    test('a per-signal metrics endpoint reaches the exporter', () async {
      await initAndFlush({
        'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT':
            'http://localhost:$port/tenant/metrics-in',
      });

      expect(requestPaths.single, startsWith('/tenant/metrics-in'));
    });

    test('a per-signal metrics endpoint overrides the generic endpoint',
        () async {
      await initAndFlush({
        // Nothing listens on port 9, so reaching the test collector at all
        // proves the per-signal value won.
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:9/wrong',
        'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT':
            'http://localhost:$port/metrics-only',
      });

      expect(requestPaths.single, startsWith('/metrics-only'));
    });

    test('the generic endpoint is used when no per-signal endpoint is set',
        () async {
      await initAndFlush({
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:$port/base',
      });

      expect(requestPaths.single, startsWith('/base'));
    });

    test('the initialize() endpoint parameter reaches the exporter', () async {
      await initAndFlush({}, endpoint: 'http://localhost:$port/from-init');

      expect(requestPaths.single, startsWith('/from-init'));
    });
  });

  // Exact URL construction: the signal path belongs on base URLs only.
  group('signal path is appended only to base URLs (#219)', () {
    test(
      'a per-signal metrics endpoint is used as-is',
      () async {
        await initAndFlush({
          'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT':
              'http://localhost:$port/tenant/metrics-in',
        });

        expect(requestPaths, equals(['/tenant/metrics-in']));
      },
      skip: _blockedOn219,
    );

    test(
      'a per-signal endpoint with no path part uses the root path',
      () async {
        await initAndFlush({
          'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT': 'http://localhost:$port',
        });

        expect(requestPaths, equals(['/']));
      },
      skip: _blockedOn219,
    );

    test('a generic base endpoint takes /v1/metrics appended', () async {
      await initAndFlush({
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:$port/base',
      });

      expect(requestPaths, equals(['/base/v1/metrics']));
    });

    test('the initialize() endpoint parameter takes /v1/metrics appended',
        () async {
      await initAndFlush({}, endpoint: 'http://localhost:$port/from-init');

      expect(requestPaths, equals(['/from-init/v1/metrics']));
    });
  });
}
