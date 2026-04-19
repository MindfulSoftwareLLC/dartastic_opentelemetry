// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// Regression tests for https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/29
///
/// The default OTLP protocol is http/protobuf, so [OTel.defaultEndpoint] must
/// point at the OTLP/HTTP port (4318), not the OTLP/gRPC port (4317). When no
/// endpoint is supplied to [OTel.initialize], the resulting exporter must
/// target 4318 directly without any port-swap workaround.
void main() {
  group('OTel.defaultEndpoint (issue #29)', () {
    test('targets the OTLP/HTTP port (4318)', () {
      expect(OTel.defaultEndpoint, equals('http://localhost:4318'));
    });

    test('default trace exporter targets port 4318 when no endpoint is supplied',
        () async {
      await OTel.initialize(serviceName: 'default-endpoint-test');
      try {
        final processors = OTel.tracerProvider().spanProcessors;
        expect(processors, isNotEmpty,
            reason: 'OTel.initialize should add a default span processor');

        final batch = processors.whereType<BatchSpanProcessor>().firstOrNull;
        expect(batch, isNotNull,
            reason:
                'Expected a BatchSpanProcessor; got ${processors.map((p) => p.runtimeType).toList()}');

        final exporter = batch!.exporter;
        expect(exporter, isA<OtlpHttpSpanExporter>(),
            reason:
                'Default protocol is http/protobuf, so the default exporter must be HTTP, not gRPC');
      } finally {
        await OTel.reset();
      }
    });

    test('default metric exporter targets port 4318 over HTTP when no endpoint is supplied',
        () async {
      await OTel.initialize(serviceName: 'default-endpoint-test-metrics');
      try {
        final readers = OTel.meterProvider().metricReaders;
        expect(readers, isNotEmpty,
            reason: 'OTel.initialize should add a default metric reader');

        final periodic =
            readers.whereType<PeriodicExportingMetricReader>().firstOrNull;
        expect(periodic, isNotNull,
            reason:
                'Expected a PeriodicExportingMetricReader; got ${readers.map((r) => r.runtimeType).toList()}');

        final exporter = periodic!.exporter;
        // Drill through composite to find the OTLP exporter.
        final otlp = exporter is CompositeMetricExporter
            ? exporter.exporters.firstWhere(
                (e) =>
                    e is OtlpHttpMetricExporter || e is OtlpGrpcMetricExporter,
                orElse: () => throw StateError(
                    'No OTLP exporter found in composite: ${exporter.exporters.map((e) => e.runtimeType).toList()}'),
              )
            : exporter;

        expect(otlp, isA<OtlpHttpMetricExporter>(),
            reason:
                'Default protocol is http/protobuf, so the default metric exporter must be HTTP (port 4318), not gRPC (port 4317)');
      } finally {
        await OTel.reset();
      }
    });
  });
}
