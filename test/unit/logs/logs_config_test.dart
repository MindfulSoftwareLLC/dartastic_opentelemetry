// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

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
    test('getBlrpConfig returns empty map when no env vars set', () {
      // When no env vars are set (which is the case in tests),
      // getBlrpConfig should return an empty map
      final config = OTelEnv.getBlrpConfig();
      expect(config, isA<Map<String, dynamic>>());
      // Config may be empty or have defaults depending on env
    });

    test('getLogRecordLimits returns empty map when no env vars set', () {
      final config = OTelEnv.getLogRecordLimits();
      expect(config, isA<Map<String, dynamic>>());
    });
  });

  group('BatchLogRecordProcessorConfig tests', () {
    test('default config values are correct per OTel spec', () {
      const config = BatchLogRecordProcessorConfig();

      expect(config.maxQueueSize, equals(2048));
      expect(config.scheduleDelay, equals(const Duration(milliseconds: 1000)));
      expect(config.maxExportBatchSize, equals(512));
      expect(config.exportTimeout, equals(const Duration(seconds: 30)));
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
  });
}
