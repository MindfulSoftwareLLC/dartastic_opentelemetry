// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import '../metrics/export/metrics_sdk_config.dart';
import '../util/header_redaction.dart';
import 'env_constants.dart';
import 'environment_service.dart';

/// Raw BLRP environment values parsed by [OTelEnv.getBlrpConfig].
///
/// All fields are nullable — `null` means the corresponding env var was
/// unset or contained a non-numeric value (a warning is logged in that case).
/// Domain-level validation (e.g. "queue size must be > 0") belongs in
/// [BatchLogRecordProcessorConfig.fromEnvironment], not here.
typedef BlrpEnvironmentValues = ({
  /// Parsed from `OTEL_BLRP_SCHEDULE_DELAY`
  Duration? scheduleDelay,

  /// Parsed from `OTEL_BLRP_EXPORT_TIMEOUT`
  Duration? exportTimeout,

  /// Parsed from `OTEL_BLRP_MAX_QUEUE_SIZE`
  int? maxQueueSize,

  /// Parsed from `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE`
  int? maxExportBatchSize,
});

/// Raw OTLP environment values parsed by [OTelEnv.getOtlpConfig].
///
/// All fields are nullable — `null` means the corresponding env var was
/// unset or unparseable. Signal-specific variables take precedence over
/// general ones per the OTel specification.
typedef OtlpEnvironmentValues = ({
  /// Parsed from `OTEL_EXPORTER_OTLP_{SIGNAL}_ENDPOINT` or
  /// `OTEL_EXPORTER_OTLP_ENDPOINT`
  String? endpoint,

  /// Parsed from `OTEL_EXPORTER_OTLP_{SIGNAL}_PROTOCOL` or
  /// `OTEL_EXPORTER_OTLP_PROTOCOL`
  String? protocol,

  /// Parsed from `OTEL_EXPORTER_OTLP_{SIGNAL}_HEADERS` or
  /// `OTEL_EXPORTER_OTLP_HEADERS`
  Map<String, String>? headers,

  /// Parsed from `OTEL_EXPORTER_OTLP_{SIGNAL}_INSECURE` or
  /// `OTEL_EXPORTER_OTLP_INSECURE`
  bool? insecure,

  /// Parsed from `OTEL_EXPORTER_OTLP_{SIGNAL}_TIMEOUT` or
  /// `OTEL_EXPORTER_OTLP_TIMEOUT`
  Duration? timeout,

  /// Parsed from `OTEL_EXPORTER_OTLP_{SIGNAL}_COMPRESSION` or
  /// `OTEL_EXPORTER_OTLP_COMPRESSION`
  String? compression,

  /// Parsed from `OTEL_EXPORTER_OTLP_{SIGNAL}_CERTIFICATE` or
  /// `OTEL_EXPORTER_OTLP_CERTIFICATE`
  String? certificate,

  /// Parsed from `OTEL_EXPORTER_OTLP_{SIGNAL}_CLIENT_KEY` or
  /// `OTEL_EXPORTER_OTLP_CLIENT_KEY`
  String? clientKey,

  /// Parsed from `OTEL_EXPORTER_OTLP_{SIGNAL}_CLIENT_CERTIFICATE` or
  /// `OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE`
  String? clientCertificate,
});

/// Raw BSP environment values parsed by [OTelEnv.getBspConfig].
///
/// All fields are nullable — `null` means the corresponding env var was
/// unset or contained a non-numeric value (a warning is logged in that case).
/// Domain-level validation belongs in
/// [BatchSpanProcessorConfig.fromEnvironment], not here.
typedef BspEnvironmentValues = ({
  /// Parsed from `OTEL_BSP_SCHEDULE_DELAY`
  Duration? scheduleDelay,

  /// Parsed from `OTEL_BSP_EXPORT_TIMEOUT`
  Duration? exportTimeout,

  /// Parsed from `OTEL_BSP_MAX_QUEUE_SIZE`
  int? maxQueueSize,

  /// Parsed from `OTEL_BSP_MAX_EXPORT_BATCH_SIZE`
  int? maxExportBatchSize,
});

