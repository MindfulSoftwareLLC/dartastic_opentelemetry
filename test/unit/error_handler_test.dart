// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../testing_utils/in_memory_span_exporter.dart';

class _FailingDetector implements ResourceDetector {
  final Object error;
  final StackTrace stack;
  _FailingDetector(this.error, this.stack);
  @override
  Future<Resource> detect() async => Error.throwWithStackTrace(error, stack);
}

class _SuccessfulDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async =>
      OTel.resource(OTel.attributesFromMap({'detected': true}));
}

class _FailingSpanExporter implements SpanExporter {
  final Object error;
  final StackTrace stack;
  _FailingSpanExporter(this.error, this.stack);
  @override
  Future<void> export(List<Span> spans) async =>
      Error.throwWithStackTrace(error, stack);
  @override
  Future<void> forceFlush() async {}
  @override
  Future<void> shutdown() async {}
}

class _FailingLogExporter implements LogRecordExporter {
  final Error? error;
  final bool hang;
  _FailingLogExporter({this.error, this.hang = false});
  @override
  Future<ExportResult> export(List<ReadableLogRecord> records) async {
    if (error != null) throw error!;
    if (hang) return Completer<ExportResult>().future;
    return ExportResult.failure;
  }

  @override
  Future<void> forceFlush() async {}
  @override
  Future<void> shutdown() async {}
}

class _FailingMetricExporter implements MetricExporter {
  final Error error;
  _FailingMetricExporter(this.error);
  @override
  Future<bool> export(MetricData data) async => throw error;
  @override
  Future<bool> forceFlush() async => throw error;
  @override
  Future<bool> shutdown() async => throw error;
}

