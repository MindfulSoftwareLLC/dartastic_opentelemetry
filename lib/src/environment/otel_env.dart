// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'environment_service.dart';

/// Utility class for handling OpenTelemetry environment variables.
///
/// This class provides methods for reading standard OpenTelemetry environment
/// variables and applying their configuration to the SDK.
///
/// OpenTelemetry standard environment variables:
/// https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
class OTelEnv {
  /// Environment variable names
  /// Log level for the OTelLog class (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
  static const String logLevelEnv = 'OTEL_LOG_LEVEL';

  /// Enable logging of metrics (1, true, yes, on)
  static const String enableMetricsLogEnv = 'OTEL_LOG_METRICS';

  /// Enable logging of spans (1, true, yes, on)
  static const String enableSpansLogEnv = 'OTEL_LOG_SPANS';

  /// Enable logging of exports (1, true, yes, on)
  static const String enableExportLogEnv = 'OTEL_LOG_EXPORT';

  /// OTLP exporter environment variables
  /// The OTLP endpoint URL for all signals
  static const String otlpEndpointEnv = 'OTEL_EXPORTER_OTLP_ENDPOINT';

  /// The OTLP protocol to use (grpc, http/protobuf, http/json)
  static const String otlpProtocolEnv = 'OTEL_EXPORTER_OTLP_PROTOCOL';

  /// Additional headers for OTLP requests as comma-separated key=value pairs
  static const String otlpHeadersEnv = 'OTEL_EXPORTER_OTLP_HEADERS';

  /// Whether to use insecure connection for OTLP (true, false)
  static const String otlpInsecureEnv = 'OTEL_EXPORTER_OTLP_INSECURE';

  /// Timeout for OTLP requests in milliseconds
  static const String otlpTimeoutEnv = 'OTEL_EXPORTER_OTLP_TIMEOUT';

  /// Compression method for OTLP requests (gzip, none)
  static const String otlpCompressionEnv = 'OTEL_EXPORTER_OTLP_COMPRESSION';

  /// Certificate file path for secure connections
  static const String otlpCertificateEnv = 'OTEL_EXPORTER_OTLP_CERTIFICATE';

  /// Client key file path for mTLS
  static const String otlpClientKeyEnv = 'OTEL_EXPORTER_OTLP_CLIENT_KEY';

  /// Client certificate file path for mTLS
  static const String otlpClientCertificateEnv =
      'OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE';

  /// Service information environment variables
  /// The service name to use for telemetry
  static const String serviceNameEnv = 'OTEL_SERVICE_NAME';

  /// The service version to use for telemetry
  static const String serviceVersionEnv = 'OTEL_SERVICE_VERSION';

  /// Resource attributes environment variable
  /// Additional resource attributes as comma-separated key=value pairs
  static const String resourceAttributesEnv = 'OTEL_RESOURCE_ATTRIBUTES';

  /// Traces specific OTLP environment variables
  /// The exporter to use for traces (otlp, console, none)
  static const String tracesExporterEnv = 'OTEL_TRACES_EXPORTER';

  /// Traces-specific endpoint URL
  static const String tracesEndpointEnv = 'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT';

  /// Traces-specific protocol
  static const String tracesProtocolEnv = 'OTEL_EXPORTER_OTLP_TRACES_PROTOCOL';

  /// Traces-specific headers
  static const String tracesHeadersEnv = 'OTEL_EXPORTER_OTLP_TRACES_HEADERS';

  /// Traces-specific insecure setting
  static const String tracesInsecureEnv = 'OTEL_EXPORTER_OTLP_TRACES_INSECURE';

  /// Traces-specific timeout
  static const String tracesTimeoutEnv = 'OTEL_EXPORTER_OTLP_TRACES_TIMEOUT';

  /// Traces-specific compression
  static const String tracesCompressionEnv =
      'OTEL_EXPORTER_OTLP_TRACES_COMPRESSION';

  /// Traces-specific certificate
  static const String tracesCertificateEnv =
      'OTEL_EXPORTER_OTLP_TRACES_CERTIFICATE';

  /// Traces-specific client key
  static const String tracesClientKeyEnv =
      'OTEL_EXPORTER_OTLP_TRACES_CLIENT_KEY';

  /// Traces-specific client certificate
  static const String tracesClientCertificateEnv =
      'OTEL_EXPORTER_OTLP_TRACES_CLIENT_CERTIFICATE';