/// Raw service environment values parsed by [OTelEnv.getServiceConfig].
///
/// All fields are nullable — `null` means the corresponding env var was
/// unset. `OTEL_SERVICE_NAME` takes precedence over `service.name` in
/// `OTEL_RESOURCE_ATTRIBUTES` per the spec.
typedef ServiceEnvironmentValues = ({
  /// Parsed from `OTEL_SERVICE_NAME` or `service.name` in
  /// `OTEL_RESOURCE_ATTRIBUTES`
  String? serviceName,

  /// Parsed from `service.version` in `OTEL_RESOURCE_ATTRIBUTES`
  String? serviceVersion,
});

/// Raw log record limit values parsed by [OTelEnv.getLogRecordLimits].
///
/// All fields are nullable — `null` means the corresponding env var was
/// unset or contained a non-numeric value.
typedef LogRecordLimitsEnvironmentValues = ({
  /// Parsed from `OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT`
  int? attributeValueLengthLimit,

  /// Parsed from `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT`
  int? attributeCountLimit,
});

/// Raw metrics environment values parsed by [OTelEnv.getMetricsConfig].
///
/// All fields are nullable — `null` means the corresponding env var was
/// unset. Domain-level validation and defaults belong in
/// [MetricsSdkConfig.fromEnvironment], not here.
typedef MetricsEnvironmentValues = ({
  /// Parsed from `OTEL_METRICS_EXEMPLAR_FILTER`
  String? exemplarFilter,

  /// Parsed from `OTEL_METRIC_EXPORT_INTERVAL`
  Duration? exportInterval,

  /// Parsed from `OTEL_METRIC_EXPORT_TIMEOUT`
  Duration? exportTimeout,
});

/// Utility class for handling OpenTelemetry environment variables.
///
/// This class provides methods for reading standard OpenTelemetry environment
/// variables and applying their configuration to the SDK.
///
/// OpenTelemetry standard environment variables:
/// https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
class OTelEnv {
  /// Initialize logging based on environment variables.
  ///
  /// This method reads the logging-related environment variables
  /// and configures the OTelLog accordingly.
  ///
  /// If a custom log function has already been set (e.g., by tests),
  /// this method will preserve it along with the current log level.
  /// This allows tests to fully control logging configuration without
  /// environment variables overriding their settings.
  static void initializeLogging() {
    // Save the current log function to check if it's custom
    final existingLogFunction = OTelLog.logFunction;

    // A custom function is one that's not null and not the default print function
    final hasCustomLogFunction =
        existingLogFunction != null && existingLogFunction != print;

    // Set log level and function based on environment variable,
    // but only if no custom log function is already configured.
    final logLevel = _getEnv(otelLogLevel)?.toLowerCase();
    if (logLevel != null && !hasCustomLogFunction) {
      switch (logLevel) {
        case 'trace':
          OTelLog.enableTraceLogging();
          break;
        case 'debug':
          OTelLog.enableDebugLogging();
          break;
        case 'info':
          OTelLog.enableInfoLogging();
          break;
        case 'warn':
          OTelLog.enableWarnLogging();
          break;
        case 'error':
          OTelLog.enableErrorLogging();
          break;
        case 'fatal':
          OTelLog.enableFatalLogging();
          break;
        default:
          // No change to logging if level not recognized
          break;
      }

      OTelLog.logFunction = print;
    }

    // Dart-specific per-signal diagnostic sinks, named per the spec's
    // language-specific env var convention (OTEL_{LANGUAGE}_{FEATURE}).
    // The spec's self-diagnostics section leaves this to language
    // conventions; OTEL_LOG_LEVEL governs only the internal logger level.
    if (_getEnvBool(otelDartLogMetrics) && OTelLog.metricLogFunction == null) {
      OTelLog.metricLogFunction = print;
    }
    if (_getEnvBool(otelDartLogSpans) && OTelLog.spanLogFunction == null) {
      OTelLog.spanLogFunction = print;
    }
    if (_getEnvBool(otelDartLogExport) && OTelLog.exportLogFunction == null) {
      OTelLog.exportLogFunction = print;
    }
  }

