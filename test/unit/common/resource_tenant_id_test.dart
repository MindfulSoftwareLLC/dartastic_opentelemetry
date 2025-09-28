@Tags(['fail'])
library;

// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/resource/resource.dart';
import 'package:dartastic_opentelemetry/src/resource/resource_detector.dart';
import 'package:dartastic_opentelemetry/src/trace/export/batch_span_processor.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/otlp_grpc_span_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/otlp_grpc_span_exporter_config.dart';
import 'package:test/test.dart';

import '../../testing_utils/real_collector.dart';

void main() {
  //RealColletor is not reliable enough for unit tests
  group('Resource Tenant ID Test', () {
    late RealCollector collector;
    late OtlpGrpcSpanExporter exporter;
    final testDir = Directory.current.path;
    final configPath = '$testDir/test/testing_utils/otelcol-config.yaml';
    final outputPath = '$testDir/test/testing_utils/spans.json';

    setUp(() async {
      // Reset OTel state
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
        spanProcessor: null,
      );

      // Ensure output file exists and is empty
      File(outputPath).writeAsStringSync('');

      // Start collector
      collector = RealCollector(
        configPath: configPath,
        outputPath: outputPath,
      );
      await collector.start();

      // Create exporter
      exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://localhost:${collector.port}',
          insecure: true,
        ),
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await exporter.shutdown();
      await collector.stop();
      await collector.clear();
    });

    test('fix tenant_id and service.name issue', () async {
      // Reset OTel state first
      await OTel.reset();

      // Initialize OTel with service name
      final serviceName = 'example-service';
      await OTel.initialize(
          endpoint: 'http://localhost:${collector.port}',
          serviceName: serviceName,
          tenantId: '123456789',
          spanProcessor: null);

      // Create exporter
      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://localhost:${collector.port}',
          insecure: true,
        ),
      );

      // Create a batch processor
      final spanProcessor = BatchSpanProcessor(exporter);
      final tracerProvider = OTel.tracerProvider()
        ..addSpanProcessor(spanProcessor);

      // Create a span
      final tracer = tracerProvider.getTracer('example-tracer');
      final span = tracer.startSpan('test-operation');
      span.end();

      // Force flush and wait for spans
      await spanProcessor.forceFlush();
      await collector.waitForSpans(1);

      // Get the spans and print resource attributes
      final spans = await collector.getSpans();
      print('\nRESOURCE ATTRIBUTES with service name fix:');
      print(json.encode(spans[0]['resourceAttributes']));

      // Verify both service.name and tenant_id are present
      expect(spans[0]['resourceAttributes'],
          containsPair('service.name', serviceName),
          reason: 'service.name should be present in resource attributes');
      expect(spans[0]['resourceAttributes'],
          containsPair('tenant_id', '123456789'),
          reason: 'tenant_id should be present in resource attributes');

      await tracerProvider.shutdown();
    });

    test('verify service.name handling in tracer provider', () async {
      // Reset OTel state to start fresh
      await OTel.reset();

      // Initialize OTel with service name
      final serviceName = 'init-service-name';
      await OTel.initialize(
        endpoint: 'http://localhost:${collector.port}',
        serviceName: serviceName,
        detectPlatformResources: true, // Ensure platform resources are detected
      );

      // Create exporter with same endpoint
      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://localhost:${collector.port}',
          insecure: true,
        ),
      );
      final spanProcessor = BatchSpanProcessor(exporter);
      final tracerProvider = OTel.tracerProvider()
        ..addSpanProcessor(spanProcessor);

      // Create a tracer with different name
      final tracerName = 'my-instrumentation-library';
      final tracer = tracerProvider.getTracer(
        tracerName,
        version: '1.0.0',
      );

      // Create a span
      final span = tracer.startSpan('test-operation');
      span.end();

      // Force flush and wait for spans
      await spanProcessor.forceFlush();
      await collector.waitForSpans(1, timeout: const Duration(seconds: 10));

      // Get the spans and print all details
      final spans = await collector.getSpans();
      print('\nFULL SPAN DETAILS:');
      print(json.encode(spans[0]));
      print('\nRESOURCE ATTRIBUTES:');
      print(json.encode(spans[0]['resourceAttributes']));

      // Verify service.name is from initialize
      expect(spans[0]['resourceAttributes'],
          containsPair('service.name', serviceName),
          reason: 'service.name should come from OTel.initialize');

      // Shutdown
      await tracerProvider.shutdown();
    });

    test('tenant_id is properly included in resource attributes', () async {
      // 1. Create resources similar to the example
      final tenantId = '123456789';
      final Resource tenantIdResource = OTel.resource(OTel.attributesFromMap({
        'tenant_id': tenantId,
        'service.name': 'test-service' // Explicitly set service.name
      }));

      // Get platform resource
      final resourceDetector = PlatformResourceDetector.create();
      final platformResource = await resourceDetector.detect();

      // Important: merge platform resource into tenant resource, not vice versa
      // This ensures tenant_id takes precedence
      final combinedResource = platformResource.merge(tenantIdResource);

      // Set as default resource
      OTel.defaultResource = combinedResource;

      // 2. Create a batch processor
      final spanProcessor = BatchSpanProcessor(
        exporter,
        const BatchSpanProcessorConfig(
          maxQueueSize: 2048,
          scheduleDelay: Duration(seconds: 1),
          maxExportBatchSize: 512,
        ),
      );

      // 3. Create and configure TracerProvider with our resource
      final tracerProvider = OTel.tracerProvider();
      // Ensure the TracerProvider uses our updated resource
      tracerProvider.resource = combinedResource;
      tracerProvider.addSpanProcessor(spanProcessor);

      // 4. Get a tracer and create some spans
      final tracer = tracerProvider.getTracer(
        'tenant-id-test',
        version: '1.0.0',
      );

      // Create a span
      final span = tracer.startSpan(
        'test-operation',
        attributes: OTel.attributesFromMap({
          'test.key': 'test-value',
        }),
      );
      span.end();

      // Force flush to ensure spans are exported
      await spanProcessor.forceFlush();

      // Give collector time to process
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Wait for spans to appear
      await collector.waitForSpans(1, timeout: const Duration(seconds: 10));

      // Verify the tenant_id is included in resource attributes
      final spans = await collector.getSpans();
      expect(spans, isNotEmpty,
          reason: 'At least one span should have been exported');

      // Print all resource attributes for debugging
      print(
          'Resource attributes: ${json.encode(spans[0]['resourceAttributes'])}');

      // Verify tenant_id is present and has correct value
      expect(
          spans[0]['resourceAttributes'], containsPair('tenant_id', tenantId),
          reason: 'tenant_id should be present in resource attributes');

      // Verify service.name is explicitly present
      expect(spans[0]['resourceAttributes'],
          containsPair('service.name', 'test-service'),
          reason:
              'service.name should be present in resource attributes with correct value');

      // Shutdown
      await tracerProvider.shutdown();
    });

    test('tenant_id merges correctly with existing resource', () async {
      // Create a resource with service info
      final serviceResource = OTel.resource(OTel.attributesFromMap({
        'service.name': 'test-service',
        'service.version': '1.0.0',
      }));

      // Create tenant resource
      final tenantResource = OTel.resource(OTel.attributesFromMap({
        'tenant_id': '987654321',
      }));

      // Get platform resources
      final resourceDetector = PlatformResourceDetector.create();
      final platformResource = await resourceDetector.detect();

      // Merge resources - platform first, then service, then tenant_id
      // The order is critical: tenant_id must be merged last to take precedence
      final mergedResource =
          platformResource.merge(serviceResource).merge(tenantResource);
      OTel.defaultResource = mergedResource;

      // Create exporter and processor
      final spanProcessor = BatchSpanProcessor(exporter);
      final tracerProvider = OTel.tracerProvider();
      // Ensure the TracerProvider uses our updated resource
      tracerProvider.resource = mergedResource;
      tracerProvider.addSpanProcessor(spanProcessor);

      // Create and export a span
      final tracer = tracerProvider.getTracer('merge-test');
      final span = tracer.startSpan('merge-test-span');
      span.end();

      await spanProcessor.forceFlush();
      await collector.waitForSpans(1);

      // Verify both attributes are present
      final spans = await collector.getSpans();
      expect(spans[0]['resourceAttributes'],
          containsPair('service.name', 'test-service'));
      expect(spans[0]['resourceAttributes'],
          containsPair('tenant_id', '987654321'));

      await tracerProvider.shutdown();
    });

    test('tenant_id is overridden when merged with higher priority resource',
        () async {
      // First set a default resource with tenant_id
      final originalTenantResource = OTel.resource(OTel.attributesFromMap({
        'tenant_id': 'original-tenant',
      }));

      // Get platform resource
      final resourceDetector = PlatformResourceDetector.create();
      final platformResource = await resourceDetector.detect();

      // Merge platform and original tenant
      OTel.defaultResource = platformResource.merge(originalTenantResource);

      // Then create a new resource with a different tenant_id
      final newResource = OTel.resource(OTel.attributesFromMap({
        'tenant_id': 'override-tenant',
      }));

      // Override the default resource
      OTel.defaultResource = OTel.defaultResource!.merge(newResource);

      // Create exporter and processor
      final spanProcessor = BatchSpanProcessor(exporter);
      final tracerProvider = OTel.tracerProvider();
      // Ensure the TracerProvider uses our updated resource
      tracerProvider.resource = OTel.defaultResource!;
      tracerProvider.addSpanProcessor(spanProcessor);

      // Create and export a span
      final tracer = tracerProvider.getTracer('override-test');
      final span = tracer.startSpan('override-test-span');
      span.end();

      await spanProcessor.forceFlush();
      await collector.waitForSpans(1);

      // Verify the overridden tenant_id is used
      final spans = await collector.getSpans();
      expect(spans[0]['resourceAttributes'],
          containsPair('tenant_id', 'override-tenant'));
      expect(spans[0]['resourceAttributes'],
          isNot(containsPair('tenant_id', 'original-tenant')));

      await tracerProvider.shutdown();
    });

    test('tenant_id follows example pattern exactly', () async {
      // This test follows the exact pattern used in the example file

      // Reset OTel state to start fresh
      await OTel.reset();

      // Initialize OTel first with the endpoint and service name
      const serviceName = 'example-service';
      await OTel.initialize(
        endpoint: 'http://localhost:${collector.port}',
        serviceName: serviceName,
        detectPlatformResources:
            false, // Don't auto-detect platform resources yet
      );

      // Configure the exporter to use the same endpoint
      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'http://localhost:${collector.port}',
          insecure: true,
        ),
      );

      // Configure resource detectors exactly like the example
      final resourceDetector = PlatformResourceDetector.create();

      // Create service resource first
      final serviceResource = OTel.resource(OTel.attributesFromMap({
        'service.name': serviceName,
      }));

      // Create tenant resource
      final Resource tenantIdResource = OTel.resource(OTel.attributesFromMap({
        'tenant_id': '123456789',
      }));

      // Detect platform resources
      final platformResource = await resourceDetector.detect();

      // Merge resources - careful with order!
      // First platform and service resource are merged
      final mergedBaseResource = platformResource.merge(serviceResource);
      // Then tenant_id resource is merged last to ensure it takes precedence
      OTel.defaultResource = mergedBaseResource.merge(tenantIdResource);

      // Print debug for resource attributes
      if (OTel.defaultResource != null) {
        print('Default resource attributes for example pattern:');
        OTel.defaultResource!.attributes.toList().forEach((attr) {
          print('  ${attr.key}: ${attr.value}');
        });
      }

      // Create a batch processor that exports spans
      final spanProcessor = BatchSpanProcessor(
        exporter,
        const BatchSpanProcessorConfig(
          maxQueueSize: 2048,
          scheduleDelay: Duration(seconds: 1),
          maxExportBatchSize: 512,
        ),
      );

      // Create and configure TracerProvider
      final tracerProvider = OTel.tracerProvider();
      // Ensure the TracerProvider uses our updated resource
      tracerProvider.resource = OTel.defaultResource!;
      tracerProvider.addSpanProcessor(spanProcessor);

      // Get a tracer
      final tracer = tracerProvider.getTracer(
        'example-tracer',
        version: '1.0.0',
      );

      // Create a span
      final span = tracer.startSpan(
        'example-operation',
        attributes: OTel.attributesFromMap({
          'example.key': 'example-value',
        }),
      );
      span.end();

      // Force flush before shutdown
      await spanProcessor.forceFlush();

      // Wait for spans
      await collector.waitForSpans(1, timeout: const Duration(seconds: 10));

      // Verify both service.name and tenant_id are present
      final spans = await collector.getSpans();
      print(
          'Resource attributes for example pattern: ${json.encode(spans[0]["resourceAttributes"])}');

      // The key verification: tenant_id must be present
      expect(spans[0]['resourceAttributes'],
          containsPair('tenant_id', '123456789'),
          reason: 'tenant_id should be present in resource attributes');

      // service.name should come from OTel.initialize
      expect(spans[0]['resourceAttributes'],
          containsPair('service.name', 'example-service'),
          reason: 'service.name should be present from OTel.initialize');

      // Wait for any pending exports
      await Future<void>.delayed(const Duration(seconds: 1));

      // Shutdown
      await tracerProvider.shutdown();
    });
  }, skip: true);
}
