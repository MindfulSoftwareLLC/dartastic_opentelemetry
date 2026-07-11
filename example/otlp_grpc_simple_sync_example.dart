// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// App-specific attribute keys as a typed enum. Prefer enums over raw
/// strings; for any attribute that exists in the OTel semantic
/// conventions, use the corresponding API enum instead.
enum ExampleAttribute implements OTelSemantic {
  isSync('example.sync');

  @override
  final String key;

  @override
  String toString() => key;

  const ExampleAttribute(this.key);
}

void main() async {
  // Configure an OTLP/gRPC exporter pointed at your collector.
  final exporter = OtlpGrpcSpanExporter(
    OtlpGrpcExporterConfig(
      endpoint: 'http://my-otel-endpoint:4317',
      insecure: true,
    ),
  );

  // SimpleSpanProcessor exports each span synchronously as it ends.
  // Use BatchSpanProcessor in production for better throughput.
  final spanProcessor = SimpleSpanProcessor(exporter);

  await OTel.initialize(
    serviceName: 'example-service',
    spanProcessor: spanProcessor,
  );

  final tracer = OTel.tracerProvider().getTracer('example-sync-tracer');

  // Create a span and run work inside try/catch/finally so the span is
  // always ended and any thrown exception is recorded with
  // SpanStatusCode.Error per the OTel spec.
  final span = tracer.startSpan(
    'sync-operation',
    attributes: OTel.attributesFromSemanticMap({ExampleAttribute.isSync: true}),
  );
  try {
    span.addEventNow('Event within span.');
    print('Trace with a span sent to OpenTelemetry.');

    // Simulate some work.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    span.recordException(e, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }

  // Shutdown flushes any pending exports.
  await OTel.shutdown();
}
