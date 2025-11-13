// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'env_constants.dart';
import 'environment_service.dart';

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
  /// this method will preserve it and only update the log level.
  /// This allows tests to capture logs while still respecting
  /// environment variable configuration.
  static void initializeLogging() {
    // Save the current log function to check if it's custom
    final existingLogFunction = OTelLog.logFunction;

    // A custom function is one that's not null and not the default print function
    final hasCustomLogFunction =
        existingLogFunction != null && existingLogFunction != print;

    // Set log level based on environment variable
    final logLevel = _getEnv(otelLogLevel)?.toLowerCase();
    if (logLevel != null) {
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

      // Only set to print if no custom function is already configured
      if (!hasCustomLogFunction) {
        OTelLog.logFunction = print;
      }
    }

    // Enable metrics logging based on environment variable
    if (_getEnvBool(otelLogMetrics) && OTelLog.metricLogFunction == null) {
      OTelLog.metricLogFunction = print;
    }

    // Enable spans logging based on environment variable
    if (_getEnvBool(otelLogSpans) && OTelLog.spanLogFunction == null) {
      OTelLog.spanLogFunction = print;
    }

    // Enable export logging based on environment variable
    if (_getEnvBool(otelLogExport) && OTelLog.exportLogFunction == null) {
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
    if (endpoint != null) {
      config['endpoint'] = endpoint;
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
    if (protocol != null) {
      config['protocol'] = protocol;
    }

    // Get headers (signal-specific takes precedence)
    String? headers;
    switch (signal) {
      case 'traces':
        headers = _getEnv(otelExporterOtlpTracesHeaders) ??
            _getEnv(otelExporterOtlpHeaders);
        break;
      case 'metrics':
        headers = _getEnv(otelExporterOtlpMetricsHeaders) ??
            _getEnv(otelExporterOtlpHeaders);
        break;
      case 'logs':
        headers = _getEnv(otelExporterOtlpLogsHeaders) ??
            _getEnv(otelExporterOtlpHeaders);
        break;
    }
    if (headers != null) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('OTelEnv: Parsing $signal headers from env: $headers');
      }
      final parsedHeaders = _parseHeaders(headers);
      if (OTelLog.isDebug()) {
        OTelLog.debug('OTelEnv: Parsed ${parsedHeaders.length} header(s)');
        parsedHeaders.forEach((key, value) {
          if (key.toLowerCase() == 'authorization') {
            OTelLog.debug('  $key: [REDACTED - length: ${value.length}]');
          } else {
            OTelLog.debug('  $key: $value');
          }
        });
      }
      config['headers'] = parsedHeaders;
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
    if (insecure != null) {
      config['insecure'] = insecure;
    }

    // Get timeout (signal-specific takes precedence)
    String? timeout;
    switch (signal) {
      case 'traces':
        timeout = _getEnv(otelExporterOtlpTracesTimeout) ??
            _getEnv(otelExporterOtlpTimeout);
        break;
      case 'metrics':
        timeout = _getEnv(otelExporterOtlpMetricsTimeout) ??
            _getEnv(otelExporterOtlpTimeout);
        break;
      case 'logs':
        timeout = _getEnv(otelExporterOtlpLogsTimeout) ??
            _getEnv(otelExporterOtlpTimeout);
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
    if (compression != null) {
      config['compression'] = compression;
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
    if (certificate != null) {
      config['certificate'] = certificate;
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
    if (clientKey != null) {
      config['clientKey'] = clientKey;
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
    if (clientCertificate != null) {
      config['clientCertificate'] = clientCertificate;
    }

    return config;
  }

  /// Get service configuration from environment variables.
  ///
  /// Returns a map containing the service configuration read from environment variables.
  ///
  /// Handles the spec precedence rules:
  /// - If `service.name` is in OTEL_RESOURCE_ATTRIBUTES, it's used as the base value
  /// - OTEL_SERVICE_NAME takes precedence over `service.name` in OTEL_RESOURCE_ATTRIBUTES
  /// - `service.version` comes from OTEL_RESOURCE_ATTRIBUTES only
  static Map<String, dynamic> getServiceConfig() {
    final config = <String, dynamic>{};

    // First, parse service.name and service.version from OTEL_RESOURCE_ATTRIBUTES
    final resourceStr = _getEnv(otelResourceAttributes);
    if (resourceStr != null) {
      final pairs = resourceStr.split(',');
      for (final pair in pairs) {
        final equalIndex = pair.indexOf('=');
        if (equalIndex > 0 && equalIndex < pair.length - 1) {
          final key = pair.substring(0, equalIndex).trim();
          final value = pair.substring(equalIndex + 1).trim();

          if (key == 'service.name') {
            config['serviceName'] = value;
          } else if (key == 'service.version') {
            config['serviceVersion'] = value;
          }
        }
      }
    }

    // OTEL_SERVICE_NAME takes precedence over service.name from resource attributes
    final serviceName = _getEnv(otelServiceName);
    if (serviceName != null) {
      config['serviceName'] = serviceName;
    }

    return config;
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
