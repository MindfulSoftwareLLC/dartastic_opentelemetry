// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import '../../../trace/export/otlp/certificate_utils.dart';

/// Configuration for the OtlpGrpcMetricExporter.
class OtlpGrpcMetricExporterConfig {
  /// The OTLP endpoint to export to (e.g. http://localhost:4317).
  final String endpoint;

  /// Whether to use an insecure connection (HTTP instead of HTTPS).
  final bool insecure;

  /// Headers to include in the OTLP request.
  final Map<String, String>? headers;

  /// Timeout for export operations in milliseconds.
  final int timeoutMillis;

  /// Path to the TLS certificate file for secure connections.
  final String? certificate;

  /// Path to the client key file for secure connections with client authentication.
  final String? clientKey;

  /// Path to the client certificate file for secure connections with client authentication.
  final String? clientCertificate;

  /// Whether to enable gRPC compression for requests.
  final bool compression;

  /// Creates a new configuration for the OtlpGrpcMetricExporter.
  OtlpGrpcMetricExporterConfig({
    required this.endpoint,
    this.insecure = false,
    this.headers,
    this.timeoutMillis = 10000,
    this.certificate,
    this.clientKey,
    this.clientCertificate,
    this.compression = false,
  }) {
    _validateCertificates(certificate, clientKey, clientCertificate);
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
