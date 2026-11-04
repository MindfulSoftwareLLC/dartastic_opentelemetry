// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
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

    late List<String> warnings;

    setUp(() async {
      warnings = [];
      OTelLog.logFunction = warnings.add;
      OTelLog.currentLevel = LogLevel.warn;
      await OTel.reset();
      EnvironmentService.testOverrides = {'OTEL_TRACES_EXPORTER': 'none'};
      await OTel.initialize(
        serviceName: 'traces-config-test',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      OTelLog.logFunction = print;
      OTelLog.currentLevel = LogLevel.info;
      await OTel.shutdown();
      await OTel.reset();
      EnvironmentService.testOverrides = null;
    });

    test(
        'default configuration produces batch processor with otlp http exporter',
        () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
      );
      final processor = provider.spanProcessors.single as BatchSpanProcessor;
      expect(processor.exporter, isA<OtlpHttpSpanExporter>());
    });

    test('endpoint parameter is used when otlp config endpoint is null', () {
      OTelLog.currentLevel = LogLevel.debug;

      TracesConfiguration.configureTracerProvider(
        endpoint: 'http://param-collector:4318',
        exporters: const ['otlp'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
      );

      expect(
        warnings.join('\n'),
        contains(
          'OtlpHttpSpanExporter: Created with endpoint: '
          'http://param-collector:4318',
        ),
      );
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
      final processor = provider.spanProcessors.single as BatchSpanProcessor;
      expect(processor.exporter, isA<OtlpGrpcSpanExporter>());
    });

    for (final protocol in ['http/protobuf', 'http/json', 'unknown_protocol']) {
      test('protocol $protocol produces http exporter', () {
        final otlpConfig = (
          endpoint: 'http://localhost:4318',
          protocol: protocol,
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
        final processor = provider.spanProcessors.single as BatchSpanProcessor;
        expect(processor.exporter, isA<OtlpHttpSpanExporter>());
      });
    }

    test(
        'none exporter with other values emits warning and installs no processor',
        () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['none', 'console'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
      );
      expect(provider.spanProcessors, isEmpty);
      expect(warnings.join('\n'), contains("contains 'none'"));
    });

    test('multiple valid exporters creates composite exporter', () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp', 'console'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
      );
      final processor = provider.spanProcessors.single as BatchSpanProcessor;
      expect(processor.exporter, isA<CompositeExporter>());
      final composite = processor.exporter as CompositeExporter;
      expect(composite.spanExporters, [
        isA<OtlpHttpSpanExporter>(),
        isA<ConsoleExporter>(),
      ]);
    });

    test('console, logging, and invalid exporters', () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['console', 'logging', 'invalid'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
      );
      final processor = provider.spanProcessors.single as BatchSpanProcessor;
      expect(processor.exporter, isA<ConsoleExporter>());
      final warnOutput = warnings.join('\n');
      expect(warnOutput, contains('deprecated'));
      expect(warnOutput, contains("'invalid' is not supported"));
    });

    test('all invalid falls back to otlp with warning', () {
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['invalid2'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
      );
      final processor = provider.spanProcessors.single as BatchSpanProcessor;
      expect(processor.exporter, isA<OtlpHttpSpanExporter>());
      expect(warnings.join('\n'), contains('falling back'));
    });

    test('custom span processor overrides exporter setup', () {
      final customProcessor = SimpleSpanProcessor(ConsoleExporter());
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
        spanProcessor: customProcessor,
      );
      expect(provider.spanProcessors.single, same(customProcessor));
    });

    test('custom non-empty resource is applied', () {
      final customResource = OTel.resource(
        OTel.attributesFromMap({'service.name': 'custom-service'}),
      );
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
        resource: customResource,
      );
      expect(provider.resource, same(customResource));
    });

    test('custom sampler is applied', () {
      const customSampler = AlwaysOffSampler();
      final provider = TracesConfiguration.configureTracerProvider(
        exporters: const ['otlp'],
        otlpConfig: emptyOtlpConfig,
        bspConfig: bspConfig,
        sampler: customSampler,
      );
      expect(provider.sampler, same(customSampler));
    });
  });
}
