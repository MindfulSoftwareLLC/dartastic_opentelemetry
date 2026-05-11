// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// App-specific attribute keys as a typed enum. Prefer enums over raw
/// strings; for any attribute that exists in the OTel semantic
/// conventions, use the corresponding API enum instead.
enum ExampleAttribute implements OTelSemantic {
  exampleKey('example.key');

  @override
  final String key;

  @override
  String toString() => key;

  const ExampleAttribute(this.key);
}

void main() async {
  // Initialize OTel first with the endpoint
  // String endpoint = 'https://otel.dartastic.io:443';
  // var secure = true;
  final endpoint = 'http://my-otel-collector:4317';
  final secure = false;
  await OTel.initialize(
    secure: secure,
    endpoint: endpoint,
    serviceName: 'dartastic-examples',
    tracerName: 'otlp_grpc_example',
    tracerVersion: '1.0.0',
    tenantId: 'my-valued-customer',
    // Always consult the OTel Semantic Conventions to find an existing
    // convention name for an attribute:
    // https://opentelemetry.io/docs/specs/semconv/general/attributes/
    resourceAttributes: {
      Deployment.deploymentEnvironmentName.key:
          'dev', //https://opentelemetry.io/docs/specs/semconv/resource/deployment-environment/
    }.toAttributes(),
  );

  // Get the default tracer
  final tracer = OTel.tracer();

  //Add attributes
  // Always consult the OTel Semantic Conventions to find an existing
  // convention name for an attribute:
  // https://opentelemetry.io/docs/specs/semconv/general/attributes/
  tracer.attributes = OTel.attributesFromSemanticMap({
    SourceCode.codeFunctionName: 'main',
  });

  // Create a new root span. Prefer typed enum keys over raw strings.
  final rootSpan = tracer.startSpan(
    'root-operation-dartastic',
    attributes: OTel.attributesFromSemanticMap({
      ExampleAttribute.exampleKey: 'example-value-dartastic',
    }),
  );

  try {
    // Add an event to match Python example.
    rootSpan.addEventNow('Event within span-dartastic');

    print('Dartastic Trace with a span sent to OpenTelemetry.');

    // Simulate some work.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Create a child span.
    final childSpan = tracer.startSpan(
      'child-operation-dartastic',
      parentSpan: rootSpan,
    );

    try {
      print('Doing some more work...');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    } catch (e, stackTrace) {
      // The span has a status of SpanStatus.Ok on creation, set it to
      // Error when an error occurs in the span.
      childSpan.recordException(e, stackTrace: stackTrace);
      childSpan.setStatus(SpanStatusCode.Error, e.toString());
      rethrow;
    } finally {
      childSpan.end();
    }
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    rootSpan.recordException(e, stackTrace: stackTrace);
    rootSpan.setStatus(SpanStatusCode.Error, e.toString());
  } finally {
    rootSpan.end();
  }

  // Force flush before shutdown
  await OTel.tracerProvider().forceFlush();

  // Wait for any pending exports
  await Future<void>.delayed(const Duration(seconds: 1));

  // Shutdown - TODO - forceFlush inside?
  await OTel.tracerProvider().shutdown();
}
