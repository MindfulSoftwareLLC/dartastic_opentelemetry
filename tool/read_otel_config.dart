#!/usr/bin/env dart
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
    print('  otlp [signal]    - Get OTLP config for signal (traces, metrics, logs, or general)');
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
  print(jsonEncode(config));
}

void _printResourceAttributes() {
  final attrs = OTelEnv.getResourceAttributes();
  print(jsonEncode(attrs));
}

void _printOtlpConfig(String? signal) {
  final config = signal != null 
      ? OTelEnv.getOtlpConfig(signal: signal)
      : OTelEnv.getOtlpConfig();
  
  // Convert headers map to JSON-serializable format
  if (config['headers'] != null) {
    final headers = config['headers'] as Map<String, String>;
    config['headers'] = headers;
  }
  
  print(jsonEncode(config));
}

void _printHeaders(String? signal) {
  final config = signal != null
      ? OTelEnv.getOtlpConfig(signal: signal)
      : OTelEnv.getOtlpConfig();
  
  final headers = config['headers'] as Map<String, String>?;
  if (headers != null) {
    print(jsonEncode(headers));
  } else {
    print('{}');
  }
}
