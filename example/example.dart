// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Example demonstrating basic usage of Dartastic OpenTelemetry SDK.
///
/// This example shows how to:
/// - Initialize the SDK with basic configuration
/// - Create and use a tracer
/// - Create spans with attributes and events using typed enum keys
/// - Properly shut down the SDK
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Define your own typed enum for application-specific attribute keys that
/// aren't covered by the OTel semantic conventions. This keeps attribute
/// keys typo-free and discoverable. Always check the OTel semantic
/// conventions first (https://opentelemetry.io/docs/specs/semconv/) — if
/// a convention exists, use the corresponding enum (e.g. UserSemantics,
/// HttpResource) instead of inventing your own.
enum ExampleSemantics implements OTelSemantic {
  requestType('request.type'),
  itemsProcessed('items.processed');

  @override
  final String key;

  @override
  String toString() => key;

  const ExampleSemantics(this.key);
}

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

  // Create a parent span for the main operation. Prefer enum keys over
  // raw strings — UserSemantics.userId is the OTel-spec key, ExampleSemantics
  // is our app-specific enum defined above.
  final parentSpan = tracer.startSpan(
    'main-operation',
    kind: SpanKind.server,
    attributes: OTel.attributesFromMap({
      UserSemantics.userId.key: 'user-123',
      ExampleSemantics.requestType.key: 'example',
    }),
  );

  try {
    // Simulate some work
    await performDatabaseQuery(tracer, parentSpan);
    await callExternalService(tracer, parentSpan);

    // Add an event to the span. Event names are user-defined (no semconv).
    parentSpan.addEvent(
      OTel.spanEventNow(
        'operation.completed',
        OTel.attributesFromMap({ExampleSemantics.itemsProcessed.key: 42}),
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
    // Simulate database query.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    span.setStatus(SpanStatusCode.Ok);
  } catch (e, stackTrace) {
    span.recordException(e, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
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
      UrlResource.urlFull.key: 'https://api.example.com/data',
      UrlResource.urlPath.key: '/data',
    }),
  );

  try {
    // Simulate HTTP request.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Add response attributes.
    span.addAttributes(
      OTel.attributesFromMap({
        HttpResource.responseStatusCode.key: 200,
        HttpResource.responseBodySize.key: 1024,
      }),
    );

    span.setStatus(SpanStatusCode.Ok);
  } catch (e, stackTrace) {
    span.recordException(e, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
