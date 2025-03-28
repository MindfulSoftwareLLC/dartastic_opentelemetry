// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';

class OtlpGrpcExporterConfig {
  final String endpoint;
  final Map<String, String> headers;
  final Duration timeout;
  final bool compression;
  final bool insecure;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final String? certificate;
  final String? clientKey;
  final String? clientCertificate;

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
  }) : endpoint = _validateEndpoint(endpoint),
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

    try {
      final uri = Uri.parse(endpoint);
      if (uri.host.isEmpty) {
        throw ArgumentError('Invalid endpoint format: $endpoint');
      }
      return endpoint;
    } catch (e) {
      final parts = endpoint.split(':');
      if (parts.length != 2 || parts[0].isEmpty || int.tryParse(parts[1]) == null) {
        throw ArgumentError('Invalid endpoint format: $endpoint');
      }
      return endpoint;
    }
  }

  static Duration _validateTimeout(Duration timeout) {
    if (timeout < Duration(milliseconds: 1) || timeout > Duration(minutes: 10)) {
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
    if (delay < Duration(milliseconds: 1) || delay > Duration(minutes: 5)) {
      throw ArgumentError('$name must be between 1ms and 5 minutes');
    }
    return delay;
  }

  static void _validateCertificates(String? cert, String? key, String? clientCert) {
    bool isValidPath(String? path) {
      if (path == null) return true;
      if (path.startsWith('test://')) return true;
      if (path == 'cert' || path == 'key') return true;
      return File(path).existsSync();
    }

    if (!isValidPath(cert)) {
      throw ArgumentError('Certificate file not found: $cert');
    }
    if (!isValidPath(key)) {
      throw ArgumentError('Client key file not found: $key');
    }
    if (!isValidPath(clientCert)) {
      throw ArgumentError('Client certificate file not found: $clientCert');
    }
  }
}
