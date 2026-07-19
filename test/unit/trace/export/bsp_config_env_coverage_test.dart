// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// In-process coverage for BatchSpanProcessorConfig.fromEnvironment's
// spec-mandated validation (negative values warn and fall back; zero
// export timeout means "no limit") and the batch timer's error guard.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

class _ThrowingSpanExporter implements SpanExporter {
  @override
  Future<void> export(List<Span> spans) async =>
      throw StateError('export always fails');

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

void main() {
  final logs = <String>[];

  setUp(() async {
    await OTel.reset();
    logs.clear();
    OTelLog.logFunction = logs.add;
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

  group('BatchSpanProcessorConfig.fromEnvironment', () {
    test('valid values pass through', () {
      EnvironmentService.testOverrides = {
        'OTEL_BSP_SCHEDULE_DELAY': '1200',
        'OTEL_BSP_EXPORT_TIMEOUT': '4500',
        'OTEL_BSP_MAX_QUEUE_SIZE': '1024',
        'OTEL_BSP_MAX_EXPORT_BATCH_SIZE': '256',
      };
      final config = BatchSpanProcessorConfig.fromEnvironment();
      expect(config.scheduleDelay, equals(const Duration(milliseconds: 1200)));
      expect(config.exportTimeout, equals(const Duration(milliseconds: 4500)));
      expect(config.maxQueueSize, equals(1024));
      expect(config.maxExportBatchSize, equals(256));
    });

    test('unset values fall back to spec defaults', () {
      EnvironmentService.testOverrides = {};
      final config = BatchSpanProcessorConfig.fromEnvironment();
      expect(config.scheduleDelay, equals(const Duration(milliseconds: 5000)));
      expect(config.exportTimeout, equals(const Duration(milliseconds: 30000)));
      expect(config.maxQueueSize, equals(2048));
      expect(config.maxExportBatchSize, equals(512));
    });

    test('negative delay and timeout warn and use defaults', () {
      EnvironmentService.testOverrides = {
        'OTEL_BSP_SCHEDULE_DELAY': '-100',
        'OTEL_BSP_EXPORT_TIMEOUT': '-200',
      };
      final config = BatchSpanProcessorConfig.fromEnvironment();
      expect(config.scheduleDelay, equals(const Duration(milliseconds: 5000)));
      expect(config.exportTimeout, equals(const Duration(milliseconds: 30000)));
      expect(logs.join('\n'), contains('OTEL_BSP_SCHEDULE_DELAY'));
      expect(logs.join('\n'), contains('OTEL_BSP_EXPORT_TIMEOUT'));
    });

    test('zero export timeout means no limit', () {
      EnvironmentService.testOverrides = {'OTEL_BSP_EXPORT_TIMEOUT': '0'};
      final config = BatchSpanProcessorConfig.fromEnvironment();
      expect(config.exportTimeout.inDays, greaterThan(1),
          reason: 'zero substitutes a practically unlimited duration');
    });

    test('non-positive queue and batch sizes warn and use defaults', () {
      EnvironmentService.testOverrides = {
        'OTEL_BSP_MAX_QUEUE_SIZE': '-1',
        'OTEL_BSP_MAX_EXPORT_BATCH_SIZE': '0',
      };
      final config = BatchSpanProcessorConfig.fromEnvironment();
      expect(config.maxQueueSize, equals(2048));
      expect(config.maxExportBatchSize, equals(512));
      expect(logs.join('\n'), contains('OTEL_BSP_MAX_QUEUE_SIZE'));
      expect(logs.join('\n'), contains('OTEL_BSP_MAX_EXPORT_BATCH_SIZE'));
    });
  });

  group('BatchSpanProcessor timer', () {
    test('a throwing exporter is caught and logged, not propagated', () async {
      OTelLog.currentLevel = LogLevel.error;
      EnvironmentService.testOverrides = {'OTEL_TRACES_EXPORTER': 'none'};
      await OTel.initialize(
        serviceName: 'bsp-timer-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );
      final processor = BatchSpanProcessor(
        _ThrowingSpanExporter(),
        const BatchSpanProcessorConfig(
          scheduleDelay: Duration(milliseconds: 20),
        ),
      );
      final span = OTel.tracer().startSpan('doomed')..end();
      await processor.onEnd(span);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(logs.join('\n'), contains('Error exporting batch of spans'));
      await processor.shutdown().catchError((_) => true);
    });
  });
}
