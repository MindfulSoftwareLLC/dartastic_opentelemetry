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
import 'otlp/http/otlp_http_metric_exporter.dart';
import 'otlp/http/otlp_http_metric_exporter_config.dart';
import 'otlp/otlp_grpc_metric_exporter.dart';
import 'otlp/otlp_grpc_metric_exporter_config.dart';

/// Configuration for metrics exporters and readers.
class MetricsConfiguration {
  /// Configures a MeterProvider with given settings.
  ///
  /// This configures everything needed for metrics pipeline:
  /// - An exporter selected per the OTel spec:
  ///   `OTEL_METRICS_EXPORTER=otlp` (default) → OtlpHttp/Grpc exporter,
  ///   `=console` → ConsoleMetricExporter, `=none` → no reader is added.
  /// - A reader (defaults to PeriodicExportingMetricReader if none provided)
  /// - Sets up resources on the MeterProvider
  ///
  /// An explicit [metricExporter] or [metricReader] always wins over the
  /// env-var selection so programmatic configuration is unsurprising.
  static MeterProvider configureMeterProvider({
    String endpoint = 'http://localhost:4318',
    bool secure = false,
    MetricExporter? metricExporter,
    MetricReader? metricReader,
    Resource? resource,
  }) {
    final meterProvider = OTel.meterProvider();
    if (resource != null) {
      meterProvider.resource = resource;
    }

    // Honor OTEL_METRICS_EXPORTER, but only when the caller did not pass an
    // explicit exporter/reader — explicit args are an unambiguous opt-in and
    // should not be silently dropped by env config.
    if (metricExporter == null && metricReader == null) {
      final exporterType =
          OTelEnv.getExporter(signal: 'metrics')?.toLowerCase() ?? 'otlp';
      if (exporterType == 'none') {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'MetricsConfiguration: OTEL_METRICS_EXPORTER=none, skipping reader');
        }
        return meterProvider;
      }
      metricExporter = _createExporter(exporterType, endpoint, secure);
      if (metricExporter == null) {
        return meterProvider;
      }
    }

    metricExporter ??= _createExporter('otlp', endpoint, secure);
    if (metricExporter == null) {
      return meterProvider;
    }

    metricReader ??= PeriodicExportingMetricReader(
      metricExporter,
      interval: const Duration(seconds: 15),
    );

    meterProvider.addMetricReader(metricReader);
    return meterProvider;
  }

  /// Creates a metric exporter for [exporterType] (`otlp` or `console`).
  /// Returns null for unknown values.
  static MetricExporter? _createExporter(
    String exporterType,
    String endpoint,
    bool secure,
  ) {
    if (exporterType == 'console') {
      if (OTelLog.isDebug()) {
        OTelLog.debug('MetricsConfiguration: Creating ConsoleMetricExporter');
      }
      return ConsoleMetricExporter();
    }
    if (exporterType != 'otlp') {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'MetricsConfiguration: Unknown OTEL_METRICS_EXPORTER value '
            '"$exporterType", falling back to otlp');
      }
    }

    final otlpConfig = OTelEnv.getOtlpConfig(signal: 'metrics');
    final protocol = otlpConfig['protocol'] as String? ?? 'http/protobuf';
    final headers = otlpConfig['headers'] as Map<String, String>? ?? const {};
    final timeout =
        otlpConfig['timeout'] as Duration? ?? const Duration(seconds: 10);
    final compression = otlpConfig['compression'] == 'gzip';
    final certificate = otlpConfig['certificate'] as String?;
    final clientKey = otlpConfig['clientKey'] as String?;
    final clientCertificate = otlpConfig['clientCertificate'] as String?;

    if (protocol == 'grpc') {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'MetricsConfiguration: Creating OtlpGrpcMetricExporter for $endpoint');
      }
      return OtlpGrpcMetricExporter(
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
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'MetricsConfiguration: Creating OtlpHttpMetricExporter for $endpoint');
    }
    return OtlpHttpMetricExporter(
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
}