  /// Metrics specific OTLP environment variables
  /// The exporter to use for metrics (otlp, console, none, prometheus)
  static const String metricsExporterEnv = 'OTEL_METRICS_EXPORTER';

  /// Metrics-specific endpoint URL
  static const String metricsEndpointEnv =
      'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT';

  /// Metrics-specific protocol
  static const String metricsProtocolEnv =
      'OTEL_EXPORTER_OTLP_METRICS_PROTOCOL';

  /// Metrics-specific headers
  static const String metricsHeadersEnv = 'OTEL_EXPORTER_OTLP_METRICS_HEADERS';

  /// Metrics-specific insecure setting
  static const String metricsInsecureEnv =
      'OTEL_EXPORTER_OTLP_METRICS_INSECURE';

  /// Metrics-specific timeout
  static const String metricsTimeoutEnv = 'OTEL_EXPORTER_OTLP_METRICS_TIMEOUT';

  /// Metrics-specific compression
  static const String metricsCompressionEnv =
      'OTEL_EXPORTER_OTLP_METRICS_COMPRESSION';

  /// Metrics-specific certificate
  static const String metricsCertificateEnv =
      'OTEL_EXPORTER_OTLP_METRICS_CERTIFICATE';

  /// Metrics-specific client key
  static const String metricsClientKeyEnv =
      'OTEL_EXPORTER_OTLP_METRICS_CLIENT_KEY';

  /// Metrics-specific client certificate
  static const String metricsClientCertificateEnv =
      'OTEL_EXPORTER_OTLP_METRICS_CLIENT_CERTIFICATE';

  /// Logs specific OTLP environment variables
  /// The exporter to use for logs (otlp, console, none)
  static const String logsExporterEnv = 'OTEL_LOGS_EXPORTER';

  /// Logs-specific endpoint URL
  static const String logsEndpointEnv = 'OTEL_EXPORTER_OTLP_LOGS_ENDPOINT';

  /// Logs-specific protocol
  static const String logsProtocolEnv = 'OTEL_EXPORTER_OTLP_LOGS_PROTOCOL';

  /// Logs-specific headers
  static const String logsHeadersEnv = 'OTEL_EXPORTER_OTLP_LOGS_HEADERS';

  /// Logs-specific insecure setting
  static const String logsInsecureEnv = 'OTEL_EXPORTER_OTLP_LOGS_INSECURE';

  /// Logs-specific timeout
  static const String logsTimeoutEnv = 'OTEL_EXPORTER_OTLP_LOGS_TIMEOUT';

  /// Logs-specific compression
  static const String logsCompressionEnv =
      'OTEL_EXPORTER_OTLP_LOGS_COMPRESSION';

  /// Logs-specific certificate
  static const String logsCertificateEnv =
      'OTEL_EXPORTER_OTLP_LOGS_CERTIFICATE';

  /// Logs-specific client key
  static const String logsClientKeyEnv = 'OTEL_EXPORTER_OTLP_LOGS_CLIENT_KEY';

  /// Logs-specific client certificate
  static const String logsClientCertificateEnv =
      'OTEL_EXPORTER_OTLP_LOGS_CLIENT_CERTIFICATE';

  /// Initialize logging based on environment variables.
  ///
  /// This method reads the logging-related environment variables
  /// and configures the OTelLog accordingly.
  static void initializeLogging() {
    // Set log level based on environment variable
    final logLevel = _getEnv(logLevelEnv)?.toLowerCase();
    if (logLevel != null) {
      switch (logLevel) {
        case 'trace':
          OTelLog.enableTraceLogging();
          OTelLog.logFunction = print;
          break;
        case 'debug':
          OTelLog.enableDebugLogging();
          OTelLog.logFunction = print;
          break;
        case 'info':
          OTelLog.enableInfoLogging();
          OTelLog.logFunction = print;
          break;
        case 'warn':
          OTelLog.enableWarnLogging();
          OTelLog.logFunction = print;
          break;
        case 'error':
          OTelLog.enableErrorLogging();
          OTelLog.logFunction = print;
          break;
        case 'fatal':
          OTelLog.enableFatalLogging();
          OTelLog.logFunction = print;
          break;
        default:
          // No change to logging if level not recognized
          break;
      }
    }

    // Enable metrics logging based on environment variable
    if (_getEnvBool(enableMetricsLogEnv)) {
      OTelLog.metricLogFunction = print;
    }

    // Enable spans logging based on environment variable
    if (_getEnvBool(enableSpansLogEnv)) {
      OTelLog.spanLogFunction = print;
    }

    // Enable export logging based on environment variable
    if (_getEnvBool(enableExportLogEnv)) {
      OTelLog.exportLogFunction = print;
    }
  }

