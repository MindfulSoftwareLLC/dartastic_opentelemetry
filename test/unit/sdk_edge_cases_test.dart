// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Tests for SDK edge cases across environment config, resource detection,
/// logging, provider initialization, instruments, and tracing.
library;

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/environment/env_from_define.dart';
import 'package:dartastic_opentelemetry/src/logs/export/logs_config.dart';
import 'package:dartastic_opentelemetry/src/resource/resource_detector.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Mock EnvironmentService that returns configurable values.
class _MockEnvironmentService implements EnvironmentService {
  final Map<String, String> _values;

  _MockEnvironmentService(this._values);

  @override
  String? getValue(String key) => _values[key];
}

/// A ResourceDetector that always throws.
class _ThrowingDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    throw Exception('detector failure');
  }
}

/// A LogRecordProcessor that throws synchronously on onEmit.
class _ThrowingEmitProcessor implements LogRecordProcessor {
  @override
  Future<void> onEmit(ReadWriteLogRecord logRecord, Context? context) {
    throw Exception('processor onEmit failure');
  }

  @override
  bool enabled({
    Context? context,
    InstrumentationScope? instrumentationScope,
    Severity? severityNumber,
    String? eventName,
  }) =>
      true;

  @override
  Future<void> shutdown() async {}

  @override
  Future<void> forceFlush() async {}
}

/// A LogRecordExporter that always throws on export.
class _ThrowingExporter implements LogRecordExporter {
  @override
  Future<ExportResult> export(List<ReadableLogRecord> logRecords) {
    throw Exception('exporter failure');
  }

  @override
  Future<void> shutdown() async {}

  @override
  Future<void> forceFlush() async {}
}

