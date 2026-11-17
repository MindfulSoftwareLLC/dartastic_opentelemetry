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
  int shutdowns = 0;
  @override
  Future<void> shutdown() async {
    shutdowns++;
  }
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
  int shutdowns = 0;
  @override
  Future<void> shutdown() async {
    shutdowns++;
  }
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

class _TrackingClient extends MockClient {
  int closes = 0;
  _TrackingClient(super.handler);
  @override
  void close() {
    closes++;
    super.close();
  }
}

class _SilentMetricExporter implements MetricExporter {
  int shutdowns = 0;
  @override
  Future<bool> export(MetricData data) async => false;
  @override
  Future<bool> forceFlush() async => true;
  @override
  Future<bool> shutdown() async {
    shutdowns++;
    return true;
  }
}

class _TestReader extends PeriodicExportingMetricReader {
  _TestReader(super.exporter, {super.timeout})
      : super(interval: const Duration(hours: 1));
  @override
  Future<MetricData> collect() async => _metricData();
}

MetricData _metricData() => MetricData(resource: Resource.empty, metrics: [
      Metric(name: 'test', type: MetricType.gauge, points: []),
    ]);

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
          await SimpleSpanProcessor(exporter)
              .onEnd(OTel.tracer().startSpan('test'));
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
  for (final batch in [false, true]) {
    test(
        'real HTTP exporters report once through ${batch ? 'batch' : 'simple'} processors',
        () async {
      await http.runWithClient(() async {
        final spanExporter =
            OtlpHttpSpanExporter(OtlpHttpExporterConfig(maxRetries: 0));
        final spans = batch
            ? BatchSpanProcessor(
                spanExporter,
                const BatchSpanProcessorConfig(
                    scheduleDelay: Duration(hours: 1)))
            : SimpleSpanProcessor(spanExporter);
        await spans.onEnd(OTel.tracer().startSpan('pipeline'));
        await spans.forceFlush();
        await spans.shutdown();
        final logExporter = OtlpHttpLogRecordExporter(
            OtlpHttpLogRecordExporterConfig(maxRetries: 0));
        final logs = batch
            ? BatchLogRecordProcessor(
                logExporter,
                const BatchLogRecordProcessorConfig(
                    scheduleDelay: Duration(hours: 1)))
            : SimpleLogRecordProcessor(logExporter);
        await logs.onEmit(record(), null);
        await logs.forceFlush();
        await logs.shutdown();
      }, () => MockClient((_) async => http.Response('', 400)));
      expect(errors, hasLength(2));
      expect(errors.every((e) => e.toString().contains('400')), isTrue);
    });
  }

  test('metric exporter composite and reader report original error once',
      () async {
    await http.runWithClient(() async {
      final exporter =
          OtlpHttpMetricExporter(OtlpHttpMetricExporterConfig(maxRetries: 0));
      final reader = _TestReader(CompositeMetricExporter([exporter]));
      reader.registerMeterProvider(OTel.addMeterProvider('pipeline'));
      await reader.forceFlush();
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('400'));
      await reader.shutdown();
      expect(errors, hasLength(2));
    }, () => MockClient((_) async => http.Response('', 400)));
  });

  test('each silent composite delegate still gets a fallback', () async {
    final reader = _TestReader(CompositeMetricExporter([
      _SilentMetricExporter(),
      _SilentMetricExporter(),
    ]));
    reader.registerMeterProvider(OTel.addMeterProvider('silent'));
    await reader.forceFlush();
    expect(errors, hasLength(2));
    await reader.shutdown();
  });

  test('reader shuts down exporter when final export handler throws once',
      () async {
    final exporter = _SilentMetricExporter();
    final reader = _TestReader(CompositeMetricExporter([exporter]));
    reader.registerMeterProvider(OTel.addMeterProvider('strict'));
    final strict = StateError('strict');
    OTel.setErrorHandler((e, _) {
      errors.add(e);
      throw strict;
    });
    await expectLater(reader.shutdown(), throwsA(same(strict)));
    expect(exporter.shutdowns, 1);
    expect(errors, hasLength(1));
  });

  for (final signal in ['traces', 'logs', 'metrics']) {
    test('$signal HTTP shutdown closes client with throwing handler', () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final client = _TrackingClient((_) {
        started.complete();
        return response.future;
      });
      final strict = StateError('strict');
      OTel.setErrorHandler((e, _) {
        errors.add(e);
        throw strict;
      });
      await http.runWithClient(() async {
        late Future<void> Function() shutdown;
        late Future<Object?> operation;
        if (signal == 'traces') {
          final exporter =
              OtlpHttpSpanExporter(OtlpHttpExporterConfig(maxRetries: 0));
          operation = SimpleSpanProcessor(exporter)
              .onEnd(OTel.tracer().startSpan('strict'));
          shutdown = exporter.shutdown;
        } else if (signal == 'logs') {
          final exporter = OtlpHttpLogRecordExporter(
              OtlpHttpLogRecordExporterConfig(maxRetries: 0));
          operation = exporter.export([record()]);
          shutdown = exporter.shutdown;
        } else {
          final exporter = OtlpHttpMetricExporter(
              OtlpHttpMetricExporterConfig(maxRetries: 0));
          operation = exporter.export(_metricData());
          shutdown = () async {
            await exporter.shutdown();
          };
        }
        final exportCheck = expectLater(operation, throwsA(same(strict)));
        await started.future;
        final closing = shutdown();
        final closeCheck = signal == 'traces'
            ? expectLater(closing, completes)
            : expectLater(closing, throwsA(same(strict)));
        response.complete(http.Response('', 400));
        await Future.wait([exportCheck, closeCheck]);
        expect(client.closes, 1);
        await shutdown();
        expect(client.closes, 1);
      }, () => client);
      expect(errors, hasLength(1));
    });
  }

  for (final signal in ['logs', 'metrics', 'traces']) {
    test('$signal shutdown during retry preserves reporting policy', () async {
      final retrying = Completer<void>();
      OTelLog.currentLevel = LogLevel.debug;
      OTelLog.logFunction = (message) {
        if (message.contains('Retrying') && !retrying.isCompleted) {
          retrying.complete();
        }
      };
      await http.runWithClient(() async {
        late Future<void> Function() shutdown;
        late Future<Object?> operation;
        if (signal == 'logs') {
          final exporter = OtlpHttpLogRecordExporter(
              OtlpHttpLogRecordExporterConfig(
                  maxRetries: 1,
                  baseDelay: const Duration(milliseconds: 100),
                  maxDelay: const Duration(milliseconds: 100)));
          operation = exporter.export([record()]);
          shutdown = exporter.shutdown;
        } else if (signal == 'metrics') {
          final exporter = OtlpHttpMetricExporter(OtlpHttpMetricExporterConfig(
              maxRetries: 1,
              baseDelay: const Duration(milliseconds: 100),
              maxDelay: const Duration(milliseconds: 100)));
          operation = CompositeMetricExporter([exporter]).export(_metricData());
          shutdown = () async {
            await exporter.shutdown();
          };
        } else {
          final exporter = OtlpHttpSpanExporter(OtlpHttpExporterConfig(
              maxRetries: 1,
              baseDelay: const Duration(milliseconds: 100),
              maxDelay: const Duration(milliseconds: 100)));
          operation = SimpleSpanProcessor(exporter)
              .onEnd(OTel.tracer().startSpan('cancel'));
          shutdown = exporter.shutdown;
        }
        await retrying.future;
        await shutdown();
        await operation;
      }, () => MockClient((_) async => http.Response('', 503)));
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('503'));
      expect(stacks.single, isNotNull);
    });
  }
  for (final shutdown in [false, true]) {
    test(
        'span.end followed by ${shutdown ? 'SDK shutdown' : 'flush'} reports once',
        () async {
      await OTel.reset();
      OTel.setErrorHandler((error, stack) {
        errors.add(error);
        stacks.add(stack);
      });
      final started = Completer<void>();
      final response = Completer<http.Response>();
      await http.runWithClient(() async {
        final processor = SimpleSpanProcessor(OtlpHttpSpanExporter(
          OtlpHttpExporterConfig(maxRetries: 0),
        ));
        await OTel.initialize(
            detectPlatformResources: false,
            enableLogs: false,
            enableMetrics: false,
            spanProcessor: processor);
        OTel.tracer().startSpan('end then drain').end();
        await started.future;
        final draining = shutdown ? OTel.shutdown() : processor.forceFlush();
        response.complete(http.Response('', 400));
        await draining;
        expect(errors, hasLength(1));
        expect(errors.single.toString(), contains('400'));
        expect(stacks.single, isNotNull);
        if (!shutdown) await OTel.shutdown();
        expect(errors, hasLength(1));
      },
          () => MockClient((_) {
                started.complete();
                return response.future;
              }));
    });
  }

  test('batch span SDK shutdown reports interrupted retry once', () async {
    await OTel.reset();
    OTel.setErrorHandler((error, stack) {
      errors.add(error);
      stacks.add(stack);
    });
    final retrying = Completer<void>();
    await http.runWithClient(() async {
      final exporter = OtlpHttpSpanExporter(OtlpHttpExporterConfig());
      final processor = BatchSpanProcessor(exporter,
          const BatchSpanProcessorConfig(scheduleDelay: Duration(hours: 1)));
      await OTel.initialize(
          detectPlatformResources: false,
          enableLogs: false,
          enableMetrics: false,
          spanProcessor: processor);
      OTelLog.currentLevel = LogLevel.debug;
      OTelLog.logFunction = (message) {
        if (message.contains('Retrying export after') &&
            !retrying.isCompleted) {
          retrying.complete();
        }
      };
      OTel.tracer().startSpan('batch retry shutdown').end();
      final exporting = processor.forceFlush();
      await retrying.future;
      await OTel.shutdown();
      await exporting;
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('503'));
    }, () => MockClient((_) async => http.Response('', 503)));
  });

  for (final signal in ['logs', 'metrics', 'composite metrics']) {
    test(
        '$signal reports outer timeout once after all transport retries finish',
        () async {
      var requests = 0;
      final timedOut = Completer<void>();
      OTel.setErrorHandler((error, stack) {
        errors.add(error);
        stacks.add(stack);
        if (!timedOut.isCompleted) timedOut.complete();
      });
      await http.runWithClient(() async {
        late Future<void> flushing;
        late Future<void> Function() cleanup;
        if (signal == 'logs') {
          final exporter = OtlpHttpLogRecordExporter(
              OtlpHttpLogRecordExporterConfig(
                  timeout: const Duration(milliseconds: 40),
                  maxRetries: 3,
                  baseDelay: const Duration(milliseconds: 1),
                  maxDelay: const Duration(milliseconds: 1)));
          final processor = BatchLogRecordProcessor(
              exporter,
              const BatchLogRecordProcessorConfig(
                  scheduleDelay: Duration(hours: 1),
                  exportTimeout: Duration(milliseconds: 20)));
          await processor.onEmit(record(), null);
          flushing = processor.forceFlush();
          cleanup = processor.shutdown;
        } else {
          final exporter = OtlpHttpMetricExporter(OtlpHttpMetricExporterConfig(
              timeout: const Duration(milliseconds: 40),
              maxRetries: 3,
              baseDelay: const Duration(milliseconds: 1),
              maxDelay: const Duration(milliseconds: 1)));
          final reader = _TestReader(
              signal == 'metrics'
                  ? exporter
                  : CompositeMetricExporter([exporter]),
              timeout: const Duration(milliseconds: 20));
          reader.registerMeterProvider(OTel.addMeterProvider('late-timeout'));
          flushing = reader.forceFlush().then((_) {});
          cleanup = () async {
            await reader.shutdown();
          };
        }
        await timedOut.future;
        expect(errors, [
          isA<TimeoutException>().having((e) => e.duration, 'outer timeout',
              const Duration(milliseconds: 20))
        ]);
        // forceFlush drains the still-running HTTP export after the outer timeout.
        await flushing;
        expect(requests, 4);
        expect(errors, hasLength(1));
        OTel.setErrorHandler((_, __) {});
        await cleanup();
      },
          () => MockClient((_) {
                requests++;
                return Completer<http.Response>().future;
              }));
    });
  }
  for (final signal in ['spans', 'logs']) {
    test(
        'batch $signal shutdown closes exporter when strict drain handler throws',
        () async {
      final strictError = StateError('strict shutdown');
      OTel.setErrorHandler((e, st) {
        errors.add(e);
        throw strictError;
      });
      final spanExporter = _FailingSpanExporter(error, stack);
      final logExporter = _FailingLogExporter(error: error);
      late Future<void> Function() shutdown;
      if (signal == 'spans') {
        final processor = BatchSpanProcessor(spanExporter,
            const BatchSpanProcessorConfig(scheduleDelay: Duration(hours: 1)));
        await processor.onEnd(OTel.tracer().startSpan('final drain'));
        shutdown = processor.shutdown;
      } else {
        final processor = BatchLogRecordProcessor(
            logExporter,
            const BatchLogRecordProcessorConfig(
                scheduleDelay: Duration(hours: 1)));
        await processor.onEmit(record(), null);
        shutdown = processor.shutdown;
      }
      await expectLater(shutdown(), throwsA(same(strictError)));
      expect(errors, [same(error)]);
      expect(signal == 'spans' ? spanExporter.shutdowns : logExporter.shutdowns,
          1);
      await shutdown();
      expect(signal == 'spans' ? spanExporter.shutdowns : logExporter.shutdowns,
          1);
    });
  }
}
