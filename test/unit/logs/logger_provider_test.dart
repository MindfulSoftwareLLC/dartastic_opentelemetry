// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/memory_log_record_exporter.dart';

void main() {
  group('LoggerProvider Tests', () {
    late MemoryLogRecordExporter memoryExporter;
    late SimpleLogRecordProcessor processor;

    setUp(() async {
      await OTel.reset();

      // Create a memory exporter for verification
      memoryExporter = MemoryLogRecordExporter();
      processor = SimpleLogRecordProcessor(memoryExporter);

      // Initialize OTel without auto-configuration of logs
      // (so we can test processor management manually)
      await OTel.initialize(
        serviceName: 'logger-provider-test-service',
        detectPlatformResources: false,
        enableLogs: false,
      );

      // Add the processor to the logger provider
      OTel.loggerProvider().addLogRecordProcessor(processor);
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('LoggerProvider exposes service information', () {
      final loggerProvider = OTel.loggerProvider();

      expect(
          loggerProvider.serviceName, equals('logger-provider-test-service'));

      // Modify service information
      loggerProvider.serviceName = 'updated-service-name';
      loggerProvider.serviceVersion = '1.2.3';
      loggerProvider.endpoint = 'https://updated.endpoint';

      expect(loggerProvider.serviceName, equals('updated-service-name'));
      expect(loggerProvider.serviceVersion, equals('1.2.3'));
      expect(loggerProvider.endpoint, equals('https://updated.endpoint'));
    });

    test('LoggerProvider can be enabled and disabled', () {
      final loggerProvider = OTel.loggerProvider();

      // By default, enabled is true
      expect(loggerProvider.enabled, isTrue);

      // Disable logger provider
      loggerProvider.enabled = false;
      expect(loggerProvider.enabled, isFalse);

      // Re-enable
      loggerProvider.enabled = true;
      expect(loggerProvider.enabled, isTrue);
    });

    test('LoggerProvider returns same logger for same configuration', () {
      final loggerProvider = OTel.loggerProvider();

      final logger1 = loggerProvider.getLogger('test-logger');
      final logger2 = loggerProvider.getLogger('test-logger');
      final logger3 = loggerProvider.getLogger('different-logger');

      expect(identical(logger1, logger2), isTrue);
      expect(identical(logger1, logger3), isFalse);
    });

    test('LoggerProvider returns different loggers for different versions', () {
      final loggerProvider = OTel.loggerProvider();

      final logger1 = loggerProvider.getLogger('test-logger', version: '1.0.0');
      final logger2 = loggerProvider.getLogger('test-logger', version: '2.0.0');

      expect(identical(logger1, logger2), isFalse);
    });

    test('LoggerProvider manages processors', () {
      final loggerProvider = OTel.loggerProvider();

      // Should have our processor
      expect(loggerProvider.logRecordProcessors.length, equals(1));

      // Add another processor
      final anotherExporter = MemoryLogRecordExporter();
      final anotherProcessor = SimpleLogRecordProcessor(anotherExporter);
      loggerProvider.addLogRecordProcessor(anotherProcessor);

      expect(loggerProvider.logRecordProcessors.length, equals(2));
    });

    test('LoggerProvider throws when getting logger after shutdown', () async {
      final loggerProvider = OTel.loggerProvider();
      await loggerProvider.shutdown();

      expect(
        () => loggerProvider.getLogger('test-logger'),
        throwsA(isA<StateError>()),
      );
    });

    test('LoggerProvider throws when adding processor after shutdown',
        () async {
      final loggerProvider = OTel.loggerProvider();
      await loggerProvider.shutdown();

      expect(
        () => loggerProvider.addLogRecordProcessor(
          SimpleLogRecordProcessor(MemoryLogRecordExporter()),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('LoggerProvider shutdown calls processor shutdown', () async {
      final loggerProvider = OTel.loggerProvider();

      expect(loggerProvider.isShutdown, isFalse);

      await loggerProvider.shutdown();

      expect(loggerProvider.isShutdown, isTrue);
    });

    test('LoggerProvider forceFlush flushes all processors', () async {
      final loggerProvider = OTel.loggerProvider();
      final logger = loggerProvider.getLogger('test-logger');

      // Emit some logs
      logger.info('Test message 1');
      logger.info('Test message 2');

      // Force flush
      await loggerProvider.forceFlush();

      // Verify logs were exported
      expect(memoryExporter.count, equals(2));
    });

    test('LoggerProvider sets resource correctly', () {
      final loggerProvider = OTel.loggerProvider();

      expect(loggerProvider.resource, isNotNull);

      // Check service name in resource
      final attrs = loggerProvider.resource!.attributes.toList();
      final serviceName = attrs.firstWhere(
        (a) => a.key == 'service.name',
        orElse: () => throw StateError('service.name not found'),
      );
      expect(serviceName.value, equals('logger-provider-test-service'));
    });
  });
}
