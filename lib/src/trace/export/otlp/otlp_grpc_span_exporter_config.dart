// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'certificate_utils.dart';

/// Configuration for the OtlpGrpcSpanExporter.
///
/// This class configures how the OTLP gRPC span exporter connects to and communicates
/// with the OpenTelemetry collector or backend. It allows customization of connection
/// parameters such as endpoint, security settings, timeouts, and retry behavior.
class OtlpGrpcExporterConfig {
  /// The endpoint to which the exporter will send spans, in the format 'host:port'.
  final String endpoint;

  /// Custom headers to include in each gRPC request, for authentication or metadata.
  final Map<String, String> headers;

  /// Timeout for gRPC operations, after which they'll fail.
  final Duration timeout;

  /// Whether to enable gRPC compression for requests.
  final bool compression;

  /// Whether to use an insecure connection (true) or TLS (false).
  final bool insecure;

  /// Maximum number of retry attempts for failed exports.
  final int maxRetries;

  /// Base delay for retry backoff calculation.
  final Duration baseDelay;

  /// Maximum delay between retry attempts.
  final Duration maxDelay;

  /// Path to the TLS certificate file for secure connections.
  final String? certificate;

  /// Path to the client key file for secure connections with client authentication.
  final String? clientKey;

  /// Path to the client certificate file for secure connections with client authentication.
  final String? clientCertificate;

  /// Creates a new OtlpGrpcExporterConfig with the specified parameters.
  ///
  /// This configuration controls the connection and behavior settings for the
  /// OTLP gRPC exporter.
  ///
  /// @param endpoint The endpoint to connect to (default: localhost:4317)
  /// @param headers Custom headers to include in the requests
  /// @param timeout Timeout for gRPC operations
  /// @param compression Whether to enable gRPC compression
  /// @param insecure Whether to use an insecure connection
  /// @param maxRetries Maximum number of retry attempts
  /// @param baseDelay Base delay for retry backoff
  /// @param maxDelay Maximum delay between retry attempts
  /// @param certificate Path to the TLS certificate file
  /// @param clientKey Path to the client key file
  /// @param clientCertificate Path to the client certificate file
  OtlpGrpcExporterConfig({
    String endpoint = 'localhost:4317',
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 10),
    this.compression = false,
    this.insecure = false,
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 100),
    Duration maxDelay = const Duration(seconds: 1),
    this.certificate,
    this.clientKey,
    this.clientCertificate,
  })  : endpoint = _validateEndpoint(endpoint),
        headers = _validateHeaders(headers ?? {}),
        timeout = _validateTimeout(timeout),
        maxRetries = _validateRetries(maxRetries),
        baseDelay = _validateDelay(baseDelay, 'baseDelay'),
        maxDelay = _validateDelay(maxDelay, 'maxDelay') {
    if (baseDelay.compareTo(maxDelay) > 0) {
      throw ArgumentError('maxDelay cannot be less than baseDelay');
    }
    _validateCertificates(certificate, clientKey, clientCertificate);
  }

  static Map<String, String> _validateHeaders(Map<String, String> headers) {
    final normalized = <String, String>{};
    for (final entry in headers.entries) {
      if (entry.key.isEmpty || entry.value.isEmpty) {
        throw ArgumentError('Header keys and values cannot be empty');
      }
      normalized[entry.key.toLowerCase()] = entry.value;
    }
    return normalized;
  }

  static String _validateEndpoint(String endpoint) {
    if (endpoint.isEmpty) {
      throw ArgumentError('Endpoint cannot be empty');
    }

    // Handle common localhost variants and validate basic format
    endpoint = endpoint.trim();

    // First check for invalid formats
    if (endpoint.contains(' ')) {
      throw ArgumentError('Endpoint cannot contain spaces: $endpoint');
    }

    // Check for specific invalid formats that might parse but are invalid
    if (endpoint.contains(':port') || endpoint.contains('://port')) {
      throw ArgumentError('Invalid port specification in endpoint: $endpoint');
    }

    final lcEndpoint = endpoint.toLowerCase();
    if (lcEndpoint == 'localhost' || lcEndpoint == '127.0.0.1') {
      return '$endpoint:4317'; // Add default port if missing
    }

    // Handle URL format validation more carefully
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      try {
        final uri = Uri.parse(endpoint);
        if (uri.host.isEmpty) {
          throw ArgumentError('Invalid host in endpoint: $endpoint');
        }
        if (uri.port == 0 && !endpoint.contains(':')) {
          // No port specified in URL format, add default
          return '${uri.scheme}://${uri.host}:4317${uri.path}';
        }
        if (uri.port == 0 &&
            endpoint.contains(':') &&
            !endpoint.contains('://:')) {
          // Port part exists but might be invalid
          final portStr = endpoint.split(':').last;
          if (int.tryParse(portStr) == null) {
            throw ArgumentError(
                'Invalid port format in endpoint URL: $endpoint');
          }
        }
        return endpoint;
      } catch (e) {
        if (e is ArgumentError) rethrow;
        throw ArgumentError('Invalid URL format in endpoint: $endpoint');
      }
    }

    // Try to parse as URI or host:port
    try {
      final parts = endpoint.split(':');
      if (parts.length == 1 && parts[0].isNotEmpty) {
        // Only host provided, add default port
        return '${parts[0]}:4317';
      } else if (parts.length == 2 && parts[0].isNotEmpty) {
        // Validate port is a number if specified
        if (parts[1].isEmpty) {
          throw ArgumentError('Invalid port format in endpoint: $endpoint');
        }
        if (int.tryParse(parts[1]) == null) {
          throw ArgumentError('Invalid port format in endpoint: $endpoint');
        }
        // Host and port provided
        return endpoint;
      }

      throw ArgumentError(
          'Invalid endpoint format: $endpoint. Expected format: "host:port" or a valid URI');
    } catch (e) {
      if (e is ArgumentError) rethrow; // Re-throw our own errors

      // Any other parsing error
      throw ArgumentError(
          'Invalid endpoint format: $endpoint. Expected format: "host:port" or a valid URI');
    }
  }

  static Duration _validateTimeout(Duration timeout) {
    if (timeout < const Duration(milliseconds: 1) ||
        timeout > const Duration(minutes: 10)) {
      throw ArgumentError('Timeout must be between 1ms and 10 minutes');
    }
    return timeout;
  }

  static int _validateRetries(int retries) {
    if (retries < 0) {
      throw ArgumentError('maxRetries cannot be negative');
    }
    return retries;
  }

  static Duration _validateDelay(Duration delay, String name) {
    if (delay < const Duration(milliseconds: 1) ||
        delay > const Duration(minutes: 5)) {
      throw ArgumentError('$name must be between 1ms and 5 minutes');
    }
    return delay;
  }

  static void _validateCertificates(
      String? cert, String? key, String? clientCert) {
    CertificateUtils.validateCertificates(
      certificate: cert,
      clientKey: key,
      clientCertificate: clientCert,
    );
  }
}
