// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../../testing_utils/memory_log_record_exporter.dart';

void main() {
  group('DartLogBridge Tests', () {
    late MemoryLogRecordExporter memoryExporter;
    late SimpleLogRecordProcessor processor;

    setUp(() async {
      await OTel.reset();

      memoryExporter = MemoryLogRecordExporter();
      processor = SimpleLogRecordProcessor(memoryExporter);

      await OTel.initialize(
        serviceName: 'dart-log-bridge-test',
        detectPlatformResources: false,
      );

      OTel.loggerProvider().addLogRecordProcessor(processor);
    });

    tearDown(() async {
      DartLogBridge.uninstall();
      await OTel.shutdown();
      await OTel.reset();
    });

    test('DartLogBridge can be installed with Logger', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      expect(bridge.isActive, isTrue);
      expect(DartLogBridge.current, equals(bridge));
    });

    test('DartLogBridge can be installed with LoggerProvider', () {
      final bridge = DartLogBridge.installWithProvider(
        OTel.loggerProvider(),
        defaultLoggerName: 'provider-logger',
      );

      expect(bridge.isActive, isTrue);
      expect(DartLogBridge.current, equals(bridge));
    });

    test('DartLogBridge can be uninstalled', () {
      final logger = OTel.logger('test-logger');
      DartLogBridge.install(logger);

      expect(DartLogBridge.current, isNotNull);

      DartLogBridge.uninstall();

      expect(DartLogBridge.current, isNull);
    });

    test('DartLogBridge can be activated and deactivated', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      expect(bridge.isActive, isTrue);

      bridge.deactivate();
      expect(bridge.isActive, isFalse);

      bridge.activate();
      expect(bridge.isActive, isTrue);
    });

    test('DartLogBridge.log emits log record when active', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      bridge.log('Test message', level: 800); // INFO level

      expect(memoryExporter.count, equals(1));
      expect(
          memoryExporter.exportedLogRecords.first.body, equals('Test message'));
    });

    test('DartLogBridge.log does not emit when inactive', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      bridge.deactivate();
      bridge.log('Should not be logged');

      expect(memoryExporter.count, equals(0));
    });

    test('DartLogBridge converts Dart INFO level to OTel INFO severity', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      bridge.log('Test at INFO level', level: 800);

      expect(memoryExporter.count, equals(1));
      expect(memoryExporter.exportedLogRecords.first.severityNumber,
          equals(Severity.INFO));
    });

    test('DartLogBridge converts Dart WARNING level to OTel WARN severity', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      bridge.log('Test at WARNING level', level: 900);

      expect(memoryExporter.count, equals(1));
      expect(memoryExporter.exportedLogRecords.first.severityNumber,
          equals(Severity.WARN));
    });

    test('DartLogBridge converts Dart SEVERE level to OTel ERROR severity', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      bridge.log('Test at SEVERE level', level: 1000);

      expect(memoryExporter.count, equals(1));
      expect(memoryExporter.exportedLogRecords.first.severityNumber,
          equals(Severity.ERROR));
    });

    test('DartLogBridge respects minimum severity filter', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(
        logger,
        minimumSeverity: Severity.WARN,
      );

      // INFO level (800) should be filtered out
      bridge.log('Info message', level: 800);
      expect(memoryExporter.count, equals(0));

      // WARNING level (900) should pass
      bridge.log('Warning message', level: 900);
      expect(memoryExporter.count, equals(1));
    });

    test('DartLogBridge includes error information', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      final error = Exception('Test error');
      bridge.log(
        'Error occurred',
        level: 1000,
        error: error,
      );

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      final attrs = logRecord.attributes?.toList() ?? [];

      expect(attrs.any((a) => a.key == 'exception.type'), isTrue);
      expect(attrs.any((a) => a.key == 'exception.message'), isTrue);
    });

    test('DartLogBridge includes stack trace', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      final stackTrace = StackTrace.current;
      bridge.log(
        'Error with stack',
        level: 1000,
        stackTrace: stackTrace,
      );

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      final attrs = logRecord.attributes?.toList() ?? [];

      expect(attrs.any((a) => a.key == 'exception.stacktrace'), isTrue);
    });

    test('DartLogBridge includes sequence number', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      bridge.log('Test message',
          level: 800, sequenceNumber: 42); // level 800 = INFO

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      final attrs = logRecord.attributes?.toList() ?? [];

      final seqAttr = attrs.firstWhere(
        (a) => a.key == 'sequence_number',
        orElse: () => throw StateError('sequence_number not found'),
      );
      expect(seqAttr.value, equals(42));
    });

    test('DartLogBridge uses logger name from log call when using provider',
        () {
      final bridge = DartLogBridge.installWithProvider(
        OTel.loggerProvider(),
        defaultLoggerName: 'default-logger',
      );

      bridge.log('Test message',
          level: 800, name: 'custom-logger'); // level 800 = INFO

      expect(memoryExporter.count, equals(1));
      // The instrumentation scope name should be the custom logger name
      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.instrumentationScope.name, equals('custom-logger'));
    });

    test('DartLogBridge uses default logger name when no name provided', () {
      final bridge = DartLogBridge.installWithProvider(
        OTel.loggerProvider(),
        defaultLoggerName: 'my-default-logger',
      );

      bridge.log('Test message', level: 800); // level 800 = INFO

      expect(memoryExporter.count, equals(1));
      final logRecord = memoryExporter.exportedLogRecords.first;
      expect(logRecord.instrumentationScope.name, equals('my-default-logger'));
    });

    test('DartLogBridge createZoneSpecification captures print', () {
      final logger = OTel.logger('test-logger');
      final bridge = DartLogBridge.install(logger);

      final spec = bridge.createZoneSpecification();
      expect(spec, isNotNull);

      // Run code in the zone
      runZoned(
        () {
          print('Test print message');
        },
        zoneSpecification: spec,
      );

      // The print should have been captured
      expect(memoryExporter.count, equals(1));
      expect(
        memoryExporter.exportedLogRecords.first.body,
        equals('Test print message'),
      );
    });

    test('DartLogBridge static emitLog works', () {
      final logger = OTel.logger('test-logger');
      DartLogBridge.install(logger);

      DartDeveloperLogBridge.emitLog(
        'Static emit message',
        level: 800,
        name: 'static-logger',
      );

      // Should produce at least one log (the OTel log from the bridge)
      expect(memoryExporter.count, greaterThanOrEqualTo(1));
    });
  });
}
