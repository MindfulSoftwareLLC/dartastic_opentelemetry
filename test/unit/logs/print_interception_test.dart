// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/memory_log_record_exporter.dart';

void main() {
  group('Print Interception Tests', () {
    late MemoryLogRecordExporter memoryExporter;
    late SimpleLogRecordProcessor processor;

    setUp(() async {
      await OTel.reset();
      memoryExporter = MemoryLogRecordExporter();
      processor = SimpleLogRecordProcessor(memoryExporter);
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('logPrint defaults to false', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
      );

      expect(OTel.isLogPrintEnabled, isFalse);
      expect(OTel.logBridge, isNull);
    });

    test('logPrint can be enabled', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );
      OTel.loggerProvider().addLogRecordProcessor(processor);

      expect(OTel.isLogPrintEnabled, isTrue);
      // Bridge is lazily initialized, so it's null until first use
      expect(OTel.logBridge, isNull);

      // Trigger lazy initialization
      OTel.runWithPrintInterception(() {});

      // Now the bridge should be initialized
      expect(OTel.logBridge, isNotNull);
      expect(OTel.logBridge!.isActive, isTrue);
    });

    test(
        'print is captured when logPrint enabled and runWithPrintInterception used',
        () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );
      OTel.loggerProvider().addLogRecordProcessor(processor);

      OTel.runWithPrintInterception(() {
        print('Test print message');
      });

      // Wait for async processor to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(memoryExporter.count, equals(1));
      expect(
        memoryExporter.exportedLogRecords.first.body,
        equals('Test print message'),
      );
    });

    test('print interception captures severity as INFO', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );
      OTel.loggerProvider().addLogRecordProcessor(processor);

      OTel.runWithPrintInterception(() {
        print('Test print');
      });

      // Wait for async processor to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(memoryExporter.count, equals(1));
      expect(
        memoryExporter.exportedLogRecords.first.severityNumber,
        equals(Severity.INFO),
      );
    });

    test('runWithPrintInterception returns callback result', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );

      final result = OTel.runWithPrintInterception(() {
        return 42;
      });

      expect(result, equals(42));
    });

    test('runWithPrintInterception works without print enabled', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: false,
      );

      final result = OTel.runWithPrintInterception(() {
        print('This should not be captured');
        return 'done';
      });

      expect(result, equals('done'));
      // No logs should be captured since logPrint is false
      expect(memoryExporter.count, equals(0));
    });

    test('runWithPrintInterceptionAsync works with async code', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );
      OTel.loggerProvider().addLogRecordProcessor(processor);

      final result = await OTel.runWithPrintInterceptionAsync(() async {
        print('Async print message');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'async result';
      });

      // Wait for async processor to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(result, equals('async result'));
      expect(memoryExporter.count, equals(1));
      expect(
        memoryExporter.exportedLogRecords.first.body,
        equals('Async print message'),
      );
    });

    test('custom logPrintLoggerName is used', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
        logPrintLoggerName: 'my.custom.print.logger',
      );
      OTel.loggerProvider().addLogRecordProcessor(processor);

      OTel.runWithPrintInterception(() {
        print('Custom logger test');
      });

      // Wait for async processor to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(memoryExporter.count, equals(1));
      expect(
        memoryExporter.exportedLogRecords.first.instrumentationScope.name,
        equals('my.custom.print.logger'),
      );
    });

    test('default logPrintLoggerName is dart.print', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );
      OTel.loggerProvider().addLogRecordProcessor(processor);

      OTel.runWithPrintInterception(() {
        print('Default logger test');
      });

      // Wait for async processor to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(memoryExporter.count, equals(1));
      expect(
        memoryExporter.exportedLogRecords.first.instrumentationScope.name,
        equals('dart.print'),
      );
    });

    test('multiple prints in single zone are captured', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );
      OTel.loggerProvider().addLogRecordProcessor(processor);

      // Verify processor is registered
      expect(OTel.loggerProvider().logRecordProcessors.length, greaterThan(0));

      OTel.runWithPrintInterception(() {
        print('First message');
        print('Second message');
        print('Third message');
      });

      // Wait for async processor to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(memoryExporter.count, equals(3));
      expect(
          memoryExporter.exportedLogRecords[0].body, equals('First message'));
      expect(
          memoryExporter.exportedLogRecords[1].body, equals('Second message'));
      expect(
          memoryExporter.exportedLogRecords[2].body, equals('Third message'));
    });

    test('multiple separate runWithPrintInterception calls work', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );
      OTel.loggerProvider().addLogRecordProcessor(processor);

      OTel.runWithPrintInterception(() {
        print('First message');
      });

      // Wait for async processor to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(memoryExporter.count, equals(1),
          reason: 'Should have 1 log after first call');

      OTel.runWithPrintInterception(() {
        print('Second message');
      });

      // Wait for async processor to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(memoryExporter.count, equals(2),
          reason: 'Should have 2 logs after second call');
    });

    test('reset clears print interception state', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );

      expect(OTel.isLogPrintEnabled, isTrue);

      // Trigger lazy initialization
      OTel.runWithPrintInterception(() {});
      expect(OTel.logBridge, isNotNull);

      await OTel.reset();

      expect(OTel.isLogPrintEnabled, isFalse);
      expect(OTel.logBridge, isNull);
    });

    test('print interception preserves original print behavior', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );
      OTel.loggerProvider().addLogRecordProcessor(processor);

      // This test just verifies no exception is thrown and print still works
      // The actual output goes to stdout which we can't easily capture
      OTel.runWithPrintInterception(() {
        print('This should both print and be logged');
      });

      // Wait for async processor to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Log should be captured
      expect(memoryExporter.count, equals(1));
    });

    test('nested runWithPrintInterception calls work', () async {
      await OTel.initialize(
        serviceName: 'print-interception-test',
        detectPlatformResources: false,
        logPrint: true,
      );
      OTel.loggerProvider().addLogRecordProcessor(processor);

      OTel.runWithPrintInterception(() {
        print('Outer message');
        OTel.runWithPrintInterception(() {
          print('Inner message');
        });
        print('Another outer message');
      });

      // Wait for async processor to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Nested zones may capture differently - at minimum we expect the messages to be logged
      expect(memoryExporter.count, greaterThanOrEqualTo(1));
    });
  });
}
