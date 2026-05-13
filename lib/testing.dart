// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

/// Test helpers for the Dartastic OpenTelemetry SDK.
///
/// Import this library from `test/` only:
///
/// ```dart
/// import 'package:dartastic_opentelemetry/testing.dart';
/// ```
///
/// It is intentionally **not** exported from the main
/// `package:dartastic_opentelemetry/dartastic_opentelemetry.dart`
/// barrel so production bundles don't carry the in-memory exporter
/// classes.
///
/// Provides:
/// - [InMemorySpanExporter] — collects exported spans into a list with
///   query helpers (`findSpanByName`, `findSpansByName`,
///   `findSpansStartingWith`, `clear`).
/// - [InMemoryLogExporter] — same idea for log records.
/// - [InMemoryMetricExporter] — same idea for metrics; pair with
///   [OnDemandMetricReader].
/// - [OnDemandMetricReader] — a metric reader that never fires on a
///   timer; tests drive `collect()` explicitly via
///   [TestHarness.collectMetrics].
/// - [TestHarness] — bundles the three exporters and the reader,
///   plus a `clear()` to reset between tests.
/// - [maybeInitializeOtelForTest] — singleton initializer designed
///   for `setUpAll`. Brings up the real OpenTelemetry SDK pointed at
///   the in-memory exporters. Safe to call from multiple test files
///   in the same process; returns the same harness on subsequent
///   calls.
///
/// The shape mirrors the test harness used in the OTel-Dart reference
/// demo at https://github.com/MindfulSoftwareLLC/dart-otel-reference-demo
/// so wrappers, customer apps, and the reference demo all use the same
/// scaffolding.
library;

import 'dart:async';

import 'dartastic_opentelemetry.dart';

/// Span exporter that buffers spans in memory for inspection.
///
/// Tests typically:
///
/// ```dart
/// setUpAll(() async {
///   harness = await maybeInitializeOtelForTest();
///   spans = harness.spans;
/// });
/// setUp(() => harness.clear());
///
/// test('my_op emits a span', () {
///   doMyOp();
///   expect(spans.findSpanByName('my_op'), isNotNull);
/// });
/// ```
///
/// Use [findSpanByName] / [findSpansByName] / [findSpansStartingWith]
/// instead of indexing into [spans] directly — they make test failures
/// read more clearly.
class InMemorySpanExporter implements SpanExporter {
  /// Creates an exporter.
  InMemorySpanExporter();

  final List<Span> _spans = <Span>[];
  bool _isShutdown = false;

  /// All spans exported since the last [clear].
  List<Span> get spans => List<Span>.unmodifiable(_spans);

  /// All exported span names, in export order. Handy in `expect`
  /// assertions when you want to check the trace shape.
  List<String> get spanNames => _spans.map((s) => s.name).toList();

  /// Clears the recorded spans. Call between tests.
  void clear() => _spans.clear();

  /// Returns the **most recently** exported span with the given
  /// [name], or `null` if none match. Most-recent makes per-test
  /// reads stable when a span name happens to be reused across tests.
  Span? findSpanByName(String name) {
    for (var i = _spans.length - 1; i >= 0; i--) {
      if (_spans[i].name == name) return _spans[i];
    }
    return null;
  }

  /// Returns every exported span whose name equals [name].
  List<Span> findSpansByName(String name) =>
      _spans.where((s) => s.name == name).toList(growable: false);

  /// Returns every exported span whose name starts with [prefix].
  /// Useful for category-level assertions
  /// (e.g. `findSpansStartingWith('http ')`).
  List<Span> findSpansStartingWith(String prefix) =>
      _spans.where((s) => s.name.startsWith(prefix)).toList(growable: false);

  @override
  Future<void> export(List<Span> spans) async {
    if (_isShutdown) {
      throw StateError('InMemorySpanExporter is shutdown');
    }
    _spans.addAll(spans);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }
}

/// Log-record exporter that buffers records in memory for inspection.
class InMemoryLogExporter implements LogRecordExporter {
  /// Creates an exporter.
  InMemoryLogExporter();

  final List<LogRecord> _records = <LogRecord>[];
  bool _isShutdown = false;

  /// All records exported since the last [clear].
  List<LogRecord> get records => List<LogRecord>.unmodifiable(_records);

  /// Clears the recorded log records. Call between tests.
  void clear() => _records.clear();

  /// Returns every record with the given [severity].
  List<LogRecord> findRecordsBySeverity(Severity severity) =>
      _records.where((r) => r.severityNumber == severity).toList();

  @override
  Future<ExportResult> export(List<LogRecord> r) async {
    if (_isShutdown) return ExportResult.failure;
    _records.addAll(r);
    return ExportResult.success;
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }
}

/// Metric exporter that buffers exported metric snapshots in memory.
///
/// Use with [OnDemandMetricReader] so tests drive collection
/// explicitly — tests rarely want a timer fighting their
/// `expect` assertions.
class InMemoryMetricExporter implements MetricExporter {
  /// Creates an exporter.
  InMemoryMetricExporter();

  final List<Metric> _metrics = <Metric>[];
  bool _isShutdown = false;

