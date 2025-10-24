// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'env_constants.dart';
import 'environment_service.dart';

/// Web implementation of the environment service.
///
/// This implementation is used on Flutter web and Dart web platforms where
/// io.Platform is not available.
///
/// Environment variable lookup priority:
/// 1. String.fromEnvironment (--dart-define values)
///
/// Note: System environment variables (from the browser or server) are NOT
/// accessible on web platforms. Only compile-time constants defined via
/// --dart-define are available.
///
/// Example usage:
/// ```bash
/// flutter run -d chrome \
///   --dart-define=OTEL_SERVICE_NAME=my-web-app \
///   --dart-define=OTEL_EXPORTER_OTLP_ENDPOINT=https://collector:4318
/// ```
class EnvironmentService implements EnvironmentServiceInterface {
  static final EnvironmentService _instance = EnvironmentService._();

  /// The singleton instance of the EnvironmentService.
  static EnvironmentService get instance => _instance;

  EnvironmentService._();

  /// Gets the value of an environment variable.
  ///
  /// Returns the value from String.fromEnvironment if defined via --dart-define,
  /// otherwise returns null.
  ///
  /// Note: On web platforms, only --dart-define values are available. System
  /// environment variables cannot be accessed.
  ///
  /// @param key The name of the environment variable to retrieve
  /// @return The value of the environment variable, or null if not found
  @override
  String? getValue(String key) {
    // String.fromEnvironment (--dart-define values)
    // Only check if this is a known environment variable
    String? value;
    if (supportedEnvVars.contains(key)) {
      final fromEnvironment = _getFromEnvironment(key);
      if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
        value = fromEnvironment;
      }
    }

    // Handle comma-separated values for --define compatibility
    // The --define flag cannot handle commas in values, so we use semicolons
    // as a delimiter for these specific variables and convert them back
    if (value != null) {
      switch (key) {
        case otelResourceAttributes:
        case otelPropagators:
        case otelExporterOtlpHeaders:
        case otelExporterOtlpTracesHeaders:
        case otelExporterOtlpMetricsHeaders:
        case otelExporterOtlpLogsHeaders:
          value = value.replaceAll(';', ',');
          break;
      }
    }

