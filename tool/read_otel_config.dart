#!/usr/bin/env dart
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// Utility to read OTelEnv configuration and output in parseable format
// Used by integration test scripts to verify environment variable parsing

import 'dart:convert';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('ERROR: No operation specified');
    print('Usage: read_otel_config.dart <operation> [args]');
    print('Operations:');
    print('  service          - Get service config');
    print('  resource         - Get resource attributes');
    print(
      '  otlp [signal]    - Get OTLP config for signal (traces, metrics, logs, or general)',
    );
    print('  headers [signal] - Get parsed headers for signal');
    return;
  }

  final operation = args[0];

  try {
    switch (operation) {
      case 'service':
        _printServiceConfig();
        break;
      case 'resource':
        _printResourceAttributes();
        break;
      case 'otlp':
        final signal = args.length > 1 ? args[1] : null;
        _printOtlpConfig(signal);
        break;
      case 'headers':
        final signal = args.length > 1 ? args[1] : null;
        _printHeaders(signal);
        break;
      default:
        print('ERROR: Unknown operation: $operation');
    }
  } catch (e) {
    print('ERROR: $e');
  }
}

void _printServiceConfig() {
  final config = OTelEnv.getServiceConfig();
  final jsonConfig = <String, dynamic>{};
  if (config.serviceName != null) {
    jsonConfig['serviceName'] = config.serviceName;
  }
  if (config.serviceVersion != null) {
    jsonConfig['serviceVersion'] = config.serviceVersion;
  }
  print(jsonEncode(jsonConfig));
}

void _printResourceAttributes() {
  final attrs = OTelEnv.getResourceAttributes();
  print(jsonEncode(attrs));
}

void _printOtlpConfig(String? signal) {
  final config = signal != null
      ? OTelEnv.getOtlpConfig(signal: signal)
      : OTelEnv.getOtlpConfig();

  // Convert record to JSON-serializable map
  final jsonConfig = <String, dynamic>{};
  if (config.endpoint != null) jsonConfig['endpoint'] = config.endpoint;
  if (config.protocol != null) jsonConfig['protocol'] = config.protocol;
  if (config.headers != null) jsonConfig['headers'] = config.headers;
  if (config.insecure != null) jsonConfig['insecure'] = config.insecure;
  if (config.timeout != null) {
    jsonConfig['timeout'] = config.timeout!.inMilliseconds;
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

void _printHeaders(String? signal) {
  final config = signal != null
      ? OTelEnv.getOtlpConfig(signal: signal)
      : OTelEnv.getOtlpConfig();

  final headers = config.headers;
  if (headers != null) {
    print(jsonEncode(headers));
  } else {
    print('{}');
  }
}