  /// Applies the OTLP header log allowlist.
  ///
  /// [headerNames] comes from `OTel.initialize`. When null,
  /// `OTEL_DART_HEADER_LOG_ALLOWLIST` is read instead; code wins over
  /// configuration and the two are never combined. With neither set, no header
  /// value is logged.
  ///
  /// The allowlist is read at log time, so call this before anything logs
  /// headers.
  static void applyHeaderLogAllowlist([Iterable<String>? headerNames]) {
    if (headerNames != null) {
      configureHeaderLogAllowlist(headerNames);
      return;
    }
    configureHeaderLogAllowlist(
      parseHeaderLogAllowlist(_getEnv(otelDartHeaderLogAllowlist)),
    );
  }

  /// Get OTLP configuration from environment variables.
  ///
  /// Returns an [OtlpEnvironmentValues] record containing the OTLP
  /// configuration read from environment variables. Signal-specific
  /// variables take precedence over general ones.
  static OtlpEnvironmentValues getOtlpConfig({String signal = 'traces'}) {
    // Get endpoint (signal-specific takes precedence)
    String? endpoint;
    switch (signal) {
      case 'traces':
        endpoint = _getEnv(otelExporterOtlpTracesEndpoint) ??
            _getEnv(otelExporterOtlpEndpoint);
        break;
      case 'metrics':
        endpoint = _getEnv(otelExporterOtlpMetricsEndpoint) ??
            _getEnv(otelExporterOtlpEndpoint);
        break;
      case 'logs':
        endpoint = _getEnv(otelExporterOtlpLogsEndpoint) ??
            _getEnv(otelExporterOtlpEndpoint);
        break;
    }

    // Get protocol (signal-specific takes precedence)
    String? protocol;
    switch (signal) {
      case 'traces':
        protocol = _getEnv(otelExporterOtlpTracesProtocol) ??
            _getEnv(otelExporterOtlpProtocol);
        break;
      case 'metrics':
        protocol = _getEnv(otelExporterOtlpMetricsProtocol) ??
            _getEnv(otelExporterOtlpProtocol);
        break;
      case 'logs':
        protocol = _getEnv(otelExporterOtlpLogsProtocol) ??
            _getEnv(otelExporterOtlpProtocol);
        break;
    }

    // Get headers (signal-specific takes precedence)
    Map<String, String>? parsedHeaders;
    String? rawHeaders;
    switch (signal) {
      case 'traces':
        rawHeaders = _getEnv(otelExporterOtlpTracesHeaders) ??
            _getEnv(otelExporterOtlpHeaders);
        break;
      case 'metrics':
        rawHeaders = _getEnv(otelExporterOtlpMetricsHeaders) ??
            _getEnv(otelExporterOtlpHeaders);
        break;
      case 'logs':
        rawHeaders = _getEnv(otelExporterOtlpLogsHeaders) ??
            _getEnv(otelExporterOtlpHeaders);
        break;
    }
    if (rawHeaders != null) {
      if (OTelLog.isDebug()) {
        // The raw value holds the Authorization header the loop below redacts.
        OTelLog.debug('OTelEnv: Parsing $signal headers from env');
      }
      parsedHeaders = _parseHeaders(rawHeaders);
      if (OTelLog.isDebug()) {
        OTelLog.debug('OTelEnv: Parsed ${parsedHeaders.length} header(s)');
        parsedHeaders.forEach((key, value) {
          OTelLog.debug('  ${formatHeaderForLog(key, value)}');
        });
      }
    }

    // Get insecure setting (signal-specific takes precedence)
    bool? insecure;
    switch (signal) {
      case 'traces':
        insecure = _getEnvBoolNullable(otelExporterOtlpTracesInsecure) ??
            _getEnvBoolNullable(otelExporterOtlpInsecure);
        break;
      case 'metrics':
        insecure = _getEnvBoolNullable(otelExporterOtlpMetricsInsecure) ??
            _getEnvBoolNullable(otelExporterOtlpInsecure);
        break;
      case 'logs':
        insecure = _getEnvBoolNullable(otelExporterOtlpLogsInsecure) ??
            _getEnvBoolNullable(otelExporterOtlpInsecure);
        break;
    }

    // Get timeout (signal-specific takes precedence)
    Duration? parsedTimeout;
    String? rawTimeout;
    switch (signal) {
      case 'traces':
        rawTimeout = _getEnv(otelExporterOtlpTracesTimeout) ??
            _getEnv(otelExporterOtlpTimeout);
        break;
      case 'metrics':
        rawTimeout = _getEnv(otelExporterOtlpMetricsTimeout) ??
            _getEnv(otelExporterOtlpTimeout);
        break;
      case 'logs':
        rawTimeout = _getEnv(otelExporterOtlpLogsTimeout) ??
            _getEnv(otelExporterOtlpTimeout);
        break;
    }
    if (rawTimeout != null) {
      final timeoutMs = int.tryParse(rawTimeout);
      if (timeoutMs != null) {
        parsedTimeout = Duration(milliseconds: timeoutMs);
      }
    }

    // Get compression (signal-specific takes precedence)
    String? compression;
    switch (signal) {
      case 'traces':
        compression = _getEnv(otelExporterOtlpTracesCompression) ??
            _getEnv(otelExporterOtlpCompression);
        break;
      case 'metrics':
        compression = _getEnv(otelExporterOtlpMetricsCompression) ??
            _getEnv(otelExporterOtlpCompression);
        break;
      case 'logs':
        compression = _getEnv(otelExporterOtlpLogsCompression) ??
            _getEnv(otelExporterOtlpCompression);
        break;
    }

    // Get certificate (signal-specific takes precedence)
    String? certificate;
    switch (signal) {
      case 'traces':
        certificate = _getEnv(otelExporterOtlpTracesCertificate) ??
            _getEnv(otelExporterOtlpCertificate);
        break;
      case 'metrics':
        certificate = _getEnv(otelExporterOtlpMetricsCertificate) ??
            _getEnv(otelExporterOtlpCertificate);
        break;
      case 'logs':
        certificate = _getEnv(otelExporterOtlpLogsCertificate) ??
            _getEnv(otelExporterOtlpCertificate);
        break;
    }

    // Get client key (signal-specific takes precedence)
    String? clientKey;
    switch (signal) {
      case 'traces':
        clientKey = _getEnv(otelExporterOtlpTracesClientKey) ??
            _getEnv(otelExporterOtlpClientKey);
        break;
      case 'metrics':
        clientKey = _getEnv(otelExporterOtlpMetricsClientKey) ??
            _getEnv(otelExporterOtlpClientKey);
        break;
      case 'logs':
        clientKey = _getEnv(otelExporterOtlpLogsClientKey) ??
            _getEnv(otelExporterOtlpClientKey);
        break;
    }

    // Get client certificate (signal-specific takes precedence)
    String? clientCertificate;
    switch (signal) {
      case 'traces':
        clientCertificate = _getEnv(otelExporterOtlpTracesClientCertificate) ??
            _getEnv(otelExporterOtlpClientCertificate);
        break;
      case 'metrics':
        clientCertificate = _getEnv(otelExporterOtlpMetricsClientCertificate) ??
            _getEnv(otelExporterOtlpClientCertificate);
        break;
      case 'logs':
        clientCertificate = _getEnv(otelExporterOtlpLogsClientCertificate) ??
            _getEnv(otelExporterOtlpClientCertificate);
        break;
    }

    return (
      endpoint: endpoint,
      protocol: protocol,
      headers: parsedHeaders,
      insecure: insecure,
      timeout: parsedTimeout,
      compression: compression,
      certificate: certificate,
      clientKey: clientKey,
      clientCertificate: clientCertificate,
    );
  }

