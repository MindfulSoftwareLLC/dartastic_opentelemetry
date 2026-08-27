// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../../environment/otel_env.dart';
import '../../otel.dart';
import '../../resource/resource.dart';
import '../log_record_processor.dart';
import '../logger_provider.dart';
import 'batch_log_record_processor.dart';
import 'console_log_record_exporter.dart';
import 'log_record_exporter.dart';
import 'otlp/http/otlp_http_log_record_exporter.dart';
import 'otlp/http/otlp_http_log_record_exporter_config.dart';
import 'otlp/otlp_grpc_log_record_exporter.dart';
import 'otlp/otlp_grpc_log_record_exporter_config.dart';
import 'simple_log_record_processor.dart';

/// Configuration for logs exporters and processors.
///
/// This class provides methods to configure the LoggerProvider based on
/// environment variables and explicit configuration parameters.
class LogsConfiguration {
  /// Configures a LoggerProvider with the given settings.
  ///
  /// This configures everything needed for the logs pipeline:
  /// - An exporter (based on OTEL_LOGS_EXPORTER env var or defaults to OTLP)
  /// - A processor (BatchLogRecordProcessor with BLRP env var config)
  /// - Sets up resources on the LoggerProvider
  ///
  /// @param endpoint The endpoint URL for the exporter (null to use the
  ///   protocol-dependent default, issue #220)
  /// @param secure Whether to use TLS for gRPC connections
  /// @param logRecordExporter Optional custom exporter (overrides env var)
  /// @param logRecordProcessor Optional custom processor (overrides env var)
  /// @param resource Optional resource for the LoggerProvider
  /// @return The configured LoggerProvider
  static LoggerProvider configureLoggerProvider({
    String? endpoint,
    bool? secure,
    LogRecordExporter? logRecordExporter,
    LogRecordProcessor? logRecordProcessor,
    Resource? resource,
    OtlpEnvironmentValues? otlpConfig,
    List<String>? exporters,
    BlrpEnvironmentValues? blrpConfig,
  }) {
    otlpConfig ??= OTelEnv.getOtlpConfig(signal: 'logs');
    exporters ??= OTelEnv.getExporters(signal: 'logs') ?? ['otlp'];
    blrpConfig ??= OTelEnv.getBlrpConfig();

    // Get the logger provider
    final logProvider = OTel.loggerProvider();

    // Set resource if provided
    if (resource != null) {
      logProvider.resource = resource;
    }

    // If a custom processor is provided, use it directly
    if (logRecordProcessor != null) {
      logProvider.addLogRecordProcessor(logRecordProcessor);
      return logProvider;
    }

    // Explicitly provided exporter wins; otherwise read the env selection.
    if (logRecordExporter != null) {
      logProvider.addLogRecordProcessor(
          _createProcessor(logRecordExporter, blrpConfig));
      return logProvider;
    }

    // Multiple exporters install one processor per exporter.
    if (exporters.contains('none')) {
      if (exporters.length > 1 && OTelLog.isWarn()) {
        OTelLog.warn("OTEL_LOGS_EXPORTER contains 'none' alongside other "
            'values; installing no processor.');
      } else if (OTelLog.isDebug()) {
        OTelLog.debug(
            'LogsConfiguration: OTEL_LOGS_EXPORTER=none, no processor added');
      }
      return logProvider;
    }

    final createdExporters = <LogRecordExporter>[];
    for (final name in exporters) {
      if (name == 'logging') {
        if (OTelLog.isWarn()) {
          OTelLog.warn("OTEL_LOGS_EXPORTER value 'logging' is deprecated "
              "in the spec and not supported; use 'console'.");
        }
        continue;
      }
      final created = _createExporter(name, endpoint, secure, otlpConfig);
      if (created != null) {
        createdExporters.add(created);
      } else if (OTelLog.isWarn()) {
        OTelLog.warn("OTEL_LOGS_EXPORTER value '$name' is not supported; "
            'ignoring. Supported: otlp, console, none.');
      }
    }
    if (createdExporters.isEmpty) {
      if (OTelLog.isWarn()) {
        OTelLog.warn('OTEL_LOGS_EXPORTER produced no usable exporter; '
            'falling back to the default otlp exporter.');
      }
      final fallback = _createExporter('otlp', endpoint, secure, otlpConfig);
      if (fallback != null) {
        createdExporters.add(fallback);
      }
    }
    for (final exporter in createdExporters) {
      logProvider.addLogRecordProcessor(_createProcessor(exporter, blrpConfig));
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug('LogsConfiguration: Configured LoggerProvider with '
          '${createdExporters.length} exporter(s) from OTEL_LOGS_EXPORTER');
    }

    return logProvider;
  }

