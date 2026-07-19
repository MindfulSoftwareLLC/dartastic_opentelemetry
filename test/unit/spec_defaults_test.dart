// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Spec-compliance tests for SDK defaults and the OTEL_*_EXPORTER /
/// OTEL_SDK_DISABLED env vars.
///
/// References:
/// - https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
///
/// These run the `check_initialized_pipeline.dart` helper in a subprocess
/// with specific env vars so that `Platform.environment` (which is read by
/// `EnvironmentService.instance` and is otherwise unmodifiable) actually
/// reflects the test scenario.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const _helper = 'test/unit/environment/helpers/check_initialized_pipeline.dart';

/// Runs the pipeline helper in a subprocess with the given env vars layered
/// on top of the current process environment. Returns the parsed pipeline
/// snapshot.
Future<Map<String, dynamic>> _runPipeline(Map<String, String> envVars) async {
  // Start from a clean slate so a developer's local OTEL_* vars can't change
  // the meaning of these tests; then layer on the scenario-specific vars.
  final env = <String, String>{};
  for (final entry in Platform.environment.entries) {
    if (entry.key.startsWith('OTEL_')) continue;
    env[entry.key] = entry.value;
  }
  env.addAll(envVars);

  final result = await Process.run(
    Platform.executable,
    ['run', _helper],
    environment: env,
    includeParentEnvironment: false,
    workingDirectory: Directory.current.path,
  );
  if (result.exitCode != 0) {
    throw Exception(
      'Helper failed with exit code ${result.exitCode}:\n'
      'stdout: ${result.stdout}\n'
      'stderr: ${result.stderr}',
    );
  }

  final stdout = (result.stdout as String).trim();
  // The helper prints exactly one JSON line; anything else is debug noise we
  // ignore. Find the JSON line.
  final jsonLine = stdout
      .split('\n')
      .lastWhere((line) => line.startsWith('{'), orElse: () => stdout);
  return jsonDecode(jsonLine) as Map<String, dynamic>;
}

List<String> _spanProcessors(Map<String, dynamic> snap) =>
    (snap['spanProcessors'] as List).cast<String>();
List<String> _metricReaders(Map<String, dynamic> snap) =>
    (snap['metricReaders'] as List).cast<String>();
List<String> _logProcessors(Map<String, dynamic> snap) =>
    (snap['logRecordProcessors'] as List).cast<String>();

