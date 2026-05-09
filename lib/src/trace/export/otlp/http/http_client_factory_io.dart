// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Native (`dart:io`) implementation of the HTTP client factory used by
// the OTLP/HTTP exporters. Builds an `IOClient` wrapping an `HttpClient`
// configured with custom certificates via [CertificateUtils] when the
// caller has provided any.

import 'dart:io';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../certificate_utils_io.dart';

/// Builds an [http.Client] for the OTLP/HTTP exporters.
///
/// If any of [certificate] / [clientKey] / [clientCertificate] are
/// non-null, builds an `HttpClient` with a custom `SecurityContext`
/// loaded from those files and wraps it in an `IOClient`. Otherwise
/// returns the default `http.Client()`.
///
/// On any error constructing the secure client, falls back to the
/// default client so the exporter still runs (logs an error).
http.Client createOtlpHttpClient({
  required String exporterName,
  String? certificate,
  String? clientKey,
  String? clientCertificate,
}) {
  if (certificate == null && clientKey == null && clientCertificate == null) {
    return http.Client();
  }

  try {
    final context = CertificateUtils.createSecurityContext(
      certificate: certificate,
      clientKey: clientKey,
      clientCertificate: clientCertificate,
    );
    if (context == null) {
      return http.Client();
    }
    return IOClient(HttpClient(context: context));
  } catch (e) {
    if (OTelLog.isError()) {
      OTelLog.error(
        '$exporterName: Failed to create HTTP client with certificates: $e',
      );
    }
    return http.Client();
  }
}