void main() {
  final List<String> logOutput = [];

  setUp(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'sdk-edge-cases-test',
      detectPlatformResources: false,
      enableLogs: false,
    );
    // Set AFTER initialize so env vars don't override
    OTelLog.enableTraceLogging();
    OTelLog.logFunction = logOutput.add;
    logOutput.clear();
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
    OTelLog.currentLevel = LogLevel.info;
    OTelLog.logFunction = null;
  });

  // =========================================================================
  // Environment configuration
  // =========================================================================
  group('getFromEnvironment', () {
    test('returns values for metrics SDK env vars', () {
      expect(getFromEnvironment('OTEL_METRICS_EXEMPLAR_FILTER'), isA<String>());
      expect(getFromEnvironment('OTEL_METRIC_EXPORT_INTERVAL'), isA<String>());
      expect(getFromEnvironment('OTEL_METRIC_EXPORT_TIMEOUT'), isA<String>());
    });

    test('returns values for Zipkin exporter env vars', () {
      expect(
          getFromEnvironment('OTEL_EXPORTER_ZIPKIN_ENDPOINT'), isA<String>());
      expect(getFromEnvironment('OTEL_EXPORTER_ZIPKIN_TIMEOUT'), isA<String>());
    });

    test('returns values for Prometheus exporter env vars', () {
      expect(
          getFromEnvironment('OTEL_EXPORTER_PROMETHEUS_HOST'), isA<String>());
      expect(
          getFromEnvironment('OTEL_EXPORTER_PROMETHEUS_PORT'), isA<String>());
    });

    test('returns values for deprecated env vars', () {
      expect(getFromEnvironment('OTEL_EXPORTER_OTLP_SPAN_INSECURE'),
          isA<String>());
      expect(getFromEnvironment('OTEL_EXPORTER_OTLP_METRIC_INSECURE'),
          isA<String>());
    });

    test('returns null for unknown key', () {
      expect(getFromEnvironment('TOTALLY_UNKNOWN_KEY'), isNull);
    });
  });

  group('OTelEnv.initializeLogging', () {
    test('configures logging from env when no custom logFunction is set', () {
      OTelLog.logFunction = print;
      OTelLog.currentLevel = LogLevel.info;
      OTelEnv.initializeLogging();
      expect(OTelLog.logFunction, isNotNull);
    });
  });

  // =========================================================================
  // Resource detection
  // =========================================================================
  group('EnvVarResourceDetector', () {
    test('parses key=value pairs', () async {
      final detector = EnvVarResourceDetector(_MockEnvironmentService({
        'OTEL_RESOURCE_ATTRIBUTES': 'key1=value1,key2=value2',
      }));
      final resource = await detector.detect();
      final attrs = resource.attributes.toList();
      expect(attrs.any((a) => a.key == 'key1' && a.value == 'value1'), isTrue);
      expect(attrs.any((a) => a.key == 'key2' && a.value == 'value2'), isTrue);
    });

    test('decodes percent-encoded values', () async {
      final detector = EnvVarResourceDetector(_MockEnvironmentService({
        'OTEL_RESOURCE_ATTRIBUTES': 'path=/usr%2Flocal%2Fbin',
      }));
      final resource = await detector.detect();
      final attrs = resource.attributes.toList();
      expect(attrs.any((a) => a.key == 'path' && a.value == '/usr/local/bin'),
          isTrue);
    });

    test('returns empty resource for empty env var', () async {
      final detector = EnvVarResourceDetector(_MockEnvironmentService({
        'OTEL_RESOURCE_ATTRIBUTES': '',
      }));
      final resource = await detector.detect();
      expect(resource.attributes.length, equals(0));
    });

    test('returns empty resource when env var is absent', () async {
      final detector = EnvVarResourceDetector(_MockEnvironmentService({}));
      final resource = await detector.detect();
      expect(resource.attributes.length, equals(0));
    });

    test('skips malformed entries without equals sign', () async {
      final detector = EnvVarResourceDetector(_MockEnvironmentService({
        'OTEL_RESOURCE_ATTRIBUTES': 'good=value,badentry,also=good',
      }));
      final resource = await detector.detect();
      final attrs = resource.attributes.toList();
      expect(attrs.any((a) => a.key == 'good' && a.value == 'value'), isTrue);
      expect(attrs.any((a) => a.key == 'also' && a.value == 'good'), isTrue);
      expect(attrs.any((a) => a.key == 'badentry'), isFalse);
    });

    test('handles escaped commas in values', () async {
      final detector = EnvVarResourceDetector(_MockEnvironmentService({
        'OTEL_RESOURCE_ATTRIBUTES': r'msg=hello\,world',
      }));
      final resource = await detector.detect();
      final attrs = resource.attributes.toList();
      expect(
          attrs.any((a) => a.key == 'msg' && a.value == 'hello,world'), isTrue);
    });
  });

  group('CompositeResourceDetector', () {
    test('continues detecting after one detector throws', () async {
      final composite = CompositeResourceDetector(
          [_ThrowingDetector(), ProcessResourceDetector()]);
      final resource = await composite.detect();
      expect(resource.attributes.length, greaterThan(0));
      expect(logOutput.any((m) => m.contains('Error in resource detector')),
          isTrue);
    });
  });

  // =========================================================================
  // Logging pipeline
  // =========================================================================
  group('SDKLogRecord', () {
    test('context getter returns provided context', () async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'log-record-test',
        detectPlatformResources: false,
        enableLogs: true,
      );
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      final scope = OTel.instrumentationScope(name: 'test');
      final ctx = Context.current;
      final record = SDKLogRecord(instrumentationScope: scope, context: ctx);
      expect(record.context, equals(ctx));
    });

    test('attributes and resource setters work', () async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'log-record-attr-test',
        detectPlatformResources: false,
        enableLogs: true,
      );
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      final scope = OTel.instrumentationScope(name: 'test');
      final record = SDKLogRecord(instrumentationScope: scope);

      record.attributes = OTel.attributes([OTel.attributeString('k', 'v')]);
      expect(record.attributes!.length, equals(1));

      record.resource = OTel.defaultResource;
      expect(record.resource, equals(OTel.defaultResource));
    });
  });

  group('Logger', () {
    test('catches and logs processor error during emit', () async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'logger-error-test',
        detectPlatformResources: false,
        enableLogs: true,
      );
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      final loggerProvider = OTel.loggerProvider();
      loggerProvider.addLogRecordProcessor(_ThrowingEmitProcessor());
      final logger = loggerProvider.getLogger('test-logger');

      logger.emit(body: 'test message', severityNumber: Severity.INFO);

      expect(logOutput.any((m) => m.contains('Error in processor')), isTrue);
    });

    test('emit with explicit observedTimestamp', () async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'logger-ts-test',
        detectPlatformResources: false,
        enableLogs: true,
      );
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      final logger = OTel.loggerProvider().getLogger('test-logger');
      logger.emit(
        body: 'test',
        severityNumber: Severity.WARN,
        observedTimestamp: DateTime(2025, 6, 15, 10, 30),
      );

      expect(logOutput.any((m) => m.contains('Emitting log record')), isTrue);
    });
  });

  group('SimpleLogRecordProcessor', () {
    test('logs error when exporter throws', () async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'simple-proc-test',
        detectPlatformResources: false,
        enableLogs: true,
      );
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      final processor = SimpleLogRecordProcessor(_ThrowingExporter());
      final scope = OTel.instrumentationScope(name: 'test');
      final record = SDKLogRecord(instrumentationScope: scope, body: 'test');

      await processor.onEmit(record, Context.current);

      expect(
          logOutput.any((m) => m.contains('SimpleLogRecordProcessor')), isTrue);
    });
  });

  group('LogsConfiguration', () {
    test('configureLoggerProvider with custom exporter', () async {
      final provider = LogsConfiguration.configureLoggerProvider(
        endpoint: 'http://localhost:4318',
        logRecordExporter: ConsoleLogRecordExporter(),
        resource: OTel.defaultResource,
      );
      expect(provider, isNotNull);
      expect(provider.logRecordProcessors, isNotEmpty);
    });
  });

  // =========================================================================
  // Provider initialization
  // =========================================================================
  group('Provider constructor logging', () {
    test('logs resource attributes during creation', () async {
      await OTel.reset();
      logOutput.clear();
      // Set logging BEFORE initialize so constructor debug output is captured
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      await OTel.initialize(
        serviceName: 'provider-log-test',
        detectPlatformResources: false,
        enableLogs: true,
      );

      expect(
        logOutput.any((m) => m.contains('Created with resource')),
        isTrue,
        reason:
            'Expected provider constructor to log creation. Got ${logOutput.length} entries: ${logOutput.take(5).join("\\n")}',
      );
    });
  });

  group('OTel print interception', () {
    test('runWithPrintInterception returns result', () async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'print-intercept-test',
        detectPlatformResources: false,
        enableLogs: true,
      );
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      expect(OTel.runWithPrintInterception(() => 42), equals(42));
    });

    test('runWithPrintInterceptionAsync returns result', () async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'print-intercept-async-test',
        detectPlatformResources: false,
        enableLogs: true,
      );
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      expect(
        await OTel.runWithPrintInterceptionAsync(() async => 'hello'),
        equals('hello'),
      );
    });
  });

  // =========================================================================
  // Instruments and tracing
  // =========================================================================
  group('Counter', () {
    test('addWithMap converts map to attributes', () async {
      final counter =
          OTel.meter().createCounter<int>(name: 'test-counter') as Counter<int>;
      counter.addWithMap(5, {'env': 'test', 'count': 1});
      counter.addWithMap(3, {});
      expect(counter.getValue(), greaterThanOrEqualTo(8));
    });
  });

  group('Histogram', () {
    test('boundaries getter returns configured boundaries', () async {
      final histogram = OTel.meter().createHistogram<double>(
        name: 'test-histogram',
        boundaries: [1.0, 5.0, 10.0],
      );
      expect(histogram.boundaries, equals([1.0, 5.0, 10.0]));
    });
  });

  group('Tracer', () {
    test('startSpanWithContext sets span in context', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpanWithContext(
        name: 'context-span',
        context: Context.current,
      );
      expect(span, isNotNull);
      span.end();
    });
  });
}
