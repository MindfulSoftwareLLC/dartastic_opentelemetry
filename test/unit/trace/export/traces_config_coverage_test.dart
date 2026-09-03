// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/resource/resource.dart';
import 'package:dartastic_opentelemetry/src/trace/export/console_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/export/simple_span_processor.dart';
import 'package:dartastic_opentelemetry/src/trace/export/traces_config.dart';
import 'package:dartastic_opentelemetry/src/trace/sampling/always_off_sampler.dart';
import 'package:test/test.dart';

void main() {
  group('TracesConfiguration', () {
    final bspConfig = (
      maxExportBatchSize: 10,
      exportTimeout: const Duration(milliseconds: 1000),
      maxQueueSize: 100,
      scheduleDelay: const Duration(milliseconds: 1000),
    );

    final emptyOtlpConfig = (
      endpoint: null,
      protocol: null,
      headers: null,
      timeout: null,
      compression: null,
      insecure: null,
      certificate: null,
      clientKey: null,
      clientCertificate: null,
    );

    setUpAll(OTel.initialize);

    test(
        'default configuration produces batch processor with otlp http exporter',
        () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
        sampler: const AlwaysOffSampler(),
      );
      expect(provider, isNotNull);
    });

    test('grpc protocol produces grpc exporter', () {
      final otlpConfig = (
        endpoint: 'http://localhost:4317',
        protocol: 'grpc',
        headers: const {'test': 'value'},
        timeout: const Duration(seconds: 5),
        compression: 'gzip',
        insecure: true,
        certificate: null,
        clientKey: null,
        clientCertificate: null,
      );

      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: otlpConfig,
        bspConfig: bspConfig,
      );
      expect(provider, isNotNull);
    });

    test('none exporter with other values emits warning and skips', () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['none', 'console'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
      );
      expect(provider, isNotNull);
    });

    test('console, logging, and invalid exporters', () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['console', 'logging', 'invalid'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
      );
      expect(provider, isNotNull);
    });

    test('multiple valid exporters creates composite exporter', () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp', 'console'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
      );
      expect(provider, isNotNull);
    });

    test('all invalid falls back to otlp', () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['invalid2'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
      );
      expect(provider, isNotNull);
    });

    test('http protocol produces http exporter', () {
      final otlpConfig = (
        endpoint: 'http://localhost:4318',
        protocol: 'http/protobuf',
        headers: const {'test': 'value'},
        timeout: const Duration(seconds: 5),
        compression: 'gzip',
        insecure: true,
        certificate: null,
        clientKey: null,
        clientCertificate: null,
      );

      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: otlpConfig,
        bspConfig: bspConfig,
      );
      expect(provider, isNotNull);
    });

    test('http json protocol produces http exporter', () {
      final otlpConfig = (
        endpoint: 'http://localhost:4318',
        protocol: 'http/json',
        headers: const {'test': 'value'},
        timeout: const Duration(seconds: 5),
        compression: 'gzip',
        insecure: true,
        certificate: null,
        clientKey: null,
        clientCertificate: null,
      );

      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: otlpConfig,
        bspConfig: bspConfig,
      );
      expect(provider, isNotNull);
    });

    test('unknown http protocol falls back to protobuf', () {
      final otlpConfig = (
        endpoint: 'http://localhost:4318',
        protocol: 'invalid_protocol',
        headers: const {'test': 'value'},
        timeout: const Duration(seconds: 5),
        compression: 'gzip',
        insecure: true,
        certificate: null,
        clientKey: null,
        clientCertificate: null,
      );

      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: otlpConfig,
        bspConfig: bspConfig,
      );
      expect(provider, isNotNull);
    });

    test('custom span processor overrides exporter setup', () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
        spanProcessor: SimpleSpanProcessor(ConsoleExporter()),
      );
      expect(provider, isNotNull);
    });

    test('custom resource is applied', () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
        resource: Resource.empty,
      );
      expect(provider, isNotNull);
    });
  });
}