  /// Get service configuration from environment variables.
  ///
  /// Returns a [ServiceEnvironmentValues] record containing the service
  /// configuration read from environment variables.
  ///
  /// Handles the spec precedence rules:
  /// - If `service.name` is in OTEL_RESOURCE_ATTRIBUTES, it's used as the base value
  /// - OTEL_SERVICE_NAME takes precedence over `service.name` in OTEL_RESOURCE_ATTRIBUTES
  /// - `service.version` comes from OTEL_RESOURCE_ATTRIBUTES only
  static ServiceEnvironmentValues getServiceConfig() {
    String? parsedServiceName;
    String? parsedServiceVersion;

    // First, parse service.name and service.version from OTEL_RESOURCE_ATTRIBUTES
    final resourceStr = _getEnv(otelResourceAttributes);
    if (resourceStr != null) {
      final pairs = resourceStr.split(',');
      for (final pair in pairs) {
        final equalIndex = pair.indexOf('=');
        if (equalIndex > 0 && equalIndex < pair.length - 1) {
          final key = pair.substring(0, equalIndex).trim();
          final value = pair.substring(equalIndex + 1).trim();

          if (key == Service.serviceName.key) {
            parsedServiceName = value;
          } else if (key == Service.serviceVersion.key) {
            parsedServiceVersion = value;
          }
        }
      }
    }

    // OTEL_SERVICE_NAME takes precedence over service.name from resource attributes
    final serviceName = _getEnv(otelServiceName);
    if (serviceName != null) {
      parsedServiceName = serviceName;
    }

    return (
      serviceName: parsedServiceName,
      serviceVersion: parsedServiceVersion,
    );
  }

