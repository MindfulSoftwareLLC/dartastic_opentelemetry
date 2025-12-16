// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import '../../../trace/export/otlp/certificate_utils.dart';

/// Configuration for the OpenTelemetry log record exporter that exports logs using OTLP over gRPC.
class OtlpGrpcLogRecordExporterConfig {
  /// The endpoint to export logs to (e.g., 'localhost:4317').
  /// Default: 'localhost:4317'
  final String endpoint;

  /// Additional gRPC headers to include in the export requests.
  final Map<String, String> headers;

  /// The timeout for export gRPC requests.
  /// Default: 10 seconds
  final Duration timeout;

  /// Whether to use gzip compression for the gRPC messages.
  /// Default: false
  final bool compression;

  /// Whether to use insecure credentials for the gRPC channel.
  /// Default: true (for development)
  final bool insecure;

  /// Maximum number of retries for failed export requests.
  /// Default: 3
  final int maxRetries;

  /// Base delay for exponential backoff when retrying.
  /// Default: 100 milliseconds
  final Duration baseDelay;

  /// Maximum delay for exponential backoff when retrying.
  /// Default: 1 second
  final Duration maxDelay;

  /// Path to the TLS certificate file for secure connections.
  final String? certificate;

  /// Path to the client key file for secure connections with client authentication.
  final String? clientKey;

  /// Path to the client certificate file for secure connections with client authentication.
  final String? clientCertificate;

  /// Creates a new configuration for the OTLP gRPC log record exporter.
  ///
  /// The endpoint should be in the format 'host:port'. Default port is 4317.
  OtlpGrpcLogRecordExporterConfig({
    String endpoint = 'localhost:4317',
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 10),
    this.compression = false,
    this.insecure = true,
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

    endpoint = endpoint.trim();

    if (endpoint.contains(' ')) {
      throw ArgumentError('Endpoint cannot contain spaces: $endpoint');
    }

    // Strip http:// or https:// if present (gRPC endpoints don't use these)
    endpoint = endpoint
        .replaceAll(RegExp(r'^http://'), '')
        .replaceAll(RegExp(r'^https://'), '');

    // Add default port if not specified
    if (!endpoint.contains(':')) {
      endpoint = '$endpoint:4317';
    }

    return endpoint;
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
