// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/memory_log_record_exporter.dart';

void main() {
  group('LogsConfiguration Tests', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test(
        'configureLoggerProvider creates default exporter when no env vars set',
        () async {
      await OTel.initialize(
        serviceName: 'logs-config-test',
        detectPlatformResources: false,
        enableLogs: false, // Disable auto-config so we can test manual config
      );

      final provider = LogsConfiguration.configureLoggerProvider(
        endpoint: 'http://localhost:4318',
        secure: false,
        resource: OTel.defaultResource,
      );

      expect(provider, isNotNull);
      expect(provider.logRecordProcessors.length, greaterThan(0));
    });

    test('configureLoggerProvider uses custom exporter when provided',
        () async {
      await OTel.initialize(
        serviceName: 'logs-config-test',
        detectPlatformResources: false,
        enableLogs: false,
      );

      final memoryExporter = MemoryLogRecordExporter();

      final provider = LogsConfiguration.configureLoggerProvider(
        endpoint: 'http://localhost:4318',
        secure: false,
        logRecordExporter: memoryExporter,
        resource: OTel.defaultResource,
      );

      expect(provider, isNotNull);
      expect(provider.logRecordProcessors.length, greaterThan(0));
    });

    test('configureLoggerProvider uses custom processor when provided',
        () async {
      await OTel.initialize(
        serviceName: 'logs-config-test',
        detectPlatformResources: false,
        enableLogs: false,
      );

      final memoryExporter = MemoryLogRecordExporter();
      final customProcessor = SimpleLogRecordProcessor(memoryExporter);

      final provider = LogsConfiguration.configureLoggerProvider(
        endpoint: 'http://localhost:4318',
        secure: false,
        logRecordProcessor: customProcessor,
        resource: OTel.defaultResource,
      );

      expect(provider, isNotNull);
      expect(provider.logRecordProcessors.length, greaterThan(0));
    });

    test('createSimpleProcessor creates SimpleLogRecordProcessor', () async {
      await OTel.initialize(
        serviceName: 'logs-config-test',
        detectPlatformResources: false,
        enableLogs: false,
      );

      final memoryExporter = MemoryLogRecordExporter();
      final processor = LogsConfiguration.createSimpleProcessor(memoryExporter);

      expect(processor, isA<SimpleLogRecordProcessor>());
    });
  });

  group('OTel.initialize with logs env vars', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('enableLogs=true auto-configures log exporter', () async {
      await OTel.initialize(
        serviceName: 'logs-env-test',
        detectPlatformResources: false,
        enableLogs: true,
        logRecordExporter: MemoryLogRecordExporter(),
      );

      final provider = OTel.loggerProvider();
      // With enableLogs=true, a processor should be added automatically
      expect(provider.logRecordProcessors.length, greaterThan(0));
    });

    test('enableLogs=false does not add log processor', () async {
      await OTel.initialize(
        serviceName: 'logs-env-test',
        detectPlatformResources: false,
        enableLogs: false,
      );

      final provider = OTel.loggerProvider();
      // With enableLogs=false, no processor should be added
      expect(provider.logRecordProcessors.length, equals(0));
    });

    test('custom logRecordExporter is used when provided', () async {
      final memoryExporter = MemoryLogRecordExporter();

      await OTel.initialize(
        serviceName: 'logs-env-test',
        detectPlatformResources: false,
        enableLogs: true,
        logRecordExporter: memoryExporter,
      );

      final provider = OTel.loggerProvider();
      expect(provider.logRecordProcessors.length, greaterThan(0));

      // Test that logs go to the memory exporter
      final logger = OTel.logger('test-logger');
      logger.emit(body: 'Test log message');

      // Wait for batch processor to export (default schedule delay is 1 second)
      // For batch processor, we need to wait longer or force flush
      await provider.forceFlush();

      expect(memoryExporter.count, equals(1));
      expect(memoryExporter.exportedLogRecords.first.body,
          equals('Test log message'));
    });

    test('custom logRecordProcessor is used when provided', () async {
      final memoryExporter = MemoryLogRecordExporter();
      final customProcessor = SimpleLogRecordProcessor(memoryExporter);

      await OTel.initialize(
        serviceName: 'logs-env-test',
        detectPlatformResources: false,
        enableLogs: true,
        logRecordProcessor: customProcessor,
      );

      final provider = OTel.loggerProvider();
      expect(provider.logRecordProcessors.length, greaterThan(0));

      // Test that logs go through the custom processor
      final logger = OTel.logger('test-logger');
      logger.emit(body: 'Custom processor test');

      // Wait for async processing
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(memoryExporter.count, equals(1));
    });
  });

  group('OTelEnv BLRP config tests', () {
    test('getBlrpConfig returns record with null fields when no env vars set',
        () {
      final config = OTelEnv.getBlrpConfig();
      expect(config.scheduleDelay, isNull);
      expect(config.exportTimeout, isNull);
      expect(config.maxQueueSize, isNull);
      expect(config.maxExportBatchSize, isNull);
    });

    test('getLogRecordLimits returns record when no env vars set', () {
      final config = OTelEnv.getLogRecordLimits();
      expect(config, isA<LogRecordLimitsEnvironmentValues>());
    });
  });

  group('BatchLogRecordProcessorConfig tests', () {
    test('default config values are correct per OTel spec', () {
      const config = BatchLogRecordProcessorConfig();

      expect(config.maxQueueSize,
          equals(BatchLogRecordProcessorConfig.defaultMaxQueueSize));
      expect(config.scheduleDelay,
          equals(BatchLogRecordProcessorConfig.defaultScheduleDelay));
      expect(config.maxExportBatchSize,
          equals(BatchLogRecordProcessorConfig.defaultMaxExportBatchSize));
      expect(config.exportTimeout,
          equals(BatchLogRecordProcessorConfig.defaultExportTimeout));
    });

    test('custom config values are applied', () {
      const config = BatchLogRecordProcessorConfig(
        maxQueueSize: 4096,
        scheduleDelay: Duration(milliseconds: 5000),
        maxExportBatchSize: 1024,
        exportTimeout: Duration(seconds: 60),
      );

      expect(config.maxQueueSize, equals(4096));
      expect(config.scheduleDelay, equals(const Duration(milliseconds: 5000)));
      expect(config.maxExportBatchSize, equals(1024));
      expect(config.exportTimeout, equals(const Duration(seconds: 60)));
    });

    test('fromEnvironment uses defaults when no vars set', () {
      EnvironmentService.testOverrides = {};
      final config = BatchLogRecordProcessorConfig.fromEnvironment();

      expect(config.maxQueueSize,
          equals(BatchLogRecordProcessorConfig.defaultMaxQueueSize));
      expect(config.scheduleDelay,
          equals(BatchLogRecordProcessorConfig.defaultScheduleDelay));
      expect(config.maxExportBatchSize,
          equals(BatchLogRecordProcessorConfig.defaultMaxExportBatchSize));
      expect(config.exportTimeout,
          equals(BatchLogRecordProcessorConfig.defaultExportTimeout));
      EnvironmentService.testOverrides = null;
    });

    test('fromEnvironment honors scheduleDelay=0 (export ASAP)', () {
      EnvironmentService.testOverrides = {'OTEL_BLRP_SCHEDULE_DELAY': '0'};
      final config = BatchLogRecordProcessorConfig.fromEnvironment();
      expect(config.scheduleDelay, equals(const Duration(milliseconds: 0)));
      EnvironmentService.testOverrides = null;
    });

    test('fromEnvironment warns and defaults for scheduleDelay=-1', () {
      final logs = <String>[];
      OTelLog.logFunction = logs.add;
      OTelLog.currentLevel = LogLevel.warn;

      EnvironmentService.testOverrides = {'OTEL_BLRP_SCHEDULE_DELAY': '-1'};
      final config = BatchLogRecordProcessorConfig.fromEnvironment();

      expect(config.scheduleDelay,
          equals(BatchLogRecordProcessorConfig.defaultScheduleDelay));
      expect(logs.join('\n'), contains('OTEL_BLRP_SCHEDULE_DELAY'));

      EnvironmentService.testOverrides = null;
      OTelLog.logFunction = null;
    });

    test('fromEnvironment honors exportTimeout=0 (no limit)', () {
      EnvironmentService.testOverrides = {'OTEL_BLRP_EXPORT_TIMEOUT': '0'};
      final config = BatchLogRecordProcessorConfig.fromEnvironment();
      expect(
          config.exportTimeout, equals(BatchLogRecordProcessorConfig.noLimit));
      EnvironmentService.testOverrides = null;
    });

    test('fromEnvironment warns and defaults for exportTimeout=-1', () {
      final logs = <String>[];
      OTelLog.logFunction = logs.add;
      OTelLog.currentLevel = LogLevel.warn;

      EnvironmentService.testOverrides = {'OTEL_BLRP_EXPORT_TIMEOUT': '-1'};
      final config = BatchLogRecordProcessorConfig.fromEnvironment();

      expect(config.exportTimeout,
          equals(BatchLogRecordProcessorConfig.defaultExportTimeout));
      expect(logs.join('\n'), contains('OTEL_BLRP_EXPORT_TIMEOUT'));

      EnvironmentService.testOverrides = null;
      OTelLog.logFunction = null;
    });

    test('fromEnvironment warns and defaults for non-positive queue size', () {
      final logs = <String>[];
      OTelLog.logFunction = logs.add;
      OTelLog.currentLevel = LogLevel.warn;

      EnvironmentService.testOverrides = {'OTEL_BLRP_MAX_QUEUE_SIZE': '-5'};
      final config = BatchLogRecordProcessorConfig.fromEnvironment();

      expect(config.maxQueueSize,
          equals(BatchLogRecordProcessorConfig.defaultMaxQueueSize));
      expect(logs.join('\n'), contains('OTEL_BLRP_MAX_QUEUE_SIZE'));

      EnvironmentService.testOverrides = null;
      OTelLog.logFunction = null;
    });

    test(
        'fromEnvironment clamps batch size to default maxQueueSize when queue unset',
        () {
      EnvironmentService.testOverrides = {
        'OTEL_BLRP_MAX_EXPORT_BATCH_SIZE': '5000'
      };
      final config = BatchLogRecordProcessorConfig.fromEnvironment();

      expect(config.maxQueueSize,
          equals(BatchLogRecordProcessorConfig.defaultMaxQueueSize));
      expect(config.maxExportBatchSize,
          equals(BatchLogRecordProcessorConfig.defaultMaxQueueSize));

      EnvironmentService.testOverrides = null;
    });

    test('fromEnvironment clamps batch size to queue size', () {
      EnvironmentService.testOverrides = {
        'OTEL_BLRP_MAX_QUEUE_SIZE': '100',
        'OTEL_BLRP_MAX_EXPORT_BATCH_SIZE': '200',
        'OTEL_BLRP_SCHEDULE_DELAY': '1234',
        'OTEL_BLRP_EXPORT_TIMEOUT': '5678',
      };

      final config = BatchLogRecordProcessorConfig.fromEnvironment();

      expect(config.maxQueueSize, equals(100));
      expect(config.maxExportBatchSize, equals(100));
      expect(config.scheduleDelay, equals(const Duration(milliseconds: 1234)));
      expect(config.exportTimeout, equals(const Duration(milliseconds: 5678)));

      EnvironmentService.testOverrides = null;
    });
  });
}