  /// Get OTLP configuration from environment variables.
  ///
  /// Returns a map containing the OTLP configuration read from environment variables.
  /// Signal-specific variables take precedence over general ones.
  static Map<String, dynamic> getOtlpConfig({String signal = 'traces'}) {
    final config = <String, dynamic>{};

    // Get endpoint (signal-specific takes precedence)
    String? endpoint;
    switch (signal) {
      case 'traces':
        endpoint = _getEnv(tracesEndpointEnv) ?? _getEnv(otlpEndpointEnv);
        break;
      case 'metrics':
        endpoint = _getEnv(metricsEndpointEnv) ?? _getEnv(otlpEndpointEnv);
        break;
      case 'logs':
        endpoint = _getEnv(logsEndpointEnv) ?? _getEnv(otlpEndpointEnv);
        break;
    }
    if (endpoint != null) {
      config['endpoint'] = endpoint;
    }

    // Get protocol (signal-specific takes precedence)
    String? protocol;
    switch (signal) {
      case 'traces':
        protocol = _getEnv(tracesProtocolEnv) ?? _getEnv(otlpProtocolEnv);
        break;
      case 'metrics':
        protocol = _getEnv(metricsProtocolEnv) ?? _getEnv(otlpProtocolEnv);
        break;
      case 'logs':
        protocol = _getEnv(logsProtocolEnv) ?? _getEnv(otlpProtocolEnv);
        break;
    }
    if (protocol != null) {
      config['protocol'] = protocol;
    }

    // Get headers (signal-specific takes precedence)
    String? headers;
    switch (signal) {
      case 'traces':
        headers = _getEnv(tracesHeadersEnv) ?? _getEnv(otlpHeadersEnv);
        break;
      case 'metrics':
        headers = _getEnv(metricsHeadersEnv) ?? _getEnv(otlpHeadersEnv);
        break;
      case 'logs':
        headers = _getEnv(logsHeadersEnv) ?? _getEnv(otlpHeadersEnv);
        break;
    }
    if (headers != null) {
      config['headers'] = _parseHeaders(headers);
    }

    // Get insecure setting (signal-specific takes precedence)
    bool? insecure;
    switch (signal) {
      case 'traces':
        insecure = _getEnvBoolNullable(tracesInsecureEnv) ??
            _getEnvBoolNullable(otlpInsecureEnv);
        break;
      case 'metrics':
        insecure = _getEnvBoolNullable(metricsInsecureEnv) ??
            _getEnvBoolNullable(otlpInsecureEnv);
        break;
      case 'logs':
        insecure = _getEnvBoolNullable(logsInsecureEnv) ??
            _getEnvBoolNullable(otlpInsecureEnv);
        break;
    }
    if (insecure != null) {
      config['insecure'] = insecure;
    }

    // Get timeout (signal-specific takes precedence)
    String? timeout;
    switch (signal) {
      case 'traces':
        timeout = _getEnv(tracesTimeoutEnv) ?? _getEnv(otlpTimeoutEnv);
        break;
      case 'metrics':
        timeout = _getEnv(metricsTimeoutEnv) ?? _getEnv(otlpTimeoutEnv);
        break;
      case 'logs':
        timeout = _getEnv(logsTimeoutEnv) ?? _getEnv(otlpTimeoutEnv);
        break;
    }
    if (timeout != null) {
      final timeoutMs = int.tryParse(timeout);
      if (timeoutMs != null) {
        config['timeout'] = Duration(milliseconds: timeoutMs);
      }
    }

    // Get compression (signal-specific takes precedence)
    String? compression;
    switch (signal) {
      case 'traces':
        compression =
            _getEnv(tracesCompressionEnv) ?? _getEnv(otlpCompressionEnv);
        break;
      case 'metrics':
        compression =
            _getEnv(metricsCompressionEnv) ?? _getEnv(otlpCompressionEnv);
        break;
      case 'logs':
        compression =
            _getEnv(logsCompressionEnv) ?? _getEnv(otlpCompressionEnv);
        break;
    }
    if (compression != null) {
      config['compression'] = compression;
    }

    // Get certificate (signal-specific takes precedence)
    String? certificate;
    switch (signal) {
      case 'traces':
        certificate =
            _getEnv(tracesCertificateEnv) ?? _getEnv(otlpCertificateEnv);
        break;
      case 'metrics':
        certificate =
            _getEnv(metricsCertificateEnv) ?? _getEnv(otlpCertificateEnv);
        break;
      case 'logs':
        certificate =
            _getEnv(logsCertificateEnv) ?? _getEnv(otlpCertificateEnv);
        break;
    }
    if (certificate != null) {
      config['certificate'] = certificate;
    }

    // Get client key (signal-specific takes precedence)
    String? clientKey;
    switch (signal) {
      case 'traces':
        clientKey = _getEnv(tracesClientKeyEnv) ?? _getEnv(otlpClientKeyEnv);
        break;
      case 'metrics':
        clientKey = _getEnv(metricsClientKeyEnv) ?? _getEnv(otlpClientKeyEnv);
        break;
      case 'logs':
        clientKey = _getEnv(logsClientKeyEnv) ?? _getEnv(otlpClientKeyEnv);
        break;
    }
    if (clientKey != null) {
      config['clientKey'] = clientKey;
    }

    // Get client certificate (signal-specific takes precedence)
    String? clientCertificate;
    switch (signal) {
      case 'traces':
        clientCertificate = _getEnv(tracesClientCertificateEnv) ??
            _getEnv(otlpClientCertificateEnv);
        break;
      case 'metrics':
        clientCertificate = _getEnv(metricsClientCertificateEnv) ??
            _getEnv(otlpClientCertificateEnv);
        break;
      case 'logs':
        clientCertificate = _getEnv(logsClientCertificateEnv) ??
            _getEnv(otlpClientCertificateEnv);
        break;
    }
    if (clientCertificate != null) {
      config['clientCertificate'] = clientCertificate;
    }

    return config;
  }

