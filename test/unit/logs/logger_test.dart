// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/memory_log_record_exporter.dart';

void main() {
  group('Logger Tests', () {
    late MemoryLogRecordExporter memoryExporter;
    late SimpleLogRecordProcessor processor;

    setUp(() async {
      await OTel.reset();

      memoryExporter = MemoryLogRecordExporter();
      processor = SimpleLogRecordProcessor(memoryExporter);

      await OTel.initialize(
        serviceName: 'logger-test-service',
        detectPlatformResources: false,
        enableLogs:
            false, // Disable auto-configuration so we control processors manually
      );

      OTel.loggerProvider().addLogRecordProcessor(processor);
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('Logger has correct name and attributes', () {
      final logger = OTel.loggerProvider().getLogger(
        'test-logger',
        version: '1.0.0',
      );

      expect(logger.name, equals('test-logger'));
      expect(logger.version, equals('1.0.0'));
    });

    test('Logger emits log record with all fields', () {
      final logger = OTel.logger('test-logger');
      final timestamp = DateTime.now();
      final attributes = OTel.attributesFromMap({
        'key1': 'value1',
        'key2': 42,
      });

      logger.emit(
        timeStamp: timestamp,
        severityNumber: Severity.INFO,
        severityText: 'INFO',
        body: 'Test log message',
        attributes: attributes,
        eventName: 'test.event',
      );

      expect(memoryExporter.count, equals(1));

      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.body, equals('Test log message'));
      expect(logRecord.severityNumber, equals(Severity.INFO));
      expect(logRecord.severityText, equals('INFO'));
      expect(logRecord.eventName, equals('test.event'));
      expect(logRecord.attributes, isNotNull);
      expect(logRecord.observedTimestamp, isNotNull);
    });

    test('Logger trace() emits TRACE severity', () {
      final logger = OTel.logger('test-logger');

      logger.trace('Trace message');

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.severityNumber, equals(Severity.TRACE));
      expect(logRecord.body, equals('Trace message'));
    });

    test('Logger debug() emits DEBUG severity', () {
      final logger = OTel.logger('test-logger');

      logger.debug('Debug message');

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.severityNumber, equals(Severity.DEBUG));
      expect(logRecord.body, equals('Debug message'));
    });

    test('Logger info() emits INFO severity', () {
      final logger = OTel.logger('test-logger');

      logger.info('Info message');

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.severityNumber, equals(Severity.INFO));
      expect(logRecord.body, equals('Info message'));
    });

    test('Logger warn() emits WARN severity', () {
      final logger = OTel.logger('test-logger');

      logger.warn('Warning message');

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.severityNumber, equals(Severity.WARN));
      expect(logRecord.body, equals('Warning message'));
    });

    test('Logger error() emits ERROR severity', () {
      final logger = OTel.logger('test-logger');

      logger.error('Error message');

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.severityNumber, equals(Severity.ERROR));
      expect(logRecord.body, equals('Error message'));
    });

    test('Logger fatal() emits FATAL severity', () {
      final logger = OTel.logger('test-logger');

      logger.fatal('Fatal message');

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.severityNumber, equals(Severity.FATAL));
      expect(logRecord.body, equals('Fatal message'));
    });

    test('Logger convenience methods accept attributes', () {
      final logger = OTel.logger('test-logger');
      final attributes = OTel.attributesFromMap({'error.code': 500});

      logger.error('Error with attributes', attributes: attributes);

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.attributes, isNotNull);
      final attrs = logRecord.attributes!.toList();
      expect(attrs.any((a) => a.key == 'error.code'), isTrue);
    });

    test('Logger convenience methods accept event name', () {
      final logger = OTel.logger('test-logger');

      logger.info('Event log', eventName: 'user.login');

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.eventName, equals('user.login'));
    });

    test('Logger is disabled when provider has no processors', () async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'no-processor-test',
        detectPlatformResources: false,
        enableLogs:
            false, // Disable auto-configuration to test no-processor behavior
      );

      final logger = OTel.logger('test-logger');

      // Logger should be disabled without processors
      expect(logger.enabled, isFalse);
    });

    test('Logger is enabled with processors', () {
      final logger = OTel.logger('test-logger');

      expect(logger.enabled, isTrue);
    });

    test('Logger does not emit when disabled', () async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'disabled-test',
        detectPlatformResources: false,
        enableLogs:
            false, // Disable auto-configuration to test disabled behavior
      );

      // No processor added, logger should be disabled
      final logger = OTel.logger('test-logger');
      logger.info('Should not be emitted');

      // Nothing should be exported since we haven't added a processor
      // to this new instance
      expect(logger.enabled, isFalse);
    });

    test('Logger captures trace context from current span', () async {
      await OTel.reset();

      memoryExporter = MemoryLogRecordExporter();
      processor = SimpleLogRecordProcessor(memoryExporter);

      await OTel.initialize(
        serviceName: 'trace-context-test',
        detectPlatformResources: false,
      );

      OTel.loggerProvider().addLogRecordProcessor(processor);

      final tracer = OTel.tracer();
      final span = tracer.startSpan('test-span');

      final logger = OTel.logger('test-logger');
      logger.info('Log within span');

      span.end();

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;

      // Log record should have trace context from the active span
      expect(logRecord.traceId, isNotNull);
      expect(logRecord.spanId, isNotNull);
      expect(logRecord.traceId!.isValid, isTrue);
      expect(logRecord.spanId!.isValid, isTrue);
    });

    test('Logger provider reference is accessible', () {
      final logger = OTel.logger('test-logger');

      expect(logger.provider, isNotNull);
      expect(logger.provider, equals(OTel.loggerProvider()));
    });

    test('Logger resource reference is accessible', () {
      final logger = OTel.logger('test-logger');

      expect(logger.resource, isNotNull);
    });
  });
}