    return value;
  }

  /// Gets a value from String.fromEnvironment.
  ///
  /// This method encapsulates all String.fromEnvironment calls to make the
  /// code more maintainable. Since String.fromEnvironment requires a
  /// compile-time constant, we must explicitly check each possible variable.
  ///
  /// @param key The environment variable name
  /// @return The value from String.fromEnvironment, or null if empty
  String? _getFromEnvironment(String key) {
    // We use a switch statement because String.fromEnvironment requires
    // compile-time constants. Each case must be explicitly listed.
    switch (key) {
      // General SDK Configuration
      case otelSdkDisabled:
        return const String.fromEnvironment(otelSdkDisabled);
      case otelResourceAttributes:
        return const String.fromEnvironment(otelResourceAttributes);
      case otelServiceName:
        return const String.fromEnvironment(otelServiceName);
      case otelLogLevel:
        return const String.fromEnvironment(otelLogLevel);
      case otelPropagators:
        return const String.fromEnvironment(otelPropagators);
      case otelTracesSampler:
        return const String.fromEnvironment(otelTracesSampler);
      case otelTracesSamplerArg:
        return const String.fromEnvironment(otelTracesSamplerArg);

      // Logging Configuration
      case otelLogMetrics:
        return const String.fromEnvironment(otelLogMetrics);
      case otelLogSpans:
        return const String.fromEnvironment(otelLogSpans);
      case otelLogExport:
        return const String.fromEnvironment(otelLogExport);

      // General OTLP Configuration
      case otelExporterOtlpEndpoint:
        return const String.fromEnvironment(otelExporterOtlpEndpoint);
      case otelExporterOtlpProtocol:
        return const String.fromEnvironment(otelExporterOtlpProtocol);
      case otelExporterOtlpHeaders:
        return const String.fromEnvironment(otelExporterOtlpHeaders);
      case otelExporterOtlpInsecure:
        return const String.fromEnvironment(otelExporterOtlpInsecure);
      case otelExporterOtlpTimeout:
        return const String.fromEnvironment(otelExporterOtlpTimeout);
      case otelExporterOtlpCompression:
        return const String.fromEnvironment(otelExporterOtlpCompression);
      case otelExporterOtlpCertificate:
        return const String.fromEnvironment(otelExporterOtlpCertificate);
      case otelExporterOtlpClientKey:
        return const String.fromEnvironment(otelExporterOtlpClientKey);
      case otelExporterOtlpClientCertificate:
        return const String.fromEnvironment(otelExporterOtlpClientCertificate);

      // Traces-specific Configuration
      case otelTracesExporter:
        return const String.fromEnvironment(otelTracesExporter);
      case otelExporterOtlpTracesEndpoint:
        return const String.fromEnvironment(otelExporterOtlpTracesEndpoint);
      case otelExporterOtlpTracesProtocol:
        return const String.fromEnvironment(otelExporterOtlpTracesProtocol);
      case otelExporterOtlpTracesHeaders:
        return const String.fromEnvironment(otelExporterOtlpTracesHeaders);
      case otelExporterOtlpTracesInsecure:
        return const String.fromEnvironment(otelExporterOtlpTracesInsecure);
      case otelExporterOtlpTracesTimeout:
        return const String.fromEnvironment(otelExporterOtlpTracesTimeout);
      case otelExporterOtlpTracesCompression:
        return const String.fromEnvironment(otelExporterOtlpTracesCompression);
      case otelExporterOtlpTracesCertificate:
        return const String.fromEnvironment(otelExporterOtlpTracesCertificate);
      case otelExporterOtlpTracesClientKey:
        return const String.fromEnvironment(otelExporterOtlpTracesClientKey);
      case otelExporterOtlpTracesClientCertificate:
        return const String.fromEnvironment(
            otelExporterOtlpTracesClientCertificate);

      // Metrics-specific Configuration
      case otelMetricsExporter:
        return const String.fromEnvironment(otelMetricsExporter);
      case otelExporterOtlpMetricsEndpoint:
        return const String.fromEnvironment(otelExporterOtlpMetricsEndpoint);
      case otelExporterOtlpMetricsProtocol:
        return const String.fromEnvironment(otelExporterOtlpMetricsProtocol);
      case otelExporterOtlpMetricsHeaders:
        return const String.fromEnvironment(otelExporterOtlpMetricsHeaders);
      case otelExporterOtlpMetricsInsecure:
        return const String.fromEnvironment(otelExporterOtlpMetricsInsecure);
      case otelExporterOtlpMetricsTimeout:
        return const String.fromEnvironment(otelExporterOtlpMetricsTimeout);
      case otelExporterOtlpMetricsCompression:
        return const String.fromEnvironment(otelExporterOtlpMetricsCompression);
      case otelExporterOtlpMetricsCertificate:
        return const String.fromEnvironment(otelExporterOtlpMetricsCertificate);
      case otelExporterOtlpMetricsClientKey:
        return const String.fromEnvironment(otelExporterOtlpMetricsClientKey);
      case otelExporterOtlpMetricsClientCertificate:
        return const String.fromEnvironment(
            otelExporterOtlpMetricsClientCertificate);

      // Logs-specific Configuration
      case otelLogsExporter:
        return const String.fromEnvironment(otelLogsExporter);
      case otelExporterOtlpLogsEndpoint:
        return const String.fromEnvironment(otelExporterOtlpLogsEndpoint);
      case otelExporterOtlpLogsProtocol:
        return const String.fromEnvironment(otelExporterOtlpLogsProtocol);
      case otelExporterOtlpLogsHeaders:
        return const String.fromEnvironment(otelExporterOtlpLogsHeaders);
      case otelExporterOtlpLogsInsecure:
        return const String.fromEnvironment(otelExporterOtlpLogsInsecure);
      case otelExporterOtlpLogsTimeout:
        return const String.fromEnvironment(otelExporterOtlpLogsTimeout);
      case otelExporterOtlpLogsCompression:
        return const String.fromEnvironment(otelExporterOtlpLogsCompression);
      case otelExporterOtlpLogsCertificate:
        return const String.fromEnvironment(otelExporterOtlpLogsCertificate);
      case otelExporterOtlpLogsClientKey:
        return const String.fromEnvironment(otelExporterOtlpLogsClientKey);
      case otelExporterOtlpLogsClientCertificate:
        return const String.fromEnvironment(
            otelExporterOtlpLogsClientCertificate);

      // Batch Span Processor
      case otelBspScheduleDelay:
        return const String.fromEnvironment(otelBspScheduleDelay);
      case otelBspExportTimeout:
        return const String.fromEnvironment(otelBspExportTimeout);
      case otelBspMaxQueueSize:
        return const String.fromEnvironment(otelBspMaxQueueSize);
      case otelBspMaxExportBatchSize:
        return const String.fromEnvironment(otelBspMaxExportBatchSize);

      // Batch LogRecord Processor
      case otelBlrpScheduleDelay:
        return const String.fromEnvironment(otelBlrpScheduleDelay);
      case otelBlrpExportTimeout:
        return const String.fromEnvironment(otelBlrpExportTimeout);
      case otelBlrpMaxQueueSize:
        return const String.fromEnvironment(otelBlrpMaxQueueSize);
      case otelBlrpMaxExportBatchSize:
        return const String.fromEnvironment(otelBlrpMaxExportBatchSize);

      // Attribute Limits
      case otelAttributeValueLengthLimit:
        return const String.fromEnvironment(otelAttributeValueLengthLimit);
      case otelAttributeCountLimit:
        return const String.fromEnvironment(otelAttributeCountLimit);

      // Span Limits
      case otelSpanAttributeValueLengthLimit:
        return const String.fromEnvironment(otelSpanAttributeValueLengthLimit);
      case otelSpanAttributeCountLimit:
        return const String.fromEnvironment(otelSpanAttributeCountLimit);
      case otelSpanEventCountLimit:
        return const String.fromEnvironment(otelSpanEventCountLimit);
      case otelSpanLinkCountLimit:
        return const String.fromEnvironment(otelSpanLinkCountLimit);
      case otelEventAttributeCountLimit:
        return const String.fromEnvironment(otelEventAttributeCountLimit);
      case otelLinkAttributeCountLimit:
        return const String.fromEnvironment(otelLinkAttributeCountLimit);

      // LogRecord Limits
      case otelLogrecordAttributeValueLengthLimit:
        return const String.fromEnvironment(
            otelLogrecordAttributeValueLengthLimit);
      case otelLogrecordAttributeCountLimit:
        return const String.fromEnvironment(otelLogrecordAttributeCountLimit);

      // Metrics SDK Configuration
      case otelMetricsExemplarFilter:
        return const String.fromEnvironment(otelMetricsExemplarFilter);
      case otelMetricExportInterval:
        return const String.fromEnvironment(otelMetricExportInterval);
      case otelMetricExportTimeout:
        return const String.fromEnvironment(otelMetricExportTimeout);

      // Zipkin Exporter
      case otelExporterZipkinEndpoint:
        return const String.fromEnvironment(otelExporterZipkinEndpoint);
      case otelExporterZipkinTimeout:
        return const String.fromEnvironment(otelExporterZipkinTimeout);

      // Prometheus Exporter
      case otelExporterPrometheusHost:
        return const String.fromEnvironment(otelExporterPrometheusHost);
      case otelExporterPrometheusPort:
        return const String.fromEnvironment(otelExporterPrometheusPort);

      // Deprecated but supported
      case otelExporterOtlpSpanInsecure:
        return const String.fromEnvironment(otelExporterOtlpSpanInsecure);
      case otelExporterOtlpMetricInsecure:
        return const String.fromEnvironment(otelExporterOtlpMetricInsecure);

      default:
        return null;
    }
  }
}