  /// Get service configuration from environment variables.
  ///
  /// Returns a map containing the service configuration read from environment variables.
  static Map<String, dynamic> getServiceConfig() {
    final config = <String, dynamic>{};

    final serviceName = _getEnv(serviceNameEnv);
    if (serviceName != null) {
      config['serviceName'] = serviceName;
    }

    final serviceVersion = _getEnv(serviceVersionEnv);
    if (serviceVersion != null) {
      config['serviceVersion'] = serviceVersion;
    }

    return config;
  }

  /// Get resource attributes from environment variables.
  ///
  /// Parses the OTEL_RESOURCE_ATTRIBUTES environment variable which should be
  /// a comma-separated list of key=value pairs.
  static Map<String, Object> getResourceAttributes() {
    final resourceAttrs = <String, Object>{};

    final resourceStr = _getEnv(resourceAttributesEnv);
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

  /// Get the selected exporter for a signal.
  ///
  /// Returns the exporter type configured via environment variables.
  static String? getExporter({String signal = 'traces'}) {
    switch (signal) {
      case 'traces':
        return _getEnv(tracesExporterEnv);
      case 'metrics':
        return _getEnv(metricsExporterEnv);
      case 'logs':
        return _getEnv(logsExporterEnv);
      default:
        return null;
    }
  }

  /// Parse headers from the environment variable format.
  ///
  /// Headers are expected in the format: key1=value1,key2=value2
  static Map<String, String> _parseHeaders(String headerStr) {
    final headers = <String, String>{};

    final pairs = headerStr.split(',');
    for (final pair in pairs) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        headers[parts[0].trim()] = parts[1].trim();
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
    final value = _getEnv(name)?.toLowerCase();
    return value == '1' || value == 'true' || value == 'yes' || value == 'on';
  }

  /// Get boolean environment variable value that can be null.
  ///
  /// This method converts an environment variable value to a boolean.
  /// Values of '1', 'true', 'yes', and 'on' (case-insensitive) are considered true.
  /// Values of '0', 'false', 'no', and 'off' (case-insensitive) are considered false.
  ///
  /// @param name The name of the environment variable
  /// @return true/false if the environment variable has a valid boolean value, null otherwise
  static bool? _getEnvBoolNullable(String name) {
    final value = _getEnv(name)?.toLowerCase();
    if (value == null) return null;

    if (value == '1' || value == 'true' || value == 'yes' || value == 'on') {
      return true;
    } else if (value == '0' ||
        value == 'false' ||
        value == 'no' ||
        value == 'off') {
      return false;
    }

    return null;
  }
}