  /// Creates a log record exporter based on the exporter type.
  static LogRecordExporter? _createExporter(
    String exporterType,
    String? endpoint,
    bool? secure,
    OtlpEnvironmentValues otlpConfig,
  ) {
    final protocol = otlpConfig.protocol ?? 'http/protobuf';

    // Use env endpoint if available, otherwise use provided endpoint. The
    // default endpoint depends on the protocol (issue #220): OTLP/gRPC uses
    // port 4317, the HTTP protocols use port 4318.
    final effectiveEndpoint = otlpConfig.endpoint ??
        endpoint ??
        (protocol == 'grpc' ? OTel.defaultGrpcEndpoint : OTel.defaultEndpoint);
    final envInsecure = otlpConfig.insecure;
    final effectiveSecure = OTelEnv.resolveOtlpSecure(
      envInsecure: envInsecure,
      endpoint: effectiveEndpoint,
      explicitSecure: secure,
    );

    if (exporterType == 'console') {
      if (OTelLog.isDebug()) {
        OTelLog.debug('LogsConfiguration: Creating ConsoleLogRecordExporter');
      }
      return ConsoleLogRecordExporter();
    }

    if (exporterType == 'otlp') {
      if (protocol == 'grpc') {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'LogsConfiguration: Creating OtlpGrpcLogRecordExporter');
        }
        return OtlpGrpcLogRecordExporter(
          OtlpGrpcLogRecordExporterConfig(
            endpoint: effectiveEndpoint,
            insecure: !effectiveSecure,
            headers: otlpConfig.headers ?? {},
            timeout: otlpConfig.timeout ?? const Duration(seconds: 10),
            compression: otlpConfig.compression == 'gzip',
            certificate: otlpConfig.certificate,
            clientKey: otlpConfig.clientKey,
            clientCertificate: otlpConfig.clientCertificate,
          ),
        );
      } else {
        // Default to http/protobuf
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'LogsConfiguration: Creating OtlpHttpLogRecordExporter');
        }
        return OtlpHttpLogRecordExporter(
          OtlpHttpLogRecordExporterConfig(
            endpoint: effectiveEndpoint,
            headers: otlpConfig.headers ?? {},
            timeout: otlpConfig.timeout ?? const Duration(seconds: 10),
            compression: otlpConfig.compression == 'gzip',
            certificate: otlpConfig.certificate,
            clientKey: otlpConfig.clientKey,
            clientCertificate: otlpConfig.clientCertificate,
          ),
        );
      }
    }

    // Unknown exporter type
    if (OTelLog.isDebug()) {
      OTelLog.debug('LogsConfiguration: Unknown exporter type: $exporterType');
    }
    return null;
  }

  /// Creates a log record processor with BLRP configuration from environment.
  static LogRecordProcessor _createProcessor(
      LogRecordExporter exporter, BlrpEnvironmentValues blrpConfig) {
    final processorConfig =
        BatchLogRecordProcessorConfig.fromBlrpEnvironmentValues(blrpConfig);
    return BatchLogRecordProcessor(exporter, processorConfig);
  }

  /// Creates a simple (synchronous) log record processor instead of batch.
  ///
  /// This is useful for development/debugging or when you want immediate export.
  static LogRecordProcessor createSimpleProcessor(LogRecordExporter exporter) {
    return SimpleLogRecordProcessor(exporter);
  }
}