  /// All metrics exported since the last [clear].
  List<Metric> get metrics => List<Metric>.unmodifiable(_metrics);

  /// Clears the recorded metrics. Call between tests.
  void clear() => _metrics.clear();

  /// Returns the most-recently exported metric named [name], or
  /// `null` if none match.
  Metric? findMetricByName(String name) {
    for (var i = _metrics.length - 1; i >= 0; i--) {
      if (_metrics[i].name == name) return _metrics[i];
    }
    return null;
  }

  @override
  Future<bool> export(MetricData data) async {
    if (_isShutdown) return false;
    _metrics.addAll(data.metrics);
    return true;
  }

  @override
  Future<bool> forceFlush() async => !_isShutdown;

  @override
  Future<bool> shutdown() async {
    _isShutdown = true;
    return true;
  }
}

/// Metric reader for tests. Never fires on a timer; tests drive
/// `collect()` explicitly via [TestHarness.collectMetrics] so
/// assertions don't race against a periodic export.
class OnDemandMetricReader extends MetricReader {
  /// Creates a reader that forwards collected metrics to [exporter].
  OnDemandMetricReader(this.exporter);

  /// The exporter that receives collected metrics.
  final MetricExporter exporter;
  bool _isShutdown = false;

  @override
  Future<MetricData> collect() async {
    final mp = meterProvider;
    if (mp == null || _isShutdown) {
      return MetricData.empty();
    }
    final metrics = await mp.collectAllMetrics();
    return MetricData(resource: mp.resource, metrics: metrics);
  }

  @override
  Future<bool> forceFlush() async {
    if (_isShutdown) return false;
    final data = await collect();
    if (data.metrics.isNotEmpty) {
      await exporter.export(data);
    }
    return await exporter.forceFlush();
  }

  @override
  Future<bool> shutdown() async {
    if (_isShutdown) return true;
    _isShutdown = true;
    return await exporter.shutdown();
  }
}

/// Bundles the three in-memory exporters and the on-demand metric
/// reader so tests have one handle to `clear()` between cases.
///
/// Construct via [maybeInitializeOtelForTest].
class TestHarness {
  /// Creates a harness. Prefer [maybeInitializeOtelForTest] over
  /// calling this directly.
  TestHarness({
    required this.spans,
    required this.logs,
    required this.metrics,
    required this.metricReader,
  });

  /// The span exporter that received every emitted span.
  final InMemorySpanExporter spans;

  /// The log exporter that received every emitted log record.
  final InMemoryLogExporter logs;

  /// The metric exporter that received every emitted metric snapshot.
  /// New snapshots arrive only when you call [collectMetrics].
  final InMemoryMetricExporter metrics;

  /// The reader driving metric collection.
  final MetricReader metricReader;

  /// Pumps the meter provider and forwards collected metrics to the
  /// in-memory exporter. Call this in a test after recording metrics
  /// but before asserting on [metrics].
  Future<void> collectMetrics() async {
    final data = await metricReader.collect();
    await metrics.export(data);
  }

  /// Forces the SDK's logger pipeline to flush. Tests that emit logs
  /// synchronously usually don't need this, but it's safe to call.
  Future<void> flushLogs() async {
    await OTel.loggerProvider().forceFlush();
  }

  /// Resets all three exporters' buffers. Call from `setUp()`.
  void clear() {
    spans.clear();
    logs.clear();
    metrics.clear();
  }
}

TestHarness? _shared;

/// Initializes the OpenTelemetry SDK once per test process with
/// in-memory exporters for spans / logs / metrics, and returns the
/// same [TestHarness] on subsequent calls.
///
/// Designed for `setUpAll`:
///
/// ```dart
/// late TestHarness harness;
/// late InMemorySpanExporter spans;
///
/// setUpAll(() async {
///   harness = await maybeInitializeOtelForTest(
///     serviceName: 'my_wrapper-test',
///   );
///   spans = harness.spans;
/// });
///
/// setUp(() => harness.clear());
/// ```
///
/// Idempotent — calling it from multiple test files in the same
/// process is fine; the SDK is initialized exactly once and every
/// caller gets the same exporters.
///
/// - [serviceName] becomes `service.name` on emitted telemetry.
/// - [endpoint] is a dummy — no exporter actually hits the network.
///   Override only if your code-under-test reads it.
Future<TestHarness> maybeInitializeOtelForTest({
  String serviceName = 'otel-test',
  String endpoint = 'http://localhost:4317',
}) async {
  if (_shared != null) return _shared!;
  final spanExporter = InMemorySpanExporter();
  final logExporter = InMemoryLogExporter();
  final metricExporter = InMemoryMetricExporter();
  final reader = OnDemandMetricReader(metricExporter);
  await OTel.initialize(
    endpoint: endpoint,
    serviceName: serviceName,
    serviceVersion: '0.0.0-test',
    spanProcessor: SimpleSpanProcessor(spanExporter),
    logRecordProcessor: SimpleLogRecordProcessor(logExporter),
    metricReader: reader,
    detectPlatformResources: false,
  );
  return _shared = TestHarness(
    spans: spanExporter,
    logs: logExporter,
    metrics: metricExporter,
    metricReader: reader,
  );
}