  /// Get resource attributes from environment variables.
  ///
  /// Parses the OTEL_RESOURCE_ATTRIBUTES environment variable which should be
  /// a comma-separated list of key=value pairs.
  static Map<String, Object> getResourceAttributes() {
    final resourceAttrs = <String, Object>{};

    final resourceStr = _getEnv(otelResourceAttributes);
    if (resourceStr != null) {
      final pairs = resourceStr.split(',');
      for (final pair in pairs) {
        final parts = pair.split('=');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = parts[1].trim();
          // Try to parse as number if possible
          final intValue = int.tryParse(value);
          if (intValue != null) {
            resourceAttrs[key] = intValue;
          } else {
            final doubleValue = double.tryParse(value);
            if (doubleValue != null) {
              resourceAttrs[key] = doubleValue;
            } else {
              // Handle boolean values
              if (value.toLowerCase() == 'true') {
                resourceAttrs[key] = true;
              } else if (value.toLowerCase() == 'false') {
                resourceAttrs[key] = false;
              } else {
                resourceAttrs[key] = value;
              }
            }
          }
        }
      }
    }

    return resourceAttrs;
  }

  /// Whether `OTEL_SDK_DISABLED` is set to a truthy value.
  ///
  /// Per the OTel spec, when this is true the SDK acts as a no-op for all
  /// signals — no span processors, metric readers, or log record processors
  /// should be installed.
  static bool isSdkDisabled() => _getEnvBool(otelSdkDisabled);

  /// Get the selected exporter for a signal.
  ///
  /// Returns the exporter type configured via environment variables.
  static String? getExporter({String signal = 'traces'}) {
    switch (signal) {
      case 'traces':
        return _getEnv(otelTracesExporter);
      case 'metrics':
        return _getEnv(otelMetricsExporter);
      case 'logs':
        return _getEnv(otelLogsExporter);
      default:
        return null;
    }
  }

  /// Reads `OTEL_<SIGNAL>_EXPORTER` as the spec's comma-separated list
  /// (sdk-environment-variables.md, "Exporter Selection": "The
  /// implementation MAY accept a comma-separated list to enable setting
  /// multiple exporters"). Returns normalized (trimmed, lowercased,
  /// deduplicated) names, or null when the variable is unset or empty.
  static List<String>? getExporters({String signal = 'traces'}) {
    final raw = getExporter(signal: signal);
    if (raw == null) return null;
    final names = <String>[];
    for (final part in raw.split(',')) {
      final name = part.trim().toLowerCase();
      if (name.isNotEmpty && !names.contains(name)) {
        names.add(name);
      }
    }
    return names.isEmpty ? null : names;
  }

  /// Get Batch Span Processor (BSP) configuration from environment variables.
  ///
  /// Returns a [BspEnvironmentValues] record containing the raw parsed BSP
  /// values from environment variables. Fields are `null` when the
  /// corresponding env var is unset or contains a non-numeric value.
  ///
  /// Domain-level defaults, validation, and clamping belong in
  /// [BatchSpanProcessorConfig.fromEnvironment], not here.
  static BspEnvironmentValues getBspConfig() {
    // Get schedule delay
    Duration? parsedScheduleDelay;
    final scheduleDelay = _getEnv(otelBspScheduleDelay);
    if (scheduleDelay != null) {
      final delayMs = int.tryParse(scheduleDelay);
      if (delayMs != null) {
        parsedScheduleDelay = Duration(milliseconds: delayMs);
      } else {
        if (OTelLog.isWarn()) {
          OTelLog.warn('OTelEnv: Invalid OTEL_BSP_SCHEDULE_DELAY value '
              '"$scheduleDelay", ignoring.');
        }
      }
    }

    // Get export timeout
    Duration? parsedExportTimeout;
    final exportTimeout = _getEnv(otelBspExportTimeout);
    if (exportTimeout != null) {
      final timeoutMs = int.tryParse(exportTimeout);
      if (timeoutMs != null) {
        parsedExportTimeout = Duration(milliseconds: timeoutMs);
      } else {
        if (OTelLog.isWarn()) {
          OTelLog.warn('OTelEnv: Invalid OTEL_BSP_EXPORT_TIMEOUT value '
              '"$exportTimeout", ignoring.');
        }
      }
    }

    // Get max queue size
    int? parsedMaxQueueSize;
    final maxQueueSize = _getEnv(otelBspMaxQueueSize);
    if (maxQueueSize != null) {
      final size = int.tryParse(maxQueueSize);
      if (size != null) {
        parsedMaxQueueSize = size;
      } else {
        if (OTelLog.isWarn()) {
          OTelLog.warn('OTelEnv: Invalid OTEL_BSP_MAX_QUEUE_SIZE value '
              '"$maxQueueSize", ignoring.');
        }
      }
    }

    // Get max export batch size
    int? parsedMaxExportBatchSize;
    final maxExportBatchSize = _getEnv(otelBspMaxExportBatchSize);
    if (maxExportBatchSize != null) {
      final size = int.tryParse(maxExportBatchSize);
      if (size != null) {
        parsedMaxExportBatchSize = size;
      } else {
        if (OTelLog.isWarn()) {
          OTelLog.warn('OTelEnv: Invalid OTEL_BSP_MAX_EXPORT_BATCH_SIZE '
              'value "$maxExportBatchSize", ignoring.');
        }
      }
    }

    return (
      scheduleDelay: parsedScheduleDelay,
      exportTimeout: parsedExportTimeout,
      maxQueueSize: parsedMaxQueueSize,
      maxExportBatchSize: parsedMaxExportBatchSize,
    );
  }

  /// Reads `OTEL_PROPAGATORS` (sdk-environment-variables.md, "General SDK
  /// Configuration"): a comma-separated list of propagator names. Returns
  /// the normalized (trimmed, lowercased) names, defaulting to the spec
  /// default `[tracecontext, baggage]` when unset or empty.
  static List<String> getPropagators() {
    final raw = _getEnv(otelPropagators);
    if (raw == null || raw.trim().isEmpty) {
      return const ['tracecontext', 'baggage'];
    }
    return raw
        .split(',')
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Get Batch LogRecord Processor (BLRP) configuration from environment variables.
  ///
  /// Returns a [BlrpEnvironmentValues] record containing the raw parsed BLRP
  /// values from environment variables. Fields are `null` when the
  /// corresponding env var is unset or contains a non-numeric value.
  ///
  /// Domain-level defaults, validation, and clamping belong in
  /// [BatchLogRecordProcessorConfig.fromEnvironment], not here.
  static BlrpEnvironmentValues getBlrpConfig() {
    // Get schedule delay — 0 is valid ("export as fast as possible")
    final scheduleDelayMs =
        getPositiveIntEnv(otelBlrpScheduleDelay, minInclusive: 0);

    // Get export timeout — 0 is valid ("no limit")
    final exportTimeoutMs =
        getPositiveIntEnv(otelBlrpExportTimeout, minInclusive: 0);

    // Get queue and batch sizes — just parse, no domain validation here
    final parsedMaxQueueSize =
        getPositiveIntEnv(otelBlrpMaxQueueSize, minInclusive: 0);
    final parsedMaxExportBatchSize =
        getPositiveIntEnv(otelBlrpMaxExportBatchSize, minInclusive: 0);

    return (
      scheduleDelay: scheduleDelayMs != null
          ? Duration(milliseconds: scheduleDelayMs)
          : null,
      exportTimeout: exportTimeoutMs != null
          ? Duration(milliseconds: exportTimeoutMs)
          : null,
      maxQueueSize: parsedMaxQueueSize,
      maxExportBatchSize: parsedMaxExportBatchSize,
    );
  }

  /// Get LogRecord attribute limits from environment variables.
  ///
  /// Returns a [LogRecordLimitsEnvironmentValues] record containing the
  /// log record attribute limits. Fields are `null` when the corresponding
  /// env var is unset or contains a non-numeric value.
  static LogRecordLimitsEnvironmentValues getLogRecordLimits() {
    // Get attribute value length limit
    int? parsedValueLengthLimit;
    final valueLengthLimit = _getEnv(otelLogrecordAttributeValueLengthLimit);
    if (valueLengthLimit != null) {
      parsedValueLengthLimit = int.tryParse(valueLengthLimit);
    }

    // Get attribute count limit
    int? parsedCountLimit;
    final countLimit = _getEnv(otelLogrecordAttributeCountLimit);
    if (countLimit != null) {
      parsedCountLimit = int.tryParse(countLimit);
    }

    return (
      attributeValueLengthLimit: parsedValueLengthLimit,
      attributeCountLimit: parsedCountLimit,
    );
  }

  /// Get metrics SDK configuration from environment variables.
  static MetricsEnvironmentValues getMetricsConfig() {
    final exportIntervalMs =
        getPositiveIntEnv(otelMetricExportInterval, minInclusive: 0);
    final exportTimeoutMs =
        getPositiveIntEnv(otelMetricExportTimeout, minInclusive: 0);

    return (
      exemplarFilter: _getEnv(otelMetricsExemplarFilter),
      exportInterval: exportIntervalMs != null
          ? Duration(milliseconds: exportIntervalMs)
          : null,
      exportTimeout: exportTimeoutMs != null
          ? Duration(milliseconds: exportTimeoutMs)
          : null,
    );
  }

  /// Resolves whether an OTLP connection should use TLS, per the OTLP
  /// exporter spec's precedence:
  ///
  /// 1. an explicit programmatic choice ([explicitSecure]) wins;
  /// 2. otherwise the endpoint **scheme** decides — the spec states the
  ///    scheme indicates the connection security, and that
  ///    `OTEL_EXPORTER_OTLP_INSECURE` "only applies to OTLP/gRPC when an
  ///    endpoint is provided without the http or https scheme";
  /// 3. otherwise `OTEL_EXPORTER_OTLP_INSECURE` (or its per-signal
  ///    variant, passed as [envInsecure]) applies;
  /// 4. otherwise [fallback] (secure by default).
  ///
  /// Bare `host:port` endpoints parse with a bogus scheme (`host`), so
  /// only exact `http`/`https` schemes participate in step 2.
  static bool resolveOtlpSecure({
    bool? explicitSecure,
    bool? envInsecure,
    String? endpoint,
    bool fallback = true,
  }) {
    if (explicitSecure != null) {
      return explicitSecure;
    }
    final scheme =
        endpoint == null ? null : Uri.tryParse(endpoint)?.scheme.toLowerCase();
    if (scheme == 'http') {
      return false;
    }
    if (scheme == 'https') {
      return true;
    }
    if (envInsecure != null) {
      return !envInsecure;
    }
    return fallback;
  }

  /// Parse headers from the environment variable format.
  ///
  /// Headers are expected in the format: key1=value1,key2=value2
  /// Note: Header values can contain '=' characters (e.g., base64), so we only
  /// split on the first '=' for each pair.
  static Map<String, String> _parseHeaders(String headerStr) {
    final headers = <String, String>{};

    final pairs = headerStr.split(',');
    for (final pair in pairs) {
      final equalIndex = pair.indexOf('=');
      if (equalIndex > 0 && equalIndex < pair.length - 1) {
        final key = pair.substring(0, equalIndex).trim();
        final value = pair.substring(equalIndex + 1).trim();
        headers[key] = value;
      }
    }

    return headers;
  }

  /// Get environment variable value.
  ///
  /// This method safely retrieves an environment variable value,
  /// handling exceptions that might occur in environments where
  /// Platform is not available (e.g., browsers).
  ///
  /// @param name The name of the environment variable
  /// @return The value of the environment variable, or null if not found
  static String? _getEnv(String name) {
    return EnvironmentService.instance.getValue(name);
  }

  /// Get boolean environment variable value.
  ///
  /// This method converts an environment variable value to a boolean.
  /// Values of '1', 'true', 'yes', and 'on' (case-insensitive) are considered true.
  ///
  /// @param name The name of the environment variable
  /// @return true if the environment variable has a truthy value, false otherwise
  static bool _getEnvBool(String name) {
    final rawValue = _getEnv(name);
    if (rawValue == null || rawValue.isEmpty) return false;

    final value = rawValue.toLowerCase();
    if (value == 'true') {
      return true;
    } else if (value == 'false') {
      return false;
    } else {
      if (OTelLog.isWarn()) {
        OTelLog.warn('OTelEnv: Invalid boolean value for $name: "$rawValue". '
            'Expected "true" or "false". Treating as false.');
      }
      return false;
    }
  }

  /// Get boolean environment variable value that can be null.
  ///
  /// This method converts an environment variable value to a boolean.
  /// Only the case-insensitive string 'true' is considered true.
  /// All other values are considered false.
  /// Returns null only when the variable is unset or empty.
  ///
  /// @param name The name of the environment variable
  /// @return true/false if the environment variable is set, null otherwise
  static bool? _getEnvBoolNullable(String name) {
    final rawValue = _getEnv(name);
    if (rawValue == null || rawValue.isEmpty) return null;

    final value = rawValue.toLowerCase();
    if (value == 'true') {
      return true;
    } else if (value == 'false') {
      return false;
    } else {
      if (OTelLog.isWarn()) {
        OTelLog.warn('OTelEnv: Invalid boolean value for $name: "$rawValue". '
            'Expected "true" or "false". Treating as false.');
      }
      return false;
    }
  }

  /// Get a non-negative integer environment variable value.
  ///
  /// Returns null when not set, non-numeric, or outside the accepted range.
  /// Warns via [OTelLog.warn] when the raw value is present but unusable
  /// (non-numeric, below [minInclusive], or above [maxInclusive]).
  static int? getPositiveIntEnv(
    String name, {
    required int minInclusive,
    int? maxInclusive,
  }) {
    final rawValue = _getEnv(name);
    if (rawValue == null) {
      return null;
    }

    final value = int.tryParse(rawValue);
    if (value == null) {
      if (OTelLog.isWarn()) {
        OTelLog.warn('OTelEnv: Illegal non-numeric value for $name: '
            '"$rawValue", ignoring.');
      }
      return null;
    }

    if (value < minInclusive) {
      if (OTelLog.isWarn()) {
        OTelLog.warn('OTelEnv: Illegal value for $name: $value is below '
            'minimum $minInclusive, ignoring.');
      }
      return null;
    }

    if (maxInclusive != null && value > maxInclusive) {
      if (OTelLog.isWarn()) {
        OTelLog.warn('OTelEnv: Illegal value for $name: $value exceeds '
            'maximum $maxInclusive, ignoring.');
      }
      return null;
    }

    return value;
  }
}
