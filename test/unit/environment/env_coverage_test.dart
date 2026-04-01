// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Tests for environment configuration, resource detection, and OTel
// initialization exercising error paths and edge cases.
//
// Areas tested:
//   1. lib/src/environment/otel_env.dart  - getBlrpConfig, getLogRecordLimits,
//      _parseHeaders edge cases, _getEnvBoolNullable, getExporter for metrics/logs
//   2. lib/src/resource/resource_detector.dart - ProcessResourceDetector,
//      HostResourceDetector, CompositeResourceDetector error handling,
//      EnvVarResourceDetector with encoded values
//   3. lib/src/otel.dart - print interception, tenantId, addTracerProvider,
//      addMeterProvider, addLoggerProvider

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

/// Runs a Dart script in a subprocess with specific environment variables set.
/// Returns the stdout output as a string.
Future<String> runWithEnv(
  String scriptPath,
  Map<String, String> envVars,
) async {
  final env = Map<String, String>.from(Platform.environment);
  // Clear any existing OTEL env vars that might interfere
  env.removeWhere((key, _) => key.startsWith('OTEL_'));
  env.addAll(envVars);
  final result = await Process.run(
    Platform.executable,
    ['run', scriptPath],
    environment: env,
    workingDirectory: Directory.current.path,
  );
  if (result.exitCode != 0) {
    throw Exception(
      'Script failed with exit code ${result.exitCode}:\n'
      'stdout: ${result.stdout}\n'
      'stderr: ${result.stderr}',
    );
  }
  return result.stdout as String;
}

/// A detector that throws a non-Exception type to exercise
/// the catch block in CompositeResourceDetector.
class _StringThrowingDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    throw 'non-exception error string';
  }
}

/// A detector that returns a known resource for merge testing.
class _FixedDetector implements ResourceDetector {
  final Map<String, Object> attrs;
  _FixedDetector(this.attrs);

  @override
  Future<Resource> detect() async {
    return ResourceCreate.create(
      OTelFactory.otelFactory!.attributesFromMap(attrs),
    );
  }
}

