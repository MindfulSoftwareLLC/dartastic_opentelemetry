// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpHttpSpanExporter', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    group('constructor', () {
      test('creates exporter with default config', () {
        final exporter = OtlpHttpSpanExporter();
        expect(exporter, isNotNull);
      });

      test('creates exporter with custom config', () {
        final config = OtlpHttpExporterConfig(
          endpoint: 'http://custom-host:4318',
          timeout: const Duration(seconds: 30),
          compression: true,
          maxRetries: 5,
        );
        final exporter = OtlpHttpSpanExporter(config);
        expect(exporter, isNotNull);
      });

      test('creates exporter with custom headers', () {
        final config = OtlpHttpExporterConfig(
          headers: {'authorization': 'Bearer test-token'},
        );
        final exporter = OtlpHttpSpanExporter(config);
        expect(exporter, isNotNull);
      });
    });

    group('export', () {
      test('throws StateError after shutdown', () async {
        final exporter = OtlpHttpSpanExporter();
        await exporter.shutdown();

        final tracer = OTel.tracer();
        final span = tracer.startSpan('test-span');
        span.end();

        expect(
          () => exporter.export([span]),
          throwsA(isA<StateError>()),
        );
      });

      test('with empty span list returns without error', () async {
        final exporter = OtlpHttpSpanExporter();

        // Empty list should return immediately without error
        await exporter.export([]);
      });
    });

    group('shutdown', () {
      test('completes successfully', () async {
        final exporter = OtlpHttpSpanExporter();
        await exporter.shutdown();
        // No error means success
      });

      test('is idempotent - can be called multiple times', () async {
        final exporter = OtlpHttpSpanExporter();
        await exporter.shutdown();
        await exporter.shutdown();
        // No error means success - second call is a no-op
      });

      test('sets shutdown state so export throws StateError', () async {
        final exporter = OtlpHttpSpanExporter();

        // Export with empty list should work before shutdown
        await exporter.export([]);

        await exporter.shutdown();

        // After shutdown, export should throw
        final tracer = OTel.tracer();
        final span = tracer.startSpan('test-span');
        span.end();

        expect(
          () => exporter.export([span]),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('forceFlush', () {
      test('returns without error before shutdown', () async {
        final exporter = OtlpHttpSpanExporter();
        await exporter.forceFlush();
        // No error means success
      });

      test('returns without error after shutdown', () async {
        final exporter = OtlpHttpSpanExporter();
        await exporter.shutdown();
        await exporter.forceFlush();
        // No error means success - just returns when shutdown
      });
    });
  });
}
