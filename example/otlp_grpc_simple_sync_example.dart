// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/otlp_grpc_span_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/otlp_grpc_span_exporter_config.dart';
import 'package:dartastic_opentelemetry/src/trace/export/simple_span_processor.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

void main() async {
  // Initialize with automatic resource detection

  // Configure the OTLP exporter
  final endpoint =
      'http://ec2-3-139-70-11.us-east-2.compute.amazonaws.com:4317';
  final exporter = OtlpGrpcSpanExporter(
    OtlpGrpcExporterConfig(
      endpoint: endpoint,
      insecure: true, // Match Python's insecure=True
    ),
  );

  // Create a span processor that exports spans
  // Create a batch processor that exports spans
  final spanProcessor = SimpleSpanProcessor(exporter);

  await OTel.initialize(
    serviceName: 'example-service',
    endpoint: 'http://localhost:4317',
    spanProcessor: spanProcessor,
  );

  // Configure provider with detected resource
  final tracerProvider = OTel.tracerProvider();

  final tracer = tracerProvider.getTracer('example-sync-tracer');

  // Create and end a simple span
  final span = tracer.startSpan('sync-operation',
      attributes: OTel.attributesFromMap({'example.sync': true}))
    ..end();

  try {
    // Add an event to match Python example
    span.addEventNow('Event within span.');

    print('Trace with a span sent to OpenTelemetry.');

    // Simulate some work
    await Future<void>.delayed(const Duration(milliseconds: 100));
  } catch (e) {
    // Record any errors
    span.recordException(e as Exception);
    span.setStatus(SpanStatusCode.Error);
  } finally {
    // End the span
    span.end();
  }

  // Wait a bit to ensure export completes
  await Future<void>.delayed(const Duration(seconds: 1));

  // Shutdown
  await tracerProvider.shutdown();
}
