// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// In-process coverage for OTel.initialize's traces-side env handling:
// OTEL_TRACES_EXPORTER list selection, env-derived service/endpoint
// config with debug logging, resource-attribute merging, and
// OTEL_SDK_DISABLED.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  final captured = <String>[];

  Future<void> initWith(Map<String, String> vars,
      {Attributes? resourceAttributes, bool bare = false}) async {
    EnvironmentService.testOverrides = {
      'OTEL_METRICS_EXPORTER': 'none',
      'OTEL_LOGS_EXPORTER': 'none',
      ...vars,
    };
    if (bare) {
      await OTel.initialize(detectPlatformResources: false);
    } else {
      await OTel.initialize(
        serviceName: 'traces-selection-test',
        detectPlatformResources: false,
        resourceAttributes: resourceAttributes,
      );
    }
  }

  SpanExporter exporterOf() {
    final processors = OTel.tracerProvider().spanProcessors;
    expect(processors, hasLength(1));
    return (processors.single as BatchSpanProcessor).exporter;
  }

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

  group('OTEL_TRACES_EXPORTER selection', () {
    test('none alongside other values warns and installs no processor',
        () async {
      await initWith({'OTEL_TRACES_EXPORTER': 'none,otlp'});
      expect(OTel.tracerProvider().spanProcessors, isEmpty);
      expect(captured.join('\n'), contains("contains 'none'"));
    });

    test('console installs a ConsoleExporter', () async {
      await initWith({'OTEL_TRACES_EXPORTER': 'console'});
      expect(exporterOf(), isA<ConsoleExporter>());
    });

    test('otlp,console composes both exporters', () async {
      await initWith({'OTEL_TRACES_EXPORTER': 'otlp,console'});
      final exporter = exporterOf();
      expect(exporter, isA<CompositeExporter>());
      expect((exporter as CompositeExporter).spanExporters, hasLength(2));
    });

    test('logging warns (deprecated) and falls back to otlp', () async {
      await initWith({'OTEL_TRACES_EXPORTER': 'logging'});
      expect(exporterOf(), isNot(isA<ConsoleExporter>()));
      expect(captured.join('\n'), contains('deprecated'));
    });

    test('unknown value warns and falls back to otlp', () async {
      await initWith({'OTEL_TRACES_EXPORTER': 'zipkin'});
      expect(exporterOf(), isNot(isA<ConsoleExporter>()));
      expect(captured.join('\n'), contains("'zipkin' is not supported"));
    });

    test('grpc protocol selects the grpc span exporter', () async {
      await initWith({
        'OTEL_TRACES_EXPORTER': 'otlp',
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
      });
      expect(exporterOf(), isA<OtlpGrpcSpanExporter>());
    });
  });

  group('env-derived configuration', () {
    test(
        'bare initialize takes service, endpoint, and insecure from env'
        ' with debug logging', () async {
      OTelLog.currentLevel = LogLevel.debug;
      await initWith({
        'OTEL_TRACES_EXPORTER': 'none',
        'OTEL_SERVICE_NAME': 'env-service',
        'OTEL_RESOURCE_ATTRIBUTES': 'service.version=9.9.9',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://env-collector:4318',
        'OTEL_EXPORTER_OTLP_TRACES_INSECURE': 'true',
      }, bare: true);
      final resource = OTel.tracerProvider().resource;
      expect(resource, isNotNull);
      final attrs = resource!.attributes;
      expect(attrs.getString('service.name'), equals('env-service'));
      expect(attrs.getString('service.version'), equals('9.9.9'));
      final logDump = captured.join('\n');
      expect(logDump, contains('service name from environment'));
      expect(logDump, contains('service version from environment'));
      expect(logDump, contains('endpoint from environment'));
      expect(logDump, contains('insecure setting from environment'));
    });

    test('env resource attributes merge under explicit ones', () async {
      await initWith(
        {
          'OTEL_TRACES_EXPORTER': 'none',
          'OTEL_RESOURCE_ATTRIBUTES': 'env.only=fromenv,shared=env',
        },
        resourceAttributes: OTel.attributesFromMap({'shared': 'param'}),
      );
      final attrs = OTel.tracerProvider().resource!.attributes;
      expect(attrs.getString('env.only'), equals('fromenv'));
      expect(attrs.getString('shared'), equals('param'),
          reason: 'explicit attributes take precedence over env');
    });

    test('OTEL_SDK_DISABLED skips all signal setup', () async {
      OTelLog.currentLevel = LogLevel.debug;
      await initWith({'OTEL_SDK_DISABLED': 'true'});
      expect(OTel.tracerProvider().spanProcessors, isEmpty);
      expect(OTel.meterProvider().metricReaders, isEmpty);
      expect(OTel.loggerProvider().logRecordProcessors, isEmpty);
      expect(captured.join('\n'), contains('OTEL_SDK_DISABLED'));
    });
  });
}
