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
  /// @param endpoint The endpoint URL for the exporter
  /// @param secure Whether to use TLS for gRPC connections
  /// @param logRecordExporter Optional custom exporter (overrides env var)
  /// @param logRecordProcessor Optional custom processor (overrides env var)
  /// @param resource Optional resource for the LoggerProvider
  /// @return The configured LoggerProvider
  static LoggerProvider configureLoggerProvider({
    String endpoint = 'http://localhost:4318',
    bool secure = false,
    LogRecordExporter? logRecordExporter,
    LogRecordProcessor? logRecordProcessor,
    Resource? resource,
  }) {
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
      logProvider.addLogRecordProcessor(_createProcessor(logRecordExporter));
      return logProvider;
    }

    // Spec "Exporter Selection": OTEL_LOGS_EXPORTER, default otlp; the
    // comma-separated list form is supported. Known: otlp, console, none.
    // Multiple exporters install one processor per exporter.
    final requested = OTelEnv.getExporters(signal: 'logs') ?? ['otlp'];
    if (requested.contains('none')) {
      if (requested.length > 1 && OTelLog.isWarn()) {
        OTelLog.warn("OTEL_LOGS_EXPORTER contains 'none' alongside other "
            'values; installing no processor.');
      } else if (OTelLog.isDebug()) {
        OTelLog.debug(
            'LogsConfiguration: OTEL_LOGS_EXPORTER=none, no processor added');
      }
      return logProvider;
    }

    final exporters = <LogRecordExporter>[];
    for (final name in requested) {
      if (name == 'logging') {
        if (OTelLog.isWarn()) {
          OTelLog.warn("OTEL_LOGS_EXPORTER value 'logging' is deprecated "
              "in the spec and not supported; use 'console'.");
        }
        continue;
      }
      final created = _createExporter(name, endpoint, secure);
      if (created != null) {
        exporters.add(created);
      } else if (OTelLog.isWarn()) {
        OTelLog.warn("OTEL_LOGS_EXPORTER value '$name' is not supported; "
            'ignoring. Supported: otlp, console, none.');
      }
    }
    if (exporters.isEmpty) {
      if (OTelLog.isWarn()) {
        OTelLog.warn('OTEL_LOGS_EXPORTER produced no usable exporter; '
            'falling back to the default otlp exporter.');
      }
      final fallback = _createExporter('otlp', endpoint, secure);
      if (fallback != null) {
        exporters.add(fallback);
      }
    }
    for (final exporter in exporters) {
      logProvider.addLogRecordProcessor(_createProcessor(exporter));
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug('LogsConfiguration: Configured LoggerProvider with '
          '${exporters.length} exporter(s) from OTEL_LOGS_EXPORTER');
    }

    return logProvider;
  }

  /// Creates a log record exporter based on the exporter type.
  static LogRecordExporter? _createExporter(
    String exporterType,
    String endpoint,
    bool secure,
  ) {
    // Get OTLP config for logs signal
    final otlpConfig = OTelEnv.getOtlpConfig(signal: 'logs');

    // Use env endpoint if available, otherwise use provided endpoint
    final effectiveEndpoint = otlpConfig['endpoint'] as String? ?? endpoint;
    final envInsecure = otlpConfig['insecure'] as bool?;
    final effectiveSecure = OTelEnv.resolveOtlpSecure(
      envInsecure: envInsecure,
      endpoint: effectiveEndpoint,
      fallback: secure,
    );

    if (exporterType == 'console') {
      if (OTelLog.isDebug()) {
        OTelLog.debug('LogsConfiguration: Creating ConsoleLogRecordExporter');
      }
      return ConsoleLogRecordExporter();
    }

    if (exporterType == 'otlp') {
      // Determine protocol - default to http/protobuf
      final protocol = otlpConfig['protocol'] as String? ?? 'http/protobuf';

      if (protocol == 'grpc') {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'LogsConfiguration: Creating OtlpGrpcLogRecordExporter');
        }
        return OtlpGrpcLogRecordExporter(
          OtlpGrpcLogRecordExporterConfig(
            endpoint: effectiveEndpoint,
            insecure: !effectiveSecure,
            headers: otlpConfig['headers'] as Map<String, String>? ?? {},
            timeout: otlpConfig['timeout'] as Duration? ??
                const Duration(seconds: 10),
            compression: otlpConfig['compression'] == 'gzip',
            certificate: otlpConfig['certificate'] as String?,
            clientKey: otlpConfig['clientKey'] as String?,
            clientCertificate: otlpConfig['clientCertificate'] as String?,
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
            headers: otlpConfig['headers'] as Map<String, String>? ?? {},
            timeout: otlpConfig['timeout'] as Duration? ??
                const Duration(seconds: 10),
            compression: otlpConfig['compression'] == 'gzip',
            certificate: otlpConfig['certificate'] as String?,
            clientKey: otlpConfig['clientKey'] as String?,
            clientCertificate: otlpConfig['clientCertificate'] as String?,
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
  static LogRecordProcessor _createProcessor(LogRecordExporter exporter) {
    final processorConfig = BatchLogRecordProcessorConfig.fromEnvironment();
    return BatchLogRecordProcessor(exporter, processorConfig);
  }

  /// Builds [BatchLogRecordProcessorConfig] from a BLRP environment config map.
  ///
  /// Exposed for testing to validate normalization and spec-rule handling.
  /// Prefer [BatchLogRecordProcessorConfig.fromEnvironment] for production use.
  static BatchLogRecordProcessorConfig buildBatchLogRecordProcessorConfig(
    Map<String, dynamic> blrpConfig,
  ) {
    if (blrpConfig.isEmpty) {
      return const BatchLogRecordProcessorConfig();
    }

    // Build config from environment
    final scheduleDelay = blrpConfig['scheduleDelay'] as Duration?;
    final exportTimeout = blrpConfig['exportTimeout'] as Duration?;
    final maxQueueSize = blrpConfig['maxQueueSize'] as int? ?? 2048;
    var maxExportBatchSize = blrpConfig['maxExportBatchSize'] as int? ?? 512;

    if (maxExportBatchSize > maxQueueSize) {
      if (OTelLog.isWarn()) {
        OTelLog.warn(
          'LogsConfiguration: maxExportBatchSize ($maxExportBatchSize) exceeds '
          'maxQueueSize ($maxQueueSize). Clamping batch size to queue size.',
        );
      }
      maxExportBatchSize = maxQueueSize;
    }

    return BatchLogRecordProcessorConfig(
      scheduleDelay: scheduleDelay ?? const Duration(milliseconds: 1000),
      exportTimeout: exportTimeout ?? const Duration(seconds: 30),
      maxQueueSize: maxQueueSize,
      maxExportBatchSize: maxExportBatchSize,
    );
  }

  /// Creates a simple (synchronous) log record processor instead of batch.
  ///
  /// This is useful for development/debugging or when you want immediate export.
  static LogRecordProcessor createSimpleProcessor(LogRecordExporter exporter) {
    return SimpleLogRecordProcessor(exporter);
  }
}
