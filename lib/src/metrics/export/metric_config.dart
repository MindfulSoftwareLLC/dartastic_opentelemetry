// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;

import '../../environment/otel_env.dart';
import '../../otel.dart';
import '../../resource/resource.dart';
import '../meter_provider.dart';
import '../metric_exporter.dart';
import '../metric_reader.dart';
import 'composite_metric_exporter.dart';
import 'otlp/http/otlp_http_metric_exporter.dart';
import 'otlp/http/otlp_http_metric_exporter_config.dart';
import 'otlp/otlp_grpc_metric_exporter.dart';
import 'otlp/otlp_grpc_metric_exporter_config.dart';

/// Configuration for metrics exporters and readers.
class MetricsConfiguration {
  /// Configures a MeterProvider with given settings.
  ///
  /// This configures everything needed for metrics pipeline:
  /// - An exporter (defaults to OtlpHttpMetricExporter using http/protobuf,
  ///   the OTel spec default; selects gRPC when OTEL_EXPORTER_OTLP_PROTOCOL
  ///   or OTEL_EXPORTER_OTLP_METRICS_PROTOCOL is set to `grpc`)
  /// - A reader (defaults to PeriodicExportingMetricReader if none provided)
  /// - Sets up resources on the MeterProvider
  static MeterProvider configureMeterProvider({
    String endpoint = 'http://localhost:4318',
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

  /// Creates the default metric exporter using the protocol indicated by
  /// the OTel environment variables (defaulting to http/protobuf per spec).
  static MetricExporter _createDefaultExporter(String endpoint, bool secure) {
    final otlpConfig = OTelEnv.getOtlpConfig(signal: 'metrics');
    final protocol = otlpConfig['protocol'] as String? ?? 'http/protobuf';
    final headers =
        otlpConfig['headers'] as Map<String, String>? ?? const {};
    final timeout = otlpConfig['timeout'] as Duration? ??
        const Duration(seconds: 10);
    final compression = otlpConfig['compression'] == 'gzip';
    final certificate = otlpConfig['certificate'] as String?;
    final clientKey = otlpConfig['clientKey'] as String?;
    final clientCertificate = otlpConfig['clientCertificate'] as String?;

    final MetricExporter otlpExporter;
    if (protocol == 'grpc') {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'MetricsConfiguration: Creating OtlpGrpcMetricExporter for $endpoint');
      }
      otlpExporter = OtlpGrpcMetricExporter(
        OtlpGrpcMetricExporterConfig(
          endpoint: endpoint,
          insecure: !secure,
          headers: headers,
          timeoutMillis: timeout.inMilliseconds,
          compression: compression,
          certificate: certificate,
          clientKey: clientKey,
          clientCertificate: clientCertificate,
        ),
      );
    } else {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'MetricsConfiguration: Creating OtlpHttpMetricExporter for $endpoint');
      }
      otlpExporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(
          endpoint: endpoint,
          headers: headers,
          timeout: timeout,
          compression: compression,
          certificate: certificate,
          clientKey: clientKey,
          clientCertificate: clientCertificate,
        ),
      );
    }

    // Use a composite exporter for both OTLP and Console output
    return CompositeMetricExporter([otlpExporter, ConsoleMetricExporter()]);
  }
}
