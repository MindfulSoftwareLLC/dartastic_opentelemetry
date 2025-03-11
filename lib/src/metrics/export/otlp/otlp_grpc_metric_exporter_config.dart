// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

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

  /// Creates a new configuration for the OtlpGrpcMetricExporter.
  OtlpGrpcMetricExporterConfig({
    required this.endpoint,
    this.insecure = false,
    this.headers,
    this.timeoutMillis = 10000,
  });
}
