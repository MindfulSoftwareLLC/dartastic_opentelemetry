// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import '../../otel.dart';
import '../../resource/resource.dart';
import '../meter_provider.dart';
import '../metric_exporter.dart';
import '../metric_reader.dart';
import 'composite_metric_exporter.dart';
import 'otlp/otlp_grpc_metric_exporter.dart';
import 'otlp/otlp_grpc_metric_exporter_config.dart';

/// Configuration for metrics exporters and readers.
class MetricsConfiguration {
  /// Configures a MeterProvider with given settings.
  ///
  /// This configures everything needed for metrics pipeline:
  /// - An exporter (defaults to OtlpGrpcMetricExporter if none provided)
  /// - A reader (defaults to PeriodicExportingMetricReader if none provided)
  /// - Sets up resources on the MeterProvider
  static MeterProvider configureMeterProvider({
    String endpoint = 'http://localhost:4317',
    bool secure = false,
    MetricExporter? metricExporter,
    MetricReader? metricReader,
    Resource? resource,
  }) {
    // If no exporter is provided, create a default one
    metricExporter ??= _createDefaultExporter(endpoint, secure);

    // If no reader is provided, create a periodic exporting metric reader
    metricReader ??= PeriodicExportingMetricReader(
      metricExporter,
      interval: const Duration(seconds: 15),
    );

    // Get meter provider
    final meterProvider = OTel.meterProvider();

    // Set resource if provided
    if (resource != null) {
      meterProvider.resource = resource;
    }

    // Add the metric reader
    meterProvider.addMetricReader(metricReader);

    return meterProvider;
  }

  /// Creates the default metric exporter.
  static MetricExporter _createDefaultExporter(String endpoint, bool secure) {
    // Configure the OTLP gRPC exporter
    final otlpExporter = OtlpGrpcMetricExporter(
      OtlpGrpcMetricExporterConfig(
        endpoint: endpoint,
        insecure: !secure,
        timeoutMillis: 10000,
      ),
    );

    // Use a composite exporter for both OTLP and Console output
    return CompositeMetricExporter([
      otlpExporter,
      ConsoleMetricExporter(),
    ]);
  }
}
