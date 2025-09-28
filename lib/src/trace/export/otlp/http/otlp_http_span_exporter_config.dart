// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Configuration for the OpenTelemetry span exporter that exports spans using OTLP over HTTP/protobuf
class OtlpHttpExporterConfig {
  /// The endpoint to export spans to (e.g., 'http://localhost:4318/v1/traces')
  /// Default: 'http://localhost:4318'
  final String endpoint;

  /// Additional HTTP headers to include in the export requests
  final Map<String, String> headers;

  /// The timeout for export HTTP requests
  /// Default: 10 seconds
  final Duration timeout;

  /// Whether to use gzip compression for the HTTP body
  /// Default: false
  final bool compression;

  /// Maximum number of retries for failed export requests
  /// Default: 3
  final int maxRetries;

  /// Base delay for exponential backoff when retrying
  /// Default: 100 milliseconds
  final Duration baseDelay;

  /// Maximum delay for exponential backoff when retrying
  /// Default: 1 second
  final Duration maxDelay;

  /// Creates a new configuration for the OTLP HTTP span exporter
  ///
  /// The endpoint must be a valid URL and will default to http://localhost:4318
  /// if not specified. The path '/v1/traces' will be appended if not already present.
  OtlpHttpExporterConfig({
    String endpoint = 'http://localhost:4318',
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 10),
    this.compression = false,
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 100),
    Duration maxDelay = const Duration(seconds: 1),
  })  : endpoint = _validateEndpoint(endpoint),
        headers = _validateHeaders(headers ?? {}),
        timeout = _validateTimeout(timeout),
        maxRetries = _validateRetries(maxRetries),
        baseDelay = _validateDelay(baseDelay, 'baseDelay'),
        maxDelay = _validateDelay(maxDelay, 'maxDelay') {
    if (baseDelay.compareTo(maxDelay) > 0) {
      throw ArgumentError('maxDelay cannot be less than baseDelay');
    }
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

    // Ensure endpoint starts with http:// or https://
    final lcEndpoint = endpoint.toLowerCase();
    if (!lcEndpoint.startsWith('http://') &&
        !lcEndpoint.startsWith('https://')) {
      endpoint = 'http://$endpoint';
    }

    // Default port for OTLP/HTTP is 4318
    if (lcEndpoint == 'http://localhost' ||
        lcEndpoint == 'http://127.0.0.1' ||
        lcEndpoint == 'https://localhost' ||
        lcEndpoint == 'https://127.0.0.1') {
      return '$endpoint:4318';
    }

    // Handle URL format validation
    try {
      final uri = Uri.parse(endpoint);
      if (uri.host.isEmpty) {
        throw ArgumentError('Invalid host in endpoint: $endpoint');
      }

      // If there's no port and no explicit path, ensure we have the correct default port
      if (uri.port == 0 && !endpoint.contains(':') && uri.path.isEmpty) {
        return '${uri.scheme}://${uri.host}:4318';
      }

      return endpoint;
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw ArgumentError('Invalid URL format in endpoint: $endpoint');
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
}