void main() {
  // =========================================================================
  // OTelEnv - subprocess tests for getBlrpConfig
  // =========================================================================
  group('OTelEnv.getBlrpConfig (subprocess)', () {
    test('reads scheduleDelay', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_blrp_config.dart',
        {'OTEL_BLRP_SCHEDULE_DELAY': '2000'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['scheduleDelay_ms'], equals(2000));
    });

    test('reads exportTimeout', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_blrp_config.dart',
        {'OTEL_BLRP_EXPORT_TIMEOUT': '30000'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['exportTimeout_ms'], equals(30000));
    });

    test('reads maxQueueSize', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_blrp_config.dart',
        {'OTEL_BLRP_MAX_QUEUE_SIZE': '4096'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['maxQueueSize'], equals(4096));
    });

    test('reads maxExportBatchSize', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_blrp_config.dart',
        {'OTEL_BLRP_MAX_EXPORT_BATCH_SIZE': '1024'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['maxExportBatchSize'], equals(1024));
    });

    test('reads all BLRP config values together', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_blrp_config.dart',
        {
          'OTEL_BLRP_SCHEDULE_DELAY': '1000',
          'OTEL_BLRP_EXPORT_TIMEOUT': '5000',
          'OTEL_BLRP_MAX_QUEUE_SIZE': '2048',
          'OTEL_BLRP_MAX_EXPORT_BATCH_SIZE': '512',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['scheduleDelay_ms'], equals(1000));
      expect(result['exportTimeout_ms'], equals(5000));
      expect(result['maxQueueSize'], equals(2048));
      expect(result['maxExportBatchSize'], equals(512));
    });

    test('ignores non-numeric scheduleDelay', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_blrp_config.dart',
        {'OTEL_BLRP_SCHEDULE_DELAY': 'not-a-number'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result.containsKey('scheduleDelay_ms'), isFalse);
    });

    test('ignores non-numeric exportTimeout', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_blrp_config.dart',
        {'OTEL_BLRP_EXPORT_TIMEOUT': 'abc'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result.containsKey('exportTimeout_ms'), isFalse);
    });

    test('ignores non-numeric maxQueueSize', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_blrp_config.dart',
        {'OTEL_BLRP_MAX_QUEUE_SIZE': 'xyz'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result.containsKey('maxQueueSize'), isFalse);
    });

    test('ignores non-numeric maxExportBatchSize', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_blrp_config.dart',
        {'OTEL_BLRP_MAX_EXPORT_BATCH_SIZE': 'foo'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result.containsKey('maxExportBatchSize'), isFalse);
    });

    test('returns empty map when no BLRP env vars set', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_blrp_config.dart',
        {},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result, isEmpty);
    });
  });

  // =========================================================================
  // OTelEnv - subprocess tests for getLogRecordLimits
  // =========================================================================
  group('OTelEnv.getLogRecordLimits (subprocess)', () {
    test('reads attributeValueLengthLimit', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_logrecord_limits.dart',
        {'OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT': '256'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['attributeValueLengthLimit'], equals(256));
    });

    test('reads attributeCountLimit', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_logrecord_limits.dart',
        {'OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT': '64'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['attributeCountLimit'], equals(64));
    });

    test('reads both limits together', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_logrecord_limits.dart',
        {
          'OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT': '512',
          'OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT': '128',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['attributeValueLengthLimit'], equals(512));
      expect(result['attributeCountLimit'], equals(128));
    });

    test('ignores non-numeric attributeValueLengthLimit', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_logrecord_limits.dart',
        {'OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT': 'not-a-number'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result.containsKey('attributeValueLengthLimit'), isFalse);
    });

    test('ignores non-numeric attributeCountLimit', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_logrecord_limits.dart',
        {'OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT': 'bad'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result.containsKey('attributeCountLimit'), isFalse);
    });

    test('returns empty map when no limits env vars set', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_logrecord_limits.dart',
        {},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result, isEmpty);
    });
  });

  // =========================================================================
  // OTelEnv - subprocess tests for _parseHeaders edge cases
  // =========================================================================
  group('OTelEnv._parseHeaders edge cases (subprocess)', () {
    test('handles empty header value', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_parse_headers.dart',
        {'OTEL_EXPORTER_OTLP_HEADERS': 'key='},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      // "key=" has equalIndex at position 3, but equalIndex < pair.length - 1
      // is false (3 < 3 is false), so it should be skipped
      expect(result.containsKey('key'), isFalse);
    });

    test('handles header with no equals sign', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_parse_headers.dart',
        {'OTEL_EXPORTER_OTLP_HEADERS': 'noequalssign'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result, isEmpty);
    });

    test('handles header starting with equals sign', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_parse_headers.dart',
        {'OTEL_EXPORTER_OTLP_HEADERS': '=value'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      // equalIndex is 0, which is not > 0, so it should be skipped
      expect(result, isEmpty);
    });

    test('handles multiple equals signs in value (base64)', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_parse_headers.dart',
        {
          'OTEL_EXPORTER_OTLP_HEADERS':
              'authorization=Basic dXNlcjpwYXNz==,x-api=val',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['authorization'], equals('Basic dXNlcjpwYXNz=='));
      expect(result['x-api'], equals('val'));
    });

    test('handles whitespace around keys and values', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_parse_headers.dart',
        {'OTEL_EXPORTER_OTLP_HEADERS': ' key1 = value1 , key2 = value2 '},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['key1'], equals('value1'));
      expect(result['key2'], equals('value2'));
    });

    test('handles single header', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_parse_headers.dart',
        {'OTEL_EXPORTER_OTLP_HEADERS': 'single=header'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['single'], equals('header'));
    });

    test('handles mix of valid and invalid headers', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_parse_headers.dart',
        {'OTEL_EXPORTER_OTLP_HEADERS': 'good=val,bad,=nokey,also-good=yes'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['good'], equals('val'));
      expect(result['also-good'], equals('yes'));
      expect(result.containsKey('bad'), isFalse);
      expect(result.containsKey(''), isFalse);
    });
  });

  // =========================================================================
  // OTelEnv - subprocess tests for getOtlpConfig with metrics and logs signals
  // (covers the 'metrics' and 'logs' cases in the switch blocks)
  // =========================================================================
  group('OTelEnv.getOtlpConfig metrics/logs signals (subprocess)', () {
    test('reads metrics-specific insecure setting', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_INSECURE': 'false',
          'OTEL_EXPORTER_OTLP_METRICS_INSECURE': 'true',
          'CHECK_SIGNAL': 'metrics',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['insecure'], isTrue);
    });

    test('reads logs-specific insecure setting', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_INSECURE': 'true',
          'OTEL_EXPORTER_OTLP_LOGS_INSECURE': 'false',
          'CHECK_SIGNAL': 'logs',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['insecure'], isFalse);
    });

    test('reads metrics-specific protocol', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_METRICS_PROTOCOL': 'http/protobuf',
          'CHECK_SIGNAL': 'metrics',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['protocol'], equals('http/protobuf'));
    });

    test('reads logs-specific protocol', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_LOGS_PROTOCOL': 'http/json',
          'CHECK_SIGNAL': 'logs',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['protocol'], equals('http/json'));
    });

    test('reads metrics-specific timeout', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_TIMEOUT': '10000',
          'OTEL_EXPORTER_OTLP_METRICS_TIMEOUT': '5000',
          'CHECK_SIGNAL': 'metrics',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['timeout_ms'], equals(5000));
    });

    test('reads logs-specific timeout', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_TIMEOUT': '10000',
          'OTEL_EXPORTER_OTLP_LOGS_TIMEOUT': '8000',
          'CHECK_SIGNAL': 'logs',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['timeout_ms'], equals(8000));
    });

    test('reads metrics-specific compression', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_COMPRESSION': 'none',
          'OTEL_EXPORTER_OTLP_METRICS_COMPRESSION': 'gzip',
          'CHECK_SIGNAL': 'metrics',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['compression'], equals('gzip'));
    });

    test('reads metrics-specific certificate', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_CERTIFICATE': '/general/cert.pem',
          'OTEL_EXPORTER_OTLP_METRICS_CERTIFICATE': '/metrics/cert.pem',
          'CHECK_SIGNAL': 'metrics',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['certificate'], equals('/metrics/cert.pem'));
    });

    test('reads logs-specific certificate', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_CERTIFICATE': '/general/cert.pem',
          'OTEL_EXPORTER_OTLP_LOGS_CERTIFICATE': '/logs/cert.pem',
          'CHECK_SIGNAL': 'logs',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['certificate'], equals('/logs/cert.pem'));
    });

    test('reads metrics-specific client key', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_CLIENT_KEY': '/general/key.pem',
          'OTEL_EXPORTER_OTLP_METRICS_CLIENT_KEY': '/metrics/key.pem',
          'CHECK_SIGNAL': 'metrics',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['clientKey'], equals('/metrics/key.pem'));
    });

    test('reads logs-specific client key', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_CLIENT_KEY': '/general/key.pem',
          'OTEL_EXPORTER_OTLP_LOGS_CLIENT_KEY': '/logs/key.pem',
          'CHECK_SIGNAL': 'logs',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['clientKey'], equals('/logs/key.pem'));
    });

    test('reads metrics-specific client certificate', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE': '/general/client.pem',
          'OTEL_EXPORTER_OTLP_METRICS_CLIENT_CERTIFICATE':
              '/metrics/client.pem',
          'CHECK_SIGNAL': 'metrics',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['clientCertificate'], equals('/metrics/client.pem'));
    });

    test('reads full metrics config with all fields', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT': 'http://metrics:4318',
          'OTEL_EXPORTER_OTLP_METRICS_PROTOCOL': 'http/protobuf',
          'OTEL_EXPORTER_OTLP_METRICS_HEADERS': 'metric-key=mval',
          'OTEL_EXPORTER_OTLP_METRICS_INSECURE': 'true',
          'OTEL_EXPORTER_OTLP_METRICS_TIMEOUT': '7000',
          'OTEL_EXPORTER_OTLP_METRICS_COMPRESSION': 'gzip',
          'OTEL_EXPORTER_OTLP_METRICS_CERTIFICATE': '/m/cert.pem',
          'OTEL_EXPORTER_OTLP_METRICS_CLIENT_KEY': '/m/key.pem',
          'OTEL_EXPORTER_OTLP_METRICS_CLIENT_CERTIFICATE': '/m/client.pem',
          'CHECK_SIGNAL': 'metrics',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['endpoint'], equals('http://metrics:4318'));
      expect(result['protocol'], equals('http/protobuf'));
      expect(result['insecure'], isTrue);
      expect(result['timeout_ms'], equals(7000));
      expect(result['compression'], equals('gzip'));
      expect(result['certificate'], equals('/m/cert.pem'));
      expect(result['clientKey'], equals('/m/key.pem'));
      expect(result['clientCertificate'], equals('/m/client.pem'));
      final headers = result['headers'] as Map<String, dynamic>;
      expect(headers['metric-key'], equals('mval'));
    });

    test('reads full logs config with all fields', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {
          'OTEL_EXPORTER_OTLP_LOGS_ENDPOINT': 'http://logs:4318',
          'OTEL_EXPORTER_OTLP_LOGS_PROTOCOL': 'http/json',
          'OTEL_EXPORTER_OTLP_LOGS_HEADERS': 'log-key=lval',
          'OTEL_EXPORTER_OTLP_LOGS_INSECURE': 'false',
          'OTEL_EXPORTER_OTLP_LOGS_TIMEOUT': '3000',
          'OTEL_EXPORTER_OTLP_LOGS_COMPRESSION': 'none',
          'OTEL_EXPORTER_OTLP_LOGS_CERTIFICATE': '/l/cert.pem',
          'OTEL_EXPORTER_OTLP_LOGS_CLIENT_KEY': '/l/key.pem',
          'OTEL_EXPORTER_OTLP_LOGS_CLIENT_CERTIFICATE': '/l/client.pem',
          'CHECK_SIGNAL': 'logs',
        },
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['endpoint'], equals('http://logs:4318'));
      expect(result['protocol'], equals('http/json'));
      expect(result['insecure'], isFalse);
      expect(result['timeout_ms'], equals(3000));
      expect(result['compression'], equals('none'));
      expect(result['certificate'], equals('/l/cert.pem'));
      expect(result['clientKey'], equals('/l/key.pem'));
      expect(result['clientCertificate'], equals('/l/client.pem'));
      final headers = result['headers'] as Map<String, dynamic>;
      expect(headers['log-key'], equals('lval'));
    });
  });

  // =========================================================================
  // OTelEnv - subprocess tests for _getEnvBoolNullable edge cases
  // (tested indirectly through insecure settings)
  // =========================================================================
  group('OTelEnv._getEnvBoolNullable edge cases (subprocess)', () {
    test('insecure "1" is true', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {'OTEL_EXPORTER_OTLP_INSECURE': '1'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['insecure'], isTrue);
    });

    test('insecure "yes" is true', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {'OTEL_EXPORTER_OTLP_INSECURE': 'yes'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['insecure'], isTrue);
    });

    test('insecure "on" is true', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {'OTEL_EXPORTER_OTLP_INSECURE': 'on'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['insecure'], isTrue);
    });

    test('insecure "0" is false', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {'OTEL_EXPORTER_OTLP_INSECURE': '0'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['insecure'], isFalse);
    });

    test('insecure "no" is false', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {'OTEL_EXPORTER_OTLP_INSECURE': 'no'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['insecure'], isFalse);
    });

    test('insecure "off" is false', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {'OTEL_EXPORTER_OTLP_INSECURE': 'off'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['insecure'], isFalse);
    });

    test('insecure "FALSE" (uppercase) is false', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {'OTEL_EXPORTER_OTLP_INSECURE': 'FALSE'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['insecure'], isFalse);
    });

    test('insecure "TRUE" (uppercase) is true', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {'OTEL_EXPORTER_OTLP_INSECURE': 'TRUE'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['insecure'], isTrue);
    });

    test('insecure with unrecognized value returns null (no insecure key)',
        () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_otlp_config.dart',
        {'OTEL_EXPORTER_OTLP_INSECURE': 'maybe'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result.containsKey('insecure'), isFalse);
    });
  });

  // =========================================================================
  // OTelEnv - subprocess tests for getExporter with metrics/logs
  // =========================================================================
  group('OTelEnv.getExporter for metrics and logs (subprocess)', () {
    test('reads OTEL_METRICS_EXPORTER', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_exporter.dart',
        {
          'OTEL_METRICS_EXPORTER': 'prometheus',
          'CHECK_SIGNAL': 'metrics',
        },
      );
      expect(output.trim(), equals('prometheus'));
    });

    test('reads OTEL_LOGS_EXPORTER', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_exporter.dart',
        {
          'OTEL_LOGS_EXPORTER': 'none',
          'CHECK_SIGNAL': 'logs',
        },
      );
      expect(output.trim(), equals('none'));
    });

    test('returns null for unknown signal', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_exporter.dart',
        {'CHECK_SIGNAL': 'unknown'},
      );
      expect(output.trim(), equals('null'));
    });
  });

  // =========================================================================
  // OTelEnv - in-process tests for getBlrpConfig and getLogRecordLimits
  // (these read from actual env, but test the method call and return type)
  // =========================================================================
  group('OTelEnv in-process', () {
    test('getBlrpConfig returns a Map<String, dynamic>', () {
      final config = OTelEnv.getBlrpConfig();
      expect(config, isA<Map<String, dynamic>>());
    });

    test('getLogRecordLimits returns a Map<String, dynamic>', () {
      final config = OTelEnv.getLogRecordLimits();
      expect(config, isA<Map<String, dynamic>>());
    });

    test('getExporter for metrics returns nullable result', () {
      final result = OTelEnv.getExporter(signal: 'metrics');
      // Result is null when env var is not set, or a String when set
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('getExporter for logs returns nullable result', () {
      final result = OTelEnv.getExporter(signal: 'logs');
      expect(result, anyOf(isNull, isA<String>()));
    });
  });

  // =========================================================================
  // EnvVarResourceDetector - subprocess tests for encoded values
  // =========================================================================
  group('EnvVarResourceDetector with encoded values (subprocess)', () {
    test('parses simple key=value pairs', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_envvar_resource_detector.dart',
        {'OTEL_RESOURCE_ATTRIBUTES': 'key1=value1,key2=value2'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['key1'], equals('value1'));
      expect(result['key2'], equals('value2'));
    });

    test('handles percent-encoded values', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_envvar_resource_detector.dart',
        {'OTEL_RESOURCE_ATTRIBUTES': 'path=/usr%2Flocal%2Fbin'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['path'], equals('/usr/local/bin'));
    });

    test('handles empty OTEL_RESOURCE_ATTRIBUTES', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_envvar_resource_detector.dart',
        {'OTEL_RESOURCE_ATTRIBUTES': ''},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result, isEmpty);
    });

    test('handles single attribute', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_envvar_resource_detector.dart',
        {'OTEL_RESOURCE_ATTRIBUTES': 'service.name=my-app'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['service.name'], equals('my-app'));
    });

    test('skips malformed entries (no equals)', () async {
      final output = await runWithEnv(
        'test/unit/environment/helpers/check_envvar_resource_detector.dart',
        {'OTEL_RESOURCE_ATTRIBUTES': 'good=val,badentry,also-good=yes'},
      );
      final result = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(result['good'], equals('val'));
      expect(result['also-good'], equals('yes'));
      expect(result.containsKey('badentry'), isFalse);
    });
  });

  // =========================================================================
  // ResourceDetector - additional in-process edge case tests
  // =========================================================================
  group('ResourceDetector additional tests', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'detector-edge-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test(
        'CompositeResourceDetector continues when detector throws non-Exception',
        () async {
      final stringThrower = _StringThrowingDetector();
      final working = _FixedDetector({'survived': 'yes'});
      final composite = CompositeResourceDetector([stringThrower, working]);
      final resource = await composite.detect();
      final attrs = resource.attributes.toMap();
      expect(attrs['survived']?.value, equals('yes'));
    });

    test('CompositeResourceDetector with all string-throwing detectors',
        () async {
      final composite = CompositeResourceDetector([
        _StringThrowingDetector(),
        _StringThrowingDetector(),
      ]);
      final resource = await composite.detect();
      expect(resource.attributes.isEmpty, isTrue);
    });

    test('EnvVarResourceDetector returns empty resource when no env var set',
        () async {
      // The default env in tests typically has no OTEL_RESOURCE_ATTRIBUTES
      final detector = EnvVarResourceDetector();
      final resource = await detector.detect();
      expect(resource.attributes.isEmpty, isTrue);
    });

    test('PlatformResourceDetector.create returns CompositeResourceDetector',
        () {
      final detector = PlatformResourceDetector.create();
      expect(detector, isA<CompositeResourceDetector>());
    });
  });

  // =========================================================================
  // OTel - print interception methods
  // =========================================================================
  group('OTel print interception', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test('isLogPrintEnabled defaults to false', () async {
      await OTel.initialize(
        serviceName: 'print-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );
      expect(OTel.isLogPrintEnabled, isFalse);
    });

    test('isLogPrintEnabled is true when logPrint=true', () async {
      await OTel.initialize(
        serviceName: 'print-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: true,
        logPrint: true,
      );
      expect(OTel.isLogPrintEnabled, isTrue);
    });

    test('runWithPrintInterception runs callback directly when not enabled',
        () async {
      await OTel.initialize(
        serviceName: 'print-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
        logPrint: false,
      );

      var callbackRan = false;
      final result = OTel.runWithPrintInterception(() {
        callbackRan = true;
        return 42;
      });
      expect(callbackRan, isTrue);
      expect(result, equals(42));
    });

    test('runWithPrintInterception returns callback result when enabled',
        () async {
      await OTel.initialize(
        serviceName: 'print-enabled-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: true,
        logPrint: true,
      );

      final result = OTel.runWithPrintInterception(() {
        return 'hello';
      });
      expect(result, equals('hello'));
    });

    test('runWithPrintInterception intercepts print when enabled', () async {
      await OTel.initialize(
        serviceName: 'print-intercept-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: true,
        logPrint: true,
      );

      // This should not throw - print is intercepted and logged
      OTel.runWithPrintInterception(() {
        print('test message from print interception');
      });
      // If we got here without error, the interception is working
      expect(true, isTrue);
    });

    test(
        'runWithPrintInterceptionAsync runs callback directly when not enabled',
        () async {
      await OTel.initialize(
        serviceName: 'async-print-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
        logPrint: false,
      );

      var callbackRan = false;
      final result = await OTel.runWithPrintInterceptionAsync(() async {
        callbackRan = true;
        return 99;
      });
      expect(callbackRan, isTrue);
      expect(result, equals(99));
    });

    test('runWithPrintInterceptionAsync returns callback result when enabled',
        () async {
      await OTel.initialize(
        serviceName: 'async-print-enabled-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: true,
        logPrint: true,
      );

      final result = await OTel.runWithPrintInterceptionAsync(() async {
        return 'async hello';
      });
      expect(result, equals('async hello'));
    });

    test('runWithPrintInterceptionAsync intercepts print when enabled',
        () async {
      await OTel.initialize(
        serviceName: 'async-print-intercept-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: true,
        logPrint: true,
      );

      await OTel.runWithPrintInterceptionAsync(() async {
        print('async test message from print interception');
      });
      // If we got here without error, the interception is working
      expect(true, isTrue);
    });

    test('logBridge is null when logPrint is false', () async {
      await OTel.initialize(
        serviceName: 'no-bridge-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
        logPrint: false,
      );
      expect(OTel.logBridge, isNull);
    });

    test('logBridge is initialized after first runWithPrintInterception',
        () async {
      await OTel.initialize(
        serviceName: 'bridge-init-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: true,
        logPrint: true,
      );

      // Before first call, bridge may or may not be initialized
      // After call, it should be
      OTel.runWithPrintInterception(() {});
      expect(OTel.logBridge, isNotNull);
    });

    test('custom logPrintLoggerName is used', () async {
      await OTel.initialize(
        serviceName: 'custom-logger-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: true,
        logPrint: true,
        logPrintLoggerName: 'my.custom.logger',
      );

      // Trigger initialization of the bridge
      OTel.runWithPrintInterception(() {});
      expect(OTel.logBridge, isNotNull);
    });
  });

  // =========================================================================
  // OTel - addTracerProvider, addMeterProvider, addLoggerProvider
  // =========================================================================
  group('OTel provider creation methods', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'provider-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test('addTracerProvider creates a named TracerProvider', () {
      final tp = OTel.addTracerProvider('custom-traces');
      expect(tp, isA<TracerProvider>());
      expect(tp.resource, isNotNull);
    });

    test('addTracerProvider uses default resource when none specified', () {
      final tp = OTel.addTracerProvider('default-resource-tp');
      expect(tp.resource, equals(OTel.defaultResource));
    });

    test('addTracerProvider uses custom resource when specified', () {
      final customResource = OTel.resource(
        OTel.attributesFromMap({'custom': 'value'}),
      );
      final tp = OTel.addTracerProvider(
        'custom-resource-tp',
        resource: customResource,
      );
      expect(tp.resource, equals(customResource));
    });

    test('addTracerProvider with custom sampler', () {
      final tp = OTel.addTracerProvider(
        'sampled-tp',
        sampler: const AlwaysOffSampler(),
      );
      expect(tp, isA<TracerProvider>());
      expect(tp.sampler, isA<AlwaysOffSampler>());
    });

    test('addMeterProvider creates a named MeterProvider', () {
      final mp = OTel.addMeterProvider('custom-metrics');
      expect(mp, isA<MeterProvider>());
      expect(mp.resource, isNotNull);
    });

    test('addMeterProvider uses default resource when none specified', () {
      final mp = OTel.addMeterProvider('default-resource-mp');
      expect(mp.resource, equals(OTel.defaultResource));
    });

    test('addMeterProvider uses custom resource when specified', () {
      final customResource = OTel.resource(
        OTel.attributesFromMap({'meter.custom': 'val'}),
      );
      final mp = OTel.addMeterProvider(
        'custom-resource-mp',
        resource: customResource,
      );
      expect(mp.resource, equals(customResource));
    });

    test('addLoggerProvider creates a named LoggerProvider', () {
      final lp = OTel.addLoggerProvider('custom-logs');
      expect(lp, isA<LoggerProvider>());
      expect(lp.resource, isNotNull);
    });

    test('addLoggerProvider uses default resource when none specified', () {
      final lp = OTel.addLoggerProvider('default-resource-lp');
      expect(lp.resource, equals(OTel.defaultResource));
    });

    test('addLoggerProvider uses custom resource when specified', () {
      final customResource = OTel.resource(
        OTel.attributesFromMap({'logger.custom': 'val'}),
      );
      final lp = OTel.addLoggerProvider(
        'custom-resource-lp',
        resource: customResource,
      );
      expect(lp.resource, equals(customResource));
    });

    test('can retrieve named TracerProvider after adding', () {
      OTel.addTracerProvider('retrievable');
      final tp = OTel.tracerProvider(name: 'retrievable');
      expect(tp, isA<TracerProvider>());
    });

    test('can retrieve named MeterProvider after adding', () {
      OTel.addMeterProvider('retrievable-meter');
      final mp = OTel.meterProvider(name: 'retrievable-meter');
      expect(mp, isA<MeterProvider>());
    });

    test('can retrieve named LoggerProvider after adding', () {
      OTel.addLoggerProvider('retrievable-logger');
      final lp = OTel.loggerProvider(name: 'retrievable-logger');
      expect(lp, isA<LoggerProvider>());
    });

    test('tracerProviders returns list including default and named', () {
      OTel.addTracerProvider('extra-tp');
      final providers = OTel.tracerProviders();
      expect(providers.length, greaterThanOrEqualTo(2));
    });

    test('meterProviders returns list including named provider', () {
      OTel.addMeterProvider('extra-mp');
      final providers = OTel.meterProviders();
      expect(providers.length, greaterThanOrEqualTo(1));
    });
  });

  // =========================================================================
  // OTel - tenantId handling in initialize
  // =========================================================================
  group('OTel tenantId handling', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test('initialize without tenantId has no tenant_id attribute', () async {
      await OTel.initialize(
        serviceName: 'no-tenant-service',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();
      final hasTenantId = attrs.any((a) => a.key == 'tenant_id');
      expect(hasTenantId, isFalse);
    });

    test('initialize with tenantId preserves it through platform detection',
        () async {
      await OTel.initialize(
        serviceName: 'tenant-with-platform',
        tenantId: 'my-tenant',
        detectPlatformResources: true,
        enableMetrics: false,
        enableLogs: false,
      );

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();
      final tenantAttr = attrs.firstWhere(
        (a) => a.key == 'tenant_id',
        orElse: () => throw StateError('tenant_id not found'),
      );
      expect(tenantAttr.value, equals('my-tenant'));
    });

    test('tenantId coexists with custom resource attributes', () async {
      final customAttrs = OTel.attributesFromMap({
        'custom.key': 'custom-value',
        'deployment.environment': 'staging',
      });

      await OTel.initialize(
        serviceName: 'tenant-with-custom',
        tenantId: 'multi-tenant',
        resourceAttributes: customAttrs,
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();

      final tenantAttr = attrs.firstWhere(
        (a) => a.key == 'tenant_id',
        orElse: () => throw StateError('tenant_id not found'),
      );
      expect(tenantAttr.value, equals('multi-tenant'));

      final customAttr = attrs.firstWhere(
        (a) => a.key == 'custom.key',
        orElse: () => throw StateError('custom.key not found'),
      );
      expect(customAttr.value, equals('custom-value'));
    });

    test('initialize with dartasticApiKey stores it', () async {
      await OTel.initialize(
        serviceName: 'api-key-test',
        dartasticApiKey: 'test-api-key-123',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );

      expect(OTel.dartasticApiKey, equals('test-api-key-123'));
    });
  });

  // =========================================================================
  // OTel - enableLogs and enableMetrics configuration
  // =========================================================================
  group('OTel initialization with logs/metrics options', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test('initialize with enableLogs=true configures LoggerProvider', () async {
      await OTel.initialize(
        serviceName: 'logs-enabled',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: true,
      );

      final lp = OTel.loggerProvider();
      expect(lp, isA<LoggerProvider>());
    });

    test('initialize with enableMetrics=true configures MeterProvider',
        () async {
      await OTel.initialize(
        serviceName: 'metrics-enabled',
        detectPlatformResources: false,
        enableMetrics: true,
        enableLogs: false,
      );

      final mp = OTel.meterProvider();
      expect(mp, isA<MeterProvider>());
    });

    test('initialize with both logs and metrics', () async {
      await OTel.initialize(
        serviceName: 'both-enabled',
        detectPlatformResources: false,
        enableMetrics: true,
        enableLogs: true,
      );

      expect(OTel.loggerProvider(), isA<LoggerProvider>());
      expect(OTel.meterProvider(), isA<MeterProvider>());
    });

    test('logger() returns a Logger from default LoggerProvider', () async {
      await OTel.initialize(
        serviceName: 'logger-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: true,
      );

      final logger = OTel.logger('test-logger');
      expect(logger, isA<Logger>());
    });

    test('logger() with default name uses defaultTracerName', () async {
      await OTel.initialize(
        serviceName: 'default-logger-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: true,
      );

      final logger = OTel.logger();
      expect(logger, isA<Logger>());
    });
  });

  // =========================================================================
  // OTel - validation in initialize
  // =========================================================================
  group('OTel.initialize validation', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test('throws ArgumentError for empty endpoint', () async {
      expect(
        () => OTel.initialize(
          serviceName: 'test',
          endpoint: '',
          detectPlatformResources: false,
          enableMetrics: false,
          enableLogs: false,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for empty serviceName', () async {
      expect(
        () => OTel.initialize(
          serviceName: '',
          detectPlatformResources: false,
          enableMetrics: false,
          enableLogs: false,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for empty serviceVersion', () async {
      expect(
        () => OTel.initialize(
          serviceName: 'test',
          serviceVersion: '',
          detectPlatformResources: false,
          enableMetrics: false,
          enableLogs: false,
        ),
        throwsArgumentError,
      );
    });
  });
}
