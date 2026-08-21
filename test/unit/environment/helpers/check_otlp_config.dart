// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper script: prints JSON of OTelEnv.getOtlpConfig() result.
// Run via subprocess with OTEL_EXPORTER_OTLP_* env vars set.
// Set CHECK_SIGNAL env var to control which signal to check (default: traces).

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  final signal = Platform.environment['CHECK_SIGNAL'] ?? 'traces';
  final config = OTelEnv.getOtlpConfig(signal: signal);

  // Convert record to JSON-serializable map
  final jsonConfig = <String, dynamic>{};
  if (config.endpoint != null) jsonConfig['endpoint'] = config.endpoint;
  if (config.protocol != null) jsonConfig['protocol'] = config.protocol;
  if (config.headers != null) jsonConfig['headers'] = config.headers;
  if (config.insecure != null) jsonConfig['insecure'] = config.insecure;
  if (config.timeout != null) {
    jsonConfig['timeout_ms'] = config.timeout!.inMilliseconds;
  }
  if (config.compression != null) {
    jsonConfig['compression'] = config.compression;
  }
  if (config.certificate != null) {
    jsonConfig['certificate'] = config.certificate;
  }
  if (config.clientKey != null) jsonConfig['clientKey'] = config.clientKey;
  if (config.clientCertificate != null) {
    jsonConfig['clientCertificate'] = config.clientCertificate;
  }

  print(jsonEncode(jsonConfig));
}
