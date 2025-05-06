// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() async {
  // Initialize OTel first with the endpoint
  // String endpoint = 'https://otel-dev.dartastic.io:443';
  // var secure = true;
  final endpoint = 'http://ec2-3-139-70-11.us-east-2.compute.amazonaws.com:4317';
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
      DeploymentResource.deploymentEnvironmentName.key: 'dev',//https://opentelemetry.io/docs/specs/semconv/resource/deployment-environment/
    }.toAttributes()
  );

  // Get the default tracer
  final tracer = OTel.tracer();

  //Add attributes
  // Always consult the OTel Semantic Conventions to find an existing
  // convention name for an attribute:
  // https://opentelemetry.io/docs/specs/semconv/general/attributes/
  tracer.attributes = OTel.attributesFromMap({
    SourceCodeResource.codeFunctionName.key: 'main'
  });

  // Create a new root span
  final rootSpan = tracer.startSpan(
    'root-operation-dartastic',
    attributes: OTel.attributesFromMap({
      'example-dartastic.key': 'example-value-dartastic',
    }),
  );

  try {
    // Add an event to match Python example
    rootSpan.addEventNow('Event within span-dartastic');

    print('Dartastic Trace with a span sent to OpenTelemetry.');

    // Simulate some work
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Create a child span
    final childSpan = tracer.startSpan(
      'child-operation-dartastic',
      parentSpan: rootSpan,
    );

    try {
      print('Doing some more work...');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      childSpan.recordException(e);
      childSpan.setStatus(SpanStatusCode.Error);
    } finally {
      childSpan.end();
    }
  } catch (e) {
    rootSpan.recordException(e);
    rootSpan.setStatus(SpanStatusCode.Error);
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
