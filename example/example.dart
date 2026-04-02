// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Example demonstrating basic usage of Dartastic OpenTelemetry SDK.
///
/// This example shows how to:
/// - Initialize the SDK with basic configuration
/// - Create and use a tracer
/// - Create spans with attributes and events
/// - Properly shut down the SDK
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

Future<void> main() async {
  // Initialize the OpenTelemetry SDK
  await OTel.initialize(
    serviceName: 'example-service',
    serviceVersion: '1.0.0',
    // Default endpoint is http://localhost:4317 for local OTLP collector
    // For production, set your collector endpoint:
    // endpoint: 'https://your-collector.example.com:4317',
  );

  // Get the default tracer
  final tracer = OTel.tracer();

  // Create a parent span for the main operation
  final parentSpan = tracer.startSpan(
    'main-operation',
    kind: SpanKind.server,
    attributes: OTel.attributesFromMap({
      'user.id': 'user-123',
      'request.type': 'example',
    }),
  );

  try {
    // Simulate some work
    await performDatabaseQuery(tracer, parentSpan);
    await callExternalService(tracer, parentSpan);

    // Add an event to the span
    parentSpan.addEvent(
      OTel.spanEventNow(
        'operation.completed',
        OTel.attributesFromMap({'items.processed': 42}),
      ),
    );

    // Set status to OK
    parentSpan.setStatus(SpanStatusCode.Ok);
  } catch (e, stackTrace) {
    // Record the exception on the span
    parentSpan.recordException(e, stackTrace: stackTrace);
    parentSpan.setStatus(SpanStatusCode.Error, e.toString());
  } finally {
    // Always end the span
    parentSpan.end();
  }

  // Shutdown the SDK to flush any remaining spans
  await OTel.shutdown();
}

/// Example of creating a child span for a database operation.
Future<void> performDatabaseQuery(Tracer tracer, Span parentSpan) async {
  final span = tracer.startSpan(
    'database.query',
    kind: SpanKind.client,
    // Link to parent span via context
    context: OTel.context(spanContext: parentSpan.spanContext),
    attributes: OTel.attributesFromMap({
      DatabaseResource.dbSystem.key: 'postgresql',
      DatabaseResource.dbOperation.key: 'SELECT',
      DatabaseResource.dbName.key: 'users',
    }),
  );

  try {
    // Simulate database query
    await Future<void>.delayed(const Duration(milliseconds: 50));
    span.setStatus(SpanStatusCode.Ok);
  } finally {
    span.end();
  }
}

/// Example of creating a child span for an external HTTP call.
Future<void> callExternalService(Tracer tracer, Span parentSpan) async {
  final span = tracer.startSpan(
    'http.request',
    kind: SpanKind.client,
    context: OTel.context(spanContext: parentSpan.spanContext),
    attributes: OTel.attributesFromMap({
      HttpResource.requestMethod.key: 'GET',
      // TODO: Replace with UrlResource.urlFull.key once added to the API
      // semantics (OTel renamed http.url → url.full).
      'url.full': 'https://api.example.com/data',
      'url.path': '/data',
    }),
  );

  try {
    // Simulate HTTP request
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Add response attributes
    span.addAttributes(
      OTel.attributesFromMap({
        HttpResource.responseStatusCode.key: 200,
        'http.response_content_length': 1024,
      }),
    );

    span.setStatus(SpanStatusCode.Ok);
  } finally {
    span.end();
  }
}
