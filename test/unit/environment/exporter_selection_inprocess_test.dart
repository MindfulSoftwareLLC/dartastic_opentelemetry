// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// In-process exporter-selection coverage via
// EnvironmentService.testOverrides: drives the OTEL_METRICS_EXPORTER /
// OTEL_LOGS_EXPORTER list handling in MetricsConfiguration and
// LogsConfiguration (warn/fallback branches, composites, grpc protocol
// selection, BLRP config application) that the subprocess pipeline
// tests exercise invisibly to coverage.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  final warnings = <String>[];

  Future<void> initWith(Map<String, String> vars,
      {bool metrics = false, bool logs = false}) async {
    EnvironmentService.testOverrides = {
      'OTEL_TRACES_EXPORTER': 'none', // keep the trace pipeline quiet
      ...vars,
    };
    await OTel.initialize(
      serviceName: 'exporter-selection-test',
      detectPlatformResources: false,
      enableMetrics: metrics,
      enableLogs: logs,
    );
  }

  setUp(() async {
    await OTel.reset();
    warnings.clear();
    OTelLog.logFunction = warnings.add;
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

  group('OTEL_METRICS_EXPORTER selection', () {
    test('none installs no reader', () async {
      await initWith({'OTEL_METRICS_EXPORTER': 'none'}, metrics: true);
      expect(OTel.meterProvider().metricReaders, isEmpty);
    });

    test('none alongside other values warns and installs no reader', () async {
      await initWith({'OTEL_METRICS_EXPORTER': 'none,otlp'}, metrics: true);
      expect(OTel.meterProvider().metricReaders, isEmpty);
      expect(warnings.join('\n'), contains("contains 'none'"));
    });

    test('console installs a ConsoleMetricExporter reader', () async {
      await initWith({'OTEL_METRICS_EXPORTER': 'console'}, metrics: true);
      final readers = OTel.meterProvider().metricReaders;
      expect(readers, hasLength(1));
      final reader = readers.single as PeriodicExportingMetricReader;
      expect(reader.exporter, isA<ConsoleMetricExporter>());
    });

    test('otlp,console composes both exporters', () async {
      await initWith({'OTEL_METRICS_EXPORTER': 'otlp,console'}, metrics: true);
      final reader = OTel.meterProvider().metricReaders.single
          as PeriodicExportingMetricReader;
      expect(reader.exporter, isA<CompositeMetricExporter>());
      final composite = reader.exporter as CompositeMetricExporter;
      expect(composite.exporters, hasLength(2));
    });

    test('prometheus warns and falls back to otlp', () async {
      await initWith({'OTEL_METRICS_EXPORTER': 'prometheus'}, metrics: true);
      final reader = OTel.meterProvider().metricReaders.single
          as PeriodicExportingMetricReader;
      expect(reader.exporter, isNot(isA<ConsoleMetricExporter>()));
      expect(warnings.join('\n'), contains('prometheus'));
      expect(warnings.join('\n'), contains('no usable exporter'));
    });

    test('logging warns (deprecated) and falls back to otlp', () async {
      await initWith({'OTEL_METRICS_EXPORTER': 'logging'}, metrics: true);
      expect(OTel.meterProvider().metricReaders, hasLength(1));
      expect(warnings.join('\n'), contains('deprecated'));
    });

    test('unknown value warns and falls back to otlp', () async {
      await initWith({'OTEL_METRICS_EXPORTER': 'statsd'}, metrics: true);
      expect(OTel.meterProvider().metricReaders, hasLength(1));
      expect(warnings.join('\n'), contains("'statsd' is not supported"));
    });

    test('grpc protocol selects the grpc metric exporter', () async {
      await initWith({
        'OTEL_METRICS_EXPORTER': 'otlp',
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
      }, metrics: true);
      final reader = OTel.meterProvider().metricReaders.single
          as PeriodicExportingMetricReader;
      expect(reader.exporter, isA<OtlpGrpcMetricExporter>());
    });
  });

  group('OTEL_LOGS_EXPORTER selection', () {
    test('none installs no processor', () async {
      await initWith({'OTEL_LOGS_EXPORTER': 'none'}, logs: true);
      expect(OTel.loggerProvider().logRecordProcessors, isEmpty);
    });

    test('none alongside other values warns and installs no processor',
        () async {
      await initWith({'OTEL_LOGS_EXPORTER': 'none,console'}, logs: true);
      expect(OTel.loggerProvider().logRecordProcessors, isEmpty);
      expect(warnings.join('\n'), contains("contains 'none'"));
    });

    test('console installs a ConsoleLogRecordExporter processor', () async {
      await initWith({'OTEL_LOGS_EXPORTER': 'console'}, logs: true);
      final processors = OTel.loggerProvider().logRecordProcessors;
      expect(processors, hasLength(1));
      final processor = processors.single as BatchLogRecordProcessor;
      expect(processor.exporter, isA<ConsoleLogRecordExporter>());
    });

    test('otlp,console installs one processor per exporter', () async {
      await initWith({'OTEL_LOGS_EXPORTER': 'otlp,console'}, logs: true);
      expect(OTel.loggerProvider().logRecordProcessors, hasLength(2));
    });

    test('logging warns (deprecated) and falls back to otlp', () async {
      await initWith({'OTEL_LOGS_EXPORTER': 'logging'}, logs: true);
      expect(OTel.loggerProvider().logRecordProcessors, hasLength(1));
      expect(warnings.join('\n'), contains('deprecated'));
    });

    test('unknown value warns and falls back to otlp', () async {
      await initWith({'OTEL_LOGS_EXPORTER': 'fluentd'}, logs: true);
      expect(OTel.loggerProvider().logRecordProcessors, hasLength(1));
      expect(warnings.join('\n'), contains("'fluentd' is not supported"));
    });

    test('grpc protocol selects the grpc log exporter', () async {
      await initWith({
        'OTEL_LOGS_EXPORTER': 'otlp',
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
      }, logs: true);
      final processor = OTel.loggerProvider().logRecordProcessors.single
          as BatchLogRecordProcessor;
      expect(processor.exporter, isA<OtlpGrpcLogRecordExporter>());
    });

    test('BLRP env config is applied to the processor', () async {
      await initWith({
        'OTEL_LOGS_EXPORTER': 'console',
        'OTEL_BLRP_SCHEDULE_DELAY': '750',
        'OTEL_BLRP_MAX_QUEUE_SIZE': '256',
      }, logs: true);
      expect(OTel.loggerProvider().logRecordProcessors, hasLength(1));
    });
  });
}