void main() {
  group('Spec-compliant defaults (no env vars)', () {
    late Map<String, dynamic> snap;

    setUpAll(() async {
      snap = await _runPipeline(const {});
    });

    test('traces default to OTLP exporter, no ConsoleExporter', () {
      final processors = _spanProcessors(snap);
      expect(processors, hasLength(1));
      expect(processors.single, contains('Otlp'));
      expect(processors.single, isNot(contains('ConsoleExporter')));
    });

    test('metrics default to OTLP exporter only, no ConsoleMetricExporter', () {
      final readers = _metricReaders(snap);
      expect(readers, hasLength(1));
      expect(readers.single, contains('Otlp'));
      // The bug we are fixing: default pipeline must not stream metrics to
      // stdout when the user has not opted in.
      expect(readers.single, isNot(contains('ConsoleMetricExporter')));
    });

    test('logs default to OTLP exporter, no console exporter', () {
      final processors = _logProcessors(snap);
      expect(processors, hasLength(1));
      expect(processors.single, contains('Otlp'));
      expect(processors.single, isNot(contains('Console')));
    });
  });

  group('OTEL_TRACES_EXPORTER', () {
    test('=none drops the span processor entirely', () async {
      final snap = await _runPipeline(const {'OTEL_TRACES_EXPORTER': 'none'});
      expect(_spanProcessors(snap), isEmpty);
      // Other signals stay on their spec defaults.
      expect(_metricReaders(snap), isNotEmpty);
      expect(_logProcessors(snap), isNotEmpty);
    });

    test('=console switches to ConsoleExporter', () async {
      final snap =
          await _runPipeline(const {'OTEL_TRACES_EXPORTER': 'console'});
      final processors = _spanProcessors(snap);
      expect(processors, hasLength(1));
      expect(processors.single, contains('ConsoleExporter'));
      expect(processors.single, isNot(contains('Otlp')));
    });

    test(
        '=otlp,console installs both via a CompositeExporter (spec list '
        'form)', () async {
      final snap =
          await _runPipeline(const {'OTEL_TRACES_EXPORTER': 'otlp,console'});
      final processors = _spanProcessors(snap);
      expect(processors, hasLength(1));
      expect(processors.single, contains('CompositeExporter'));
      expect(processors.single, contains('OtlpHttpSpanExporter'));
      expect(processors.single, contains('ConsoleExporter'));
    });

    test('unsupported values are ignored with the rest honored', () async {
      final snap =
          await _runPipeline(const {'OTEL_TRACES_EXPORTER': 'zipkin,console'});
      final processors = _spanProcessors(snap);
      expect(processors, hasLength(1));
      expect(processors.single, contains('ConsoleExporter'));
      expect(processors.single, isNot(contains('Composite')));
    });

    test('deprecated logging value falls back to the otlp default', () async {
      final snap =
          await _runPipeline(const {'OTEL_TRACES_EXPORTER': 'logging'});
      final processors = _spanProcessors(snap);
      expect(processors, hasLength(1));
      expect(processors.single, contains('OtlpHttpSpanExporter'));
    });

    test('none wins over other values in a list', () async {
      final snap =
          await _runPipeline(const {'OTEL_TRACES_EXPORTER': 'console,none'});
      expect(_spanProcessors(snap), isEmpty);
    });
  });

  group('OTEL_METRICS_EXPORTER', () {
    test('=none drops the metric reader entirely', () async {
      final snap = await _runPipeline(const {'OTEL_METRICS_EXPORTER': 'none'});
      expect(_metricReaders(snap), isEmpty);
      // Other signals stay on their spec defaults.
      expect(_spanProcessors(snap), isNotEmpty);
      expect(_logProcessors(snap), isNotEmpty);
    });

    test('=console switches to ConsoleMetricExporter', () async {
      final snap =
          await _runPipeline(const {'OTEL_METRICS_EXPORTER': 'console'});
      final readers = _metricReaders(snap);
      expect(readers, hasLength(1));
      expect(readers.single, contains('ConsoleMetricExporter'));
      expect(readers.single, isNot(contains('Otlp')));
    });

    test('=prometheus warns (no scrape server yet) and falls back to otlp',
        () async {
      final snap =
          await _runPipeline(const {'OTEL_METRICS_EXPORTER': 'prometheus'});
      final readers = _metricReaders(snap);
      expect(readers, hasLength(1));
      expect(readers.single, contains('OtlpHttpMetricExporter'));
      expect(readers.single, isNot(contains('Prometheus')));
    });

    test('unknown metrics value warns and is ignored, not silently otlp',
        () async {
      final snap =
          await _runPipeline(const {'OTEL_METRICS_EXPORTER': 'bogus,console'});
      final readers = _metricReaders(snap);
      expect(readers, hasLength(1));
      expect(readers.single, contains('ConsoleMetricExporter'));
      expect(readers.single, isNot(contains('Composite')));
    });

    test(
        '=otlp,console installs both via a CompositeMetricExporter (spec '
        'list form)', () async {
      final snap =
          await _runPipeline(const {'OTEL_METRICS_EXPORTER': 'otlp,console'});
      final readers = _metricReaders(snap);
      expect(readers, hasLength(1));
      expect(readers.single, contains('CompositeMetricExporter'));
      expect(readers.single, contains('OtlpHttpMetricExporter'));
      expect(readers.single, contains('ConsoleMetricExporter'));
    });
  });

  group('OTEL_LOGS_EXPORTER', () {
    test('=none drops the log record processor entirely', () async {
      final snap = await _runPipeline(const {'OTEL_LOGS_EXPORTER': 'none'});
      expect(_logProcessors(snap), isEmpty);
      // Other signals stay on their spec defaults.
      expect(_spanProcessors(snap), isNotEmpty);
      expect(_metricReaders(snap), isNotEmpty);
    });

    test('=console switches to ConsoleLogRecordExporter', () async {
      final snap = await _runPipeline(const {'OTEL_LOGS_EXPORTER': 'console'});
      final processors = _logProcessors(snap);
      expect(processors, hasLength(1));
      expect(processors.single, contains('Console'));
      expect(processors.single, isNot(contains('Otlp')));
    });

    test(
        '=otlp,console installs one processor per exporter (spec list '
        'form)', () async {
      final snap =
          await _runPipeline(const {'OTEL_LOGS_EXPORTER': 'otlp,console'});
      final processors = _logProcessors(snap);
      expect(processors, hasLength(2));
      expect(processors.join(','), contains('OtlpHttpLogRecordExporter'));
      expect(processors.join(','), contains('ConsoleLogRecordExporter'));
    });
  });

  group('OTEL_SDK_DISABLED', () {
    test('=true silences all three signals', () async {
      final snap = await _runPipeline(const {'OTEL_SDK_DISABLED': 'true'});
      expect(_spanProcessors(snap), isEmpty);
      expect(_metricReaders(snap), isEmpty);
      expect(_logProcessors(snap), isEmpty);
    });

    test('=false has no effect (defaults remain)', () async {
      final snap = await _runPipeline(const {'OTEL_SDK_DISABLED': 'false'});
      expect(_spanProcessors(snap), isNotEmpty);
      expect(_metricReaders(snap), isNotEmpty);
      expect(_logProcessors(snap), isNotEmpty);
    });
  });
}
