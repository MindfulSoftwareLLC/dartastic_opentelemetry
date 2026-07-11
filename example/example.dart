// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

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
/// a convention exists, use the corresponding enum (e.g. User,
/// Http) instead of inventing your own.
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
    // Default endpoint is http://localhost:4318 (OTLP/HTTP per spec).
    // Override via OTEL_EXPORTER_OTLP_ENDPOINT env var, or pass `endpoint:`
    // explicitly. For gRPC, also set OTEL_EXPORTER_OTLP_PROTOCOL=grpc and
    // point at port 4317.
  );

  // Get the default tracer
  final tracer = OTel.tracer();

  // Create a parent span for the main operation. Prefer enum keys over
  // raw strings — User.userId is the OTel-spec key, ExampleSemantics
  // is our app-specific enum defined above.
  final parentSpan = tracer.startSpan(
    'main-operation',
    kind: SpanKind.server,
    attributes: OTel.attributesFromSemanticMap({
      User.userId: 'user-123',
      ExampleSemantics.requestType: 'example',
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
        OTel.attributesFromSemanticMap({ExampleSemantics.itemsProcessed: 42}),
      ),
    );
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
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
    attributes: OTel.attributesFromSemanticMap({
      Database.dbSystem: 'postgresql',
      Database.dbOperation: 'SELECT',
      Database.dbName: 'users',
    }),
  );

  try {
    // Simulate database query.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
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
    attributes: OTel.attributesFromSemanticMap({
      Http.requestMethod: 'GET',
      Url.urlFull: 'https://api.example.com/data',
      Url.urlPath: '/data',
    }),
  );

  try {
    // Simulate HTTP request.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Add response attributes.
    span.addAttributes(
      OTel.attributesFromSemanticMap({
        Http.responseStatusCode: 200,
        Http.responseBodySize: 1024,
      }),
    );
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    span.recordException(e, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