void main() {
  final errors = <Object>[];
  final stacks = <StackTrace?>[];
  final error = StateError('test failure');
  final stack = StackTrace.fromString('original stack');

  Future<void> initialize() => OTel.initialize(
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
        spanProcessor: SimpleSpanProcessor(InMemorySpanExporter()),
      );

  SDKLogRecord record() => SDKLogRecord(
        instrumentationScope: OTel.instrumentationScope(name: 'test'),
        body: 'test',
      );

  setUp(() async {
    await OTel.reset();
    errors.clear();
    stacks.clear();
    OTel.setErrorHandler((error, stack) {
      errors.add(error);
      stacks.add(stack);
    });
    await initialize();
    OTelLog.logFunction = null;
  });

  tearDown(() async {
    OTel.setErrorHandler(null);
    await OTel.reset();
    OTelLog.logFunction = null;
  });

  test('handler survives initialization and is shared with API', () {
    OTelErrorHandling.report(error, stack);
    expect(errors, [same(error)]);
    expect(stacks.single, same(stack));
    OTelAPI.setErrorHandler((error, _) => errors.add(error));
    OTelErrorHandling.report('API replacement');
    expect(errors.last, 'API replacement');
  });

  test('handler survives API factory upgrade', () async {
    await OTel.reset();
    OTelAPI.attributesFromMap({'key': 'value'});
    OTel.setErrorHandler((error, _) => errors.add(error));
    await initialize();
    OTelErrorHandling.report(error);
    expect(errors, [same(error)]);
  });

  test('null restores default logging and no-op suppresses it', () {
    final messages = <String>[];
    OTelLog.logFunction = messages.add;
    OTelLog.currentLevel = LogLevel.error;
    OTel.setErrorHandler((_, __) {});
    OTelErrorHandling.report(error, stack);
    expect(messages, isEmpty);
    OTel.setErrorHandler(null);
    OTelErrorHandling.report(error, stack);
    expect(messages.join(), contains('test failure'));
    expect(messages.join(), contains('original stack'));
  });

  test('reset clears configured handler', () async {
    await OTel.reset();
    expect(OTelErrorHandling.installedHandler, isNull);
  });

  test('resource detector reports original error and continues', () async {
    final resource = await CompositeResourceDetector([
      _FailingDetector(error, stack),
      _SuccessfulDetector(),
    ]).detect();
    expect(resource.attributes.getBool('detected'), isTrue);
    expect(errors, [same(error)]);
    expect(stacks.single, same(stack));
  });

  for (final batch in [false, true]) {
    test('${batch ? 'batch' : 'simple'} span processor routes export errors',
        () async {
      final exporter = _FailingSpanExporter(error, stack);
      final processor = batch
          ? BatchSpanProcessor(exporter,
              const BatchSpanProcessorConfig(scheduleDelay: Duration(hours: 1)))
          : SimpleSpanProcessor(exporter);
      final span = OTel.tracer().startSpan('test');
      await processor.onEnd(span);
      await processor.forceFlush();
      expect(errors, [same(error)]);
      expect(stacks.single, same(stack));
      await processor.shutdown();
    });

    test('${batch ? 'batch' : 'simple'} log processor reports failure results',
        () async {
      final exporter = _FailingLogExporter();
      final processor = batch
          ? BatchLogRecordProcessor(
              exporter,
              const BatchLogRecordProcessorConfig(
                  scheduleDelay: Duration(hours: 1)))
          : SimpleLogRecordProcessor(exporter);
      await processor.onEmit(record(), null);
      await processor.forceFlush();
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('Export failed'));
      await processor.shutdown();
    });
  }

  test('simple log processor routes thrown errors', () async {
    final processor =
        SimpleLogRecordProcessor(_FailingLogExporter(error: error));
    await processor.onEmit(record(), null);
    expect(errors, [same(error)]);
    expect(stacks.single, isNotNull);
    await processor.shutdown();
  });

  test('batch log timeout is reported once', () async {
    final processor = BatchLogRecordProcessor(
        _FailingLogExporter(hang: true),
        const BatchLogRecordProcessorConfig(
          scheduleDelay: Duration(hours: 1),
          exportTimeout: Duration(milliseconds: 1),
        ));
    await processor.onEmit(record(), null);
    await processor.forceFlush();
    expect(errors, [isA<TimeoutException>()]);
    await processor.shutdown();
  });

  test('strict handler propagates from simple processor once', () async {
    final strictError = StateError('strict');
    OTel.setErrorHandler((e, _) {
      errors.add(e);
      throw strictError;
    });
    final processor = SimpleSpanProcessor(_FailingSpanExporter(error, stack));
    await expectLater(processor.onEnd(OTel.tracer().startSpan('test')),
        throwsA(same(strictError)));
    expect(errors, [same(error)]);
  });

  test('metric reader and composite route lifecycle failures', () async {
    final exporter = _FailingMetricExporter(error);
    final reader = PeriodicExportingMetricReader(exporter,
        interval: const Duration(hours: 1));
    expect(await reader.forceFlush(), isFalse);
    expect(await reader.shutdown(), isFalse);
    final composite = CompositeMetricExporter([exporter]);
    expect(await composite.export(MetricData.empty()), isFalse);
    expect(await composite.forceFlush(), isFalse);
    expect(await composite.shutdown(), isFalse);
    expect(errors, List.filled(5, same(error)));
  });

  test('successful retry does not report a failure', () async {
    var requests = 0;
    await http.runWithClient(() async {
      final exporter =
          OtlpHttpLogRecordExporter(OtlpHttpLogRecordExporterConfig(
        maxRetries: 1,
        baseDelay: const Duration(milliseconds: 1),
        maxDelay: const Duration(milliseconds: 1),
      ));
      expect(await exporter.export([record()]), ExportResult.success);
      await exporter.shutdown();
    },
        () => MockClient(
            (_) async => http.Response('', ++requests == 1 ? 503 : 200)));
    expect(requests, 2);
    expect(errors, isEmpty);
  });

  test('strict handler exception escapes HTTP exporter without retrying',
      () async {
    var requests = 0;
    final strictError = StateError('strict');
    OTel.setErrorHandler((error, _) {
      errors.add(error);
      throw strictError;
    });
    await http.runWithClient(() async {
      final exporter =
          OtlpHttpLogRecordExporter(OtlpHttpLogRecordExporterConfig(
        maxRetries: 2,
        baseDelay: const Duration(milliseconds: 1),
        maxDelay: const Duration(milliseconds: 1),
      ));
      await expectLater(
          exporter.export([record()]), throwsA(same(strictError)));
      await exporter.shutdown();
    },
        () => MockClient((_) async {
              requests++;
              return http.Response('', 400);
            }));
    expect(requests, 1);
    expect(errors, hasLength(1));
  });

  for (final signal in ['traces', 'logs', 'metrics']) {
    test('$signal HTTP exporter reports exhausted retries once', () async {
      var requests = 0;
      await http.runWithClient(() async {
        if (signal == 'traces') {
          final exporter = OtlpHttpSpanExporter(OtlpHttpExporterConfig(
              maxRetries: 1,
              baseDelay: const Duration(milliseconds: 1),
              maxDelay: const Duration(milliseconds: 1)));
          await expectLater(exporter.export([OTel.tracer().startSpan('test')]),
              throwsA(anything));
          await exporter.shutdown();
        } else if (signal == 'logs') {
          final exporter = OtlpHttpLogRecordExporter(
              OtlpHttpLogRecordExporterConfig(
                  maxRetries: 1,
                  baseDelay: const Duration(milliseconds: 1),
                  maxDelay: const Duration(milliseconds: 1)));
          expect(await exporter.export([record()]), ExportResult.failure);
          await exporter.shutdown();
        } else {
          final exporter = OtlpHttpMetricExporter(OtlpHttpMetricExporterConfig(
              maxRetries: 1,
              baseDelay: const Duration(milliseconds: 1),
              maxDelay: const Duration(milliseconds: 1)));
          expect(
              await exporter.export(MetricData(
                  resource: Resource.empty,
                  metrics: [
                    Metric(name: 'test', type: MetricType.gauge, points: [])
                  ])),
              isFalse);
          await exporter.shutdown();
        }
      },
          () => MockClient((_) async {
                requests++;
                return http.Response('', 503);
              }));
      expect(requests, 2);
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('503'));
      expect(stacks.single, isNotNull);
    });
  }
}
