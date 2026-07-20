// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

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
      // Spec "Exporter Selection": OTEL_METRICS_EXPORTER, default otlp; the
      // comma-separated list form is supported. Known: otlp, console, none.
      final requested = OTelEnv.getExporters(signal: 'metrics') ?? ['otlp'];
      if (requested.contains('none')) {
        if (requested.length > 1 && OTelLog.isWarn()) {
          OTelLog.warn("OTEL_METRICS_EXPORTER contains 'none' alongside "
              'other values; installing no reader.');
        } else if (OTelLog.isDebug()) {
          OTelLog.debug(
              'MetricsConfiguration: OTEL_METRICS_EXPORTER=none, skipping reader');
        }
        return meterProvider;
      }
      final exporters = <MetricExporter>[];
      for (final name in requested) {
        switch (name) {
          case 'otlp':
          case 'console':
            final created = _createExporter(name, endpoint, secure);
            if (created != null) {
              exporters.add(created);
            }
          case 'prometheus':
            // Recognized spec value, but not auto-wirable yet: the SDK has
            // no scrape server, and an env-created PrometheusExporter would
            // be unreachable by the app — a silent no-op. Honest support
            // arrives with the scrape server (#82). Programmatic use of
            // PrometheusExporter (app serves prometheusData) works today.
            if (OTelLog.isWarn()) {
              OTelLog.warn("OTEL_METRICS_EXPORTER value 'prometheus' is not "
                  'supported yet (no scrape server; see issue #82). '
                  'Construct PrometheusExporter programmatically and serve '
                  'prometheusData, or route OTLP through the collector.');
            }
          case 'logging':
            if (OTelLog.isWarn()) {
              OTelLog.warn("OTEL_METRICS_EXPORTER value 'logging' is "
                  "deprecated in the spec and not supported; use 'console'.");
            }
          default:
            if (OTelLog.isWarn()) {
              OTelLog.warn("OTEL_METRICS_EXPORTER value '$name' is not "
                  'supported; ignoring. Supported: otlp, console, none.');
            }
        }
      }
      if (exporters.isEmpty) {
        if (OTelLog.isWarn()) {
          OTelLog.warn('OTEL_METRICS_EXPORTER produced no usable exporter; '
              'falling back to the default otlp exporter.');
        }
        exporters.add(_createExporter('otlp', endpoint, secure)!);
      }
      metricExporter = exporters.length == 1
          ? exporters.single
          : CompositeMetricExporter(exporters);
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
    // Parity with logs_config: honor OTEL_EXPORTER_OTLP_METRICS_INSECURE
    // (previously parsed and dropped) and the endpoint scheme per the
    // OTLP spec, falling back to the resolved global setting.
    final effectiveSecure = OTelEnv.resolveOtlpSecure(
      envInsecure: otlpConfig['insecure'] as bool?,
      endpoint: endpoint,
      fallback: secure,
    );
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
          insecure: !effectiveSecure,
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
