// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Remaining OTel facade coverage: pre-initialize attribute creation,
// semantic-map passthroughs, propagator env selection edges, and the
// custom time provider.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

class _FixedTimeProvider implements TimeProvider {
  @override
  DateTime nowDateTime() => DateTime.utc(2026, 7, 18, 12);
}

void main() {
  final captured = <String>[];

  setUp(() async {
    await OTel.reset();
    captured.clear();
    OTelLog.logFunction = captured.add;
    OTelLog.currentLevel = LogLevel.warn;
  });

  tearDown(() async {
    OTelLog.logFunction = print;
    OTelLog.currentLevel = LogLevel.info;
    try {
      await OTel.shutdown();
    } catch (_) {}
    await OTel.reset();
    EnvironmentService.testOverrides = null;
  });

  Future<void> initWith(Map<String, String> vars,
      {TimeProvider? timeProvider}) async {
    EnvironmentService.testOverrides = {
      'OTEL_TRACES_EXPORTER': 'none',
      'OTEL_METRICS_EXPORTER': 'none',
      'OTEL_LOGS_EXPORTER': 'none',
      ...vars,
    };
    await OTel.initialize(
      serviceName: 'otel-misc-test',
      detectPlatformResources: false,
      enableMetrics: false,
      enableLogs: false,
      timeProvider: timeProvider,
    );
  }

  test('attributes() works before initialize via the API fallback', () async {
    final attrs = OTel.attributes([OTelAPI.attributeString('k', 'v')]);
    expect(attrs.getString('k'), equals('v'));
  });

  test('semantic map passthroughs build attributes', () async {
    await initWith({});
    final fromSemantic = OTel.attributesFromSemanticMap({
      Service.serviceName: 'semantic-svc',
    });
    expect(fromSemantic.getString('service.name'), equals('semantic-svc'));

    final typed = OTel.attributesOf<Service>({
      Service.serviceName: 'typed-svc',
      Service.serviceVersion: '1.2.3',
    });
    expect(typed.getString('service.version'), equals('1.2.3'));
  });

  test('custom time provider stamps span times', () async {
    await initWith({}, timeProvider: _FixedTimeProvider());
    final span = OTel.tracer().startSpan('timed')..end();
    expect(span.startTime, equals(DateTime.utc(2026, 7, 18, 12)));
  });

  group('OTEL_PROPAGATORS selection', () {
    test('none alongside other values warns and keeps the no-op default',
        () async {
      await initWith({'OTEL_PROPAGATORS': 'none,tracecontext'});
      expect(captured.join('\n'), contains('none'));
    });

    test('unsupported name warns and is ignored', () async {
      await initWith({'OTEL_PROPAGATORS': 'jaeger,tracecontext'});
      expect(captured.join('\n'), contains('unsupported propagator'));
    });

    test('explicit pair installs a composite propagator', () async {
      await initWith({'OTEL_PROPAGATORS': 'tracecontext,baggage'});
      expect(OTelAPI.textMapPropagator, isA<CompositePropagator>());
    });
  });
}
