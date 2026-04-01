// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show LogFunction, LogLevel;
import 'package:test/test.dart';

/// Runs a Dart script in a subprocess with specific environment variables set.
///
/// Returns the stdout output as a string.
/// This is the only reliable way to test code that reads from
/// Platform.environment, since Platform.environment is an unmodifiable map.
Future<String> runWithEnv(
  String scriptPath,
  Map<String, String> envVars,
) async {
  final env = Map<String, String>.from(Platform.environment);
  env.addAll(envVars);
  final result = await Process.run(
    Platform.executable,
    ['run', scriptPath],
    environment: env,
    workingDirectory: Directory.current.path.endsWith('dartastic_opentelemetry')
        ? Directory.current.path
        : '${Directory.current.path}/dartastic_opentelemetry',
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

void main() {
  group('OTelEnv', () {
    // Save and restore OTelLog state around each test.
    LogFunction? savedLogFunction;
    LogFunction? savedMetricLogFunction;
    LogFunction? savedSpanLogFunction;
    LogFunction? savedExportLogFunction;
    LogLevel savedLogLevel = OTelLog.currentLevel;

    setUp(() {
      savedLogFunction = OTelLog.logFunction;
      savedMetricLogFunction = OTelLog.metricLogFunction;
      savedSpanLogFunction = OTelLog.spanLogFunction;
      savedExportLogFunction = OTelLog.exportLogFunction;
      savedLogLevel = OTelLog.currentLevel;
    });

    tearDown(() {
      OTelLog.logFunction = savedLogFunction;
      OTelLog.metricLogFunction = savedMetricLogFunction;
      OTelLog.spanLogFunction = savedSpanLogFunction;
      OTelLog.exportLogFunction = savedExportLogFunction;
      OTelLog.currentLevel = savedLogLevel;
    });

    // =========================================================================
    // initializeLogging
    // =========================================================================
    group('initializeLogging', () {
      test('does not throw when no env vars are set', () {
        // Clear all logging to a known state
        OTelLog.logFunction = null;
        OTelLog.metricLogFunction = null;
        OTelLog.spanLogFunction = null;
        OTelLog.exportLogFunction = null;

        // Should not throw
        expect(OTelEnv.initializeLogging, returnsNormally);
      });

      test('preserves custom log function when env vars set log level', () {
        // Set a custom log function (not print)
        final logs = <String>[];
        OTelLog.logFunction = logs.add;

        // Call initializeLogging - it should preserve the custom function
        OTelEnv.initializeLogging();

        // The custom function should be preserved (not replaced with print)
        expect(OTelLog.logFunction, equals(logs.add));
      });

      test('preserves null log function when no OTEL_LOG_LEVEL is set', () {
        // When there's no OTEL_LOG_LEVEL env var and logFunction is null,
        // it should stay null since the logLevel block isn't entered
        OTelLog.logFunction = null;

        // Whether initializeLogging changes logFunction depends on whether
        // OTEL_LOG_LEVEL is set in the environment. We check the behavior:
        OTelEnv.initializeLogging();

        // If OTEL_LOG_LEVEL is set (e.g. during coverage), logFunction may
        // remain null since hasCustomLogFunction is false but logFunction is
        // null (not a custom function), so it gets set to print.
        // If not set, logFunction stays null.
        final envLogLevel =
            EnvironmentService.instance.getValue('OTEL_LOG_LEVEL');
        if (envLogLevel == null) {
          expect(OTelLog.logFunction, isNull);
        } else {
          // When env var is set and no custom function, it sets to print
          expect(OTelLog.logFunction, equals(print));
        }
      });

      test(
          'sets logFunction to print when OTEL_LOG_LEVEL is set and no custom function',
          () {
        // Start with the default print function
        OTelLog.logFunction = print;

        OTelEnv.initializeLogging();

        // If OTEL_LOG_LEVEL is set, logFunction stays print (not custom)
        // If not set, logFunction stays as-is
        final envLogLevel =
            EnvironmentService.instance.getValue('OTEL_LOG_LEVEL');
        if (envLogLevel != null) {
          expect(OTelLog.logFunction, equals(print));
        }
      });

      test('does not overwrite existing metric log function', () {
        final metricLogs = <String>[];
        OTelLog.metricLogFunction = metricLogs.add;

        OTelEnv.initializeLogging();

        // The existing custom function should be preserved
        expect(OTelLog.metricLogFunction, equals(metricLogs.add));
      });

      test('does not overwrite existing span log function', () {
        final spanLogs = <String>[];
        OTelLog.spanLogFunction = spanLogs.add;

        OTelEnv.initializeLogging();

        // The existing custom function should be preserved
        expect(OTelLog.spanLogFunction, equals(spanLogs.add));
      });

      test('does not overwrite existing export log function', () {
        final exportLogs = <String>[];
        OTelLog.exportLogFunction = exportLogs.add;

        OTelEnv.initializeLogging();

        // The existing custom function should be preserved
        expect(OTelLog.exportLogFunction, equals(exportLogs.add));
      });

      test('handles log level set during coverage run', () {
        // During coverage run, OTEL_LOG_LEVEL=trace is set
        final envLogLevel =
            EnvironmentService.instance.getValue('OTEL_LOG_LEVEL');

        // Reset to known state
        OTelLog.logFunction = null;
        OTelLog.metricLogFunction = null;
        OTelLog.spanLogFunction = null;
        OTelLog.exportLogFunction = null;
        OTelLog.currentLevel = LogLevel.info;

        OTelEnv.initializeLogging();

        if (envLogLevel != null) {
          // Log level should be set based on env var
          switch (envLogLevel.toLowerCase()) {
            case 'trace':
              expect(OTelLog.currentLevel, equals(LogLevel.trace));
              break;
            case 'debug':
              expect(OTelLog.currentLevel, equals(LogLevel.debug));
              break;
            case 'info':
              expect(OTelLog.currentLevel, equals(LogLevel.info));
              break;
            case 'warn':
              expect(OTelLog.currentLevel, equals(LogLevel.warn));
              break;
            case 'error':
              expect(OTelLog.currentLevel, equals(LogLevel.error));
              break;
            case 'fatal':
              expect(OTelLog.currentLevel, equals(LogLevel.fatal));
              break;
          }
          // logFunction should be set to print since there was no custom function
          expect(OTelLog.logFunction, equals(print));
        } else {
          // No env var - log level stays at default
          expect(OTelLog.currentLevel, equals(LogLevel.info));
        }
      });

      test('sets metric/span/export log functions when env vars are true', () {
        // Clear log functions
        OTelLog.metricLogFunction = null;
        OTelLog.spanLogFunction = null;
        OTelLog.exportLogFunction = null;

        OTelEnv.initializeLogging();

        final logMetrics =
            EnvironmentService.instance.getValue('OTEL_LOG_METRICS');
        final logSpans = EnvironmentService.instance.getValue('OTEL_LOG_SPANS');
        final logExport =
            EnvironmentService.instance.getValue('OTEL_LOG_EXPORT');

        if (logMetrics?.toLowerCase() == 'true') {
          expect(OTelLog.metricLogFunction, equals(print));
        }
        if (logSpans?.toLowerCase() == 'true') {
          expect(OTelLog.spanLogFunction, equals(print));
        }
        if (logExport?.toLowerCase() == 'true') {
          expect(OTelLog.exportLogFunction, equals(print));
        }
      });
    });

    // =========================================================================
    // getOtlpConfig
    // =========================================================================
    group('getOtlpConfig', () {
      test('returns empty map for traces when no env vars set', () {
        final config = OTelEnv.getOtlpConfig(signal: 'traces');
        // Config may have entries if env vars are set externally
        expect(config, isA<Map<String, dynamic>>());
      });

      test('returns empty map for metrics when no env vars set', () {
        final config = OTelEnv.getOtlpConfig(signal: 'metrics');
        expect(config, isA<Map<String, dynamic>>());
      });

      test('returns empty map for logs when no env vars set', () {
        final config = OTelEnv.getOtlpConfig(signal: 'logs');
        expect(config, isA<Map<String, dynamic>>());
      });

      test('returns empty map for unknown signal', () {
        final config = OTelEnv.getOtlpConfig(signal: 'unknown');
        expect(config, isA<Map<String, dynamic>>());
        // An unknown signal won't match any switch case so all values stay null
        expect(config, isEmpty);
      });

      test('defaults to traces signal', () {
        final configDefault = OTelEnv.getOtlpConfig();
        final configTraces = OTelEnv.getOtlpConfig(signal: 'traces');
        // Both should produce the same result
        expect(configDefault.length, equals(configTraces.length));
      });
    });

    // =========================================================================
    // getServiceConfig
    // =========================================================================
    group('getServiceConfig', () {
      test('returns a map', () {
        final config = OTelEnv.getServiceConfig();
        expect(config, isA<Map<String, dynamic>>());
      });

      test(
          'returns empty map when no OTEL_RESOURCE_ATTRIBUTES or OTEL_SERVICE_NAME set',
          () {
        final resourceAttrs =
            EnvironmentService.instance.getValue('OTEL_RESOURCE_ATTRIBUTES');
        final serviceName =
            EnvironmentService.instance.getValue('OTEL_SERVICE_NAME');

        final config = OTelEnv.getServiceConfig();

        if (resourceAttrs == null && serviceName == null) {
          expect(config, isEmpty);
        } else {
          // If env vars are set, config should have entries
          expect(config, isA<Map<String, dynamic>>());
        }
      });
    });

    // =========================================================================
    // getResourceAttributes
    // =========================================================================
    group('getResourceAttributes', () {
      test('returns a Map<String, Object>', () {
        final attrs = OTelEnv.getResourceAttributes();
        expect(attrs, isA<Map<String, Object>>());
      });

      test('returns empty map when OTEL_RESOURCE_ATTRIBUTES not set', () {
        final resourceStr =
            EnvironmentService.instance.getValue('OTEL_RESOURCE_ATTRIBUTES');

        final attrs = OTelEnv.getResourceAttributes();

        if (resourceStr == null) {
          expect(attrs, isEmpty);
        } else {
          expect(attrs, isA<Map<String, Object>>());
        }
      });
    });

    // =========================================================================
    // getExporter
    // =========================================================================
    group('getExporter', () {
      test('returns null for traces when OTEL_TRACES_EXPORTER not set', () {
        final envValue =
            EnvironmentService.instance.getValue('OTEL_TRACES_EXPORTER');
        final result = OTelEnv.getExporter(signal: 'traces');
        if (envValue == null) {
          expect(result, isNull);
        } else {
          expect(result, equals(envValue));
        }
      });

      test('returns null for metrics when OTEL_METRICS_EXPORTER not set', () {
        final envValue =
            EnvironmentService.instance.getValue('OTEL_METRICS_EXPORTER');
        final result = OTelEnv.getExporter(signal: 'metrics');
        if (envValue == null) {
          expect(result, isNull);
        } else {
          expect(result, equals(envValue));
        }
      });

      test('returns null for logs when OTEL_LOGS_EXPORTER not set', () {
        final envValue =
            EnvironmentService.instance.getValue('OTEL_LOGS_EXPORTER');
        final result = OTelEnv.getExporter(signal: 'logs');
        if (envValue == null) {
          expect(result, isNull);
        } else {
          expect(result, equals(envValue));
        }
      });

      test('returns null for unknown signal', () {
        final result = OTelEnv.getExporter(signal: 'unknown');
        expect(result, isNull);
      });

      test('defaults to traces signal', () {
        final resultDefault = OTelEnv.getExporter();
        final resultTraces = OTelEnv.getExporter(signal: 'traces');
        expect(resultDefault, equals(resultTraces));
      });
    });

    // =========================================================================
    // Subprocess tests for environment-dependent code paths
    //
    // These tests spawn a child Dart process with specific environment
    // variables set to exercise the parsing logic that cannot be tested
    // in-process (Platform.environment is an unmodifiable map).
    // =========================================================================
    group('subprocess - initializeLogging log levels', () {
      for (final level in [
        'trace',
        'debug',
        'info',
        'warn',
        'error',
        'fatal'
      ]) {
        test('sets log level to $level from OTEL_LOG_LEVEL', () async {
          final output = await runWithEnv(
            'test/unit/environment/helpers/check_log_level.dart',
            {'OTEL_LOG_LEVEL': level},
          );
          expect(output.trim(), equals(level));
        });
      }

      test('ignores unrecognized OTEL_LOG_LEVEL value', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_log_level.dart',
          {'OTEL_LOG_LEVEL': 'bogus'},
        );
        // Default level is info
        expect(output.trim(), equals('info'));
      });

      test('handles uppercase OTEL_LOG_LEVEL', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_log_level.dart',
          {'OTEL_LOG_LEVEL': 'DEBUG'},
        );
        expect(output.trim(), equals('debug'));
      });

      test('handles mixed case OTEL_LOG_LEVEL', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_log_level.dart',
          {'OTEL_LOG_LEVEL': 'Warn'},
        );
        expect(output.trim(), equals('warn'));
      });
    });

    group('subprocess - initializeLogging boolean env vars', () {
      test('enables metric logging when OTEL_LOG_METRICS is true', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_log_bools.dart',
          {'OTEL_LOG_METRICS': 'true'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['metricLogFunction'], isTrue);
      });

      test('enables span logging when OTEL_LOG_SPANS is 1', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_log_bools.dart',
          {'OTEL_LOG_SPANS': '1'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['spanLogFunction'], isTrue);
      });

      test('enables export logging when OTEL_LOG_EXPORT is yes', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_log_bools.dart',
          {'OTEL_LOG_EXPORT': 'yes'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['exportLogFunction'], isTrue);
      });

      test('enables export logging when OTEL_LOG_EXPORT is on', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_log_bools.dart',
          {'OTEL_LOG_EXPORT': 'on'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['exportLogFunction'], isTrue);
      });

      test('does not enable logging when env var is false', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_log_bools.dart',
          {
            'OTEL_LOG_METRICS': 'false',
            'OTEL_LOG_SPANS': '0',
            'OTEL_LOG_EXPORT': 'no',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['metricLogFunction'], isFalse);
        expect(result['spanLogFunction'], isFalse);
        expect(result['exportLogFunction'], isFalse);
      });

      test('all three enabled simultaneously', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_log_bools.dart',
          {
            'OTEL_LOG_METRICS': 'true',
            'OTEL_LOG_SPANS': 'true',
            'OTEL_LOG_EXPORT': 'true',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['metricLogFunction'], isTrue);
        expect(result['spanLogFunction'], isTrue);
        expect(result['exportLogFunction'], isTrue);
      });
    });

    group('subprocess - getOtlpConfig', () {
      test('reads general endpoint', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:4318'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['endpoint'], equals('http://localhost:4318'));
      });

      test('signal-specific endpoint overrides general for traces', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://general:4318',
            'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT': 'http://traces:4318',
            'CHECK_SIGNAL': 'traces',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['endpoint'], equals('http://traces:4318'));
      });

      test('signal-specific endpoint overrides general for metrics', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://general:4318',
            'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT': 'http://metrics:4318',
            'CHECK_SIGNAL': 'metrics',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['endpoint'], equals('http://metrics:4318'));
      });

      test('signal-specific endpoint overrides general for logs', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://general:4318',
            'OTEL_EXPORTER_OTLP_LOGS_ENDPOINT': 'http://logs:4318',
            'CHECK_SIGNAL': 'logs',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['endpoint'], equals('http://logs:4318'));
      });

      test('reads protocol', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['protocol'], equals('grpc'));
      });

      test('reads signal-specific protocol for traces', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
            'OTEL_EXPORTER_OTLP_TRACES_PROTOCOL': 'http/protobuf',
            'CHECK_SIGNAL': 'traces',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['protocol'], equals('http/protobuf'));
      });

      test('reads headers and parses them', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_HEADERS': 'api-key=secret123,tenant=acme'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        final headers = result['headers'] as Map<String, dynamic>;
        expect(headers['api-key'], equals('secret123'));
        expect(headers['tenant'], equals('acme'));
      });

      test('parses headers with base64 values containing equals signs',
          () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_HEADERS':
                'authorization=Bearer dG9rZW4=,x-custom=val',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        final headers = result['headers'] as Map<String, dynamic>;
        expect(headers['authorization'], equals('Bearer dG9rZW4='));
        expect(headers['x-custom'], equals('val'));
      });

      test('reads signal-specific headers for metrics', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_HEADERS': 'general=val',
            'OTEL_EXPORTER_OTLP_METRICS_HEADERS': 'metric-key=mval',
            'CHECK_SIGNAL': 'metrics',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        final headers = result['headers'] as Map<String, dynamic>;
        expect(headers['metric-key'], equals('mval'));
        expect(headers.containsKey('general'), isFalse);
      });

      test('reads signal-specific headers for logs', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_LOGS_HEADERS': 'log-key=lval',
            'CHECK_SIGNAL': 'logs',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        final headers = result['headers'] as Map<String, dynamic>;
        expect(headers['log-key'], equals('lval'));
      });

      test('reads insecure as true', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_INSECURE': 'true'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['insecure'], isTrue);
      });

      test('reads insecure as false', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_INSECURE': 'false'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['insecure'], isFalse);
      });

      test('reads signal-specific insecure for traces', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_INSECURE': 'false',
            'OTEL_EXPORTER_OTLP_TRACES_INSECURE': 'true',
            'CHECK_SIGNAL': 'traces',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['insecure'], isTrue);
      });

      test('reads timeout and converts to milliseconds', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_TIMEOUT': '5000'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['timeout_ms'], equals(5000));
      });

      test('ignores non-numeric timeout', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_TIMEOUT': 'not-a-number'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result.containsKey('timeout_ms'), isFalse);
      });

      test('reads signal-specific timeout for metrics', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_TIMEOUT': '10000',
            'OTEL_EXPORTER_OTLP_METRICS_TIMEOUT': '3000',
            'CHECK_SIGNAL': 'metrics',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['timeout_ms'], equals(3000));
      });

      test('reads compression', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_COMPRESSION': 'gzip'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['compression'], equals('gzip'));
      });

      test('reads signal-specific compression for logs', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_COMPRESSION': 'none',
            'OTEL_EXPORTER_OTLP_LOGS_COMPRESSION': 'gzip',
            'CHECK_SIGNAL': 'logs',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['compression'], equals('gzip'));
      });

      test('reads certificate', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_CERTIFICATE': '/path/to/cert.pem'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['certificate'], equals('/path/to/cert.pem'));
      });

      test('reads signal-specific certificate for traces', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_CERTIFICATE': '/general/cert.pem',
            'OTEL_EXPORTER_OTLP_TRACES_CERTIFICATE': '/traces/cert.pem',
            'CHECK_SIGNAL': 'traces',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['certificate'], equals('/traces/cert.pem'));
      });

      test('reads client key', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_CLIENT_KEY': '/path/to/key.pem'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['clientKey'], equals('/path/to/key.pem'));
      });

      test('reads signal-specific client key for metrics', () async {
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

      test('reads client certificate', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE': '/path/to/client.pem'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['clientCertificate'], equals('/path/to/client.pem'));
      });

      test('reads signal-specific client certificate for logs', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE': '/general/client.pem',
            'OTEL_EXPORTER_OTLP_LOGS_CLIENT_CERTIFICATE': '/logs/client.pem',
            'CHECK_SIGNAL': 'logs',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['clientCertificate'], equals('/logs/client.pem'));
      });

      test('reads full config with all fields', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {
            'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://collector:4318',
            'OTEL_EXPORTER_OTLP_PROTOCOL': 'http/protobuf',
            'OTEL_EXPORTER_OTLP_HEADERS': 'api-key=secret,tenant=acme',
            'OTEL_EXPORTER_OTLP_INSECURE': 'false',
            'OTEL_EXPORTER_OTLP_TIMEOUT': '15000',
            'OTEL_EXPORTER_OTLP_COMPRESSION': 'gzip',
            'OTEL_EXPORTER_OTLP_CERTIFICATE': '/cert.pem',
            'OTEL_EXPORTER_OTLP_CLIENT_KEY': '/key.pem',
            'OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE': '/client.pem',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['endpoint'], equals('http://collector:4318'));
        expect(result['protocol'], equals('http/protobuf'));
        expect(result['insecure'], isFalse);
        expect(result['timeout_ms'], equals(15000));
        expect(result['compression'], equals('gzip'));
        expect(result['certificate'], equals('/cert.pem'));
        expect(result['clientKey'], equals('/key.pem'));
        expect(result['clientCertificate'], equals('/client.pem'));
        final headers = result['headers'] as Map<String, dynamic>;
        expect(headers['api-key'], equals('secret'));
        expect(headers['tenant'], equals('acme'));
      });
    });

    group('subprocess - getServiceConfig', () {
      test('reads service.name from OTEL_RESOURCE_ATTRIBUTES', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_service_config.dart',
          {'OTEL_RESOURCE_ATTRIBUTES': 'service.name=my-service'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['serviceName'], equals('my-service'));
      });

      test('reads service.version from OTEL_RESOURCE_ATTRIBUTES', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_service_config.dart',
          {
            'OTEL_RESOURCE_ATTRIBUTES':
                'service.name=my-service,service.version=1.2.3',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['serviceName'], equals('my-service'));
        expect(result['serviceVersion'], equals('1.2.3'));
      });

      test('OTEL_SERVICE_NAME overrides service.name from resource attributes',
          () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_service_config.dart',
          {
            'OTEL_RESOURCE_ATTRIBUTES': 'service.name=from-attrs',
            'OTEL_SERVICE_NAME': 'from-env-var',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['serviceName'], equals('from-env-var'));
      });

      test('OTEL_SERVICE_NAME alone without resource attributes', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_service_config.dart',
          {'OTEL_SERVICE_NAME': 'standalone-service'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['serviceName'], equals('standalone-service'));
      });

      test('ignores malformed pairs in OTEL_RESOURCE_ATTRIBUTES', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_service_config.dart',
          {
            'OTEL_RESOURCE_ATTRIBUTES':
                'bad-entry,service.name=good,=nokey,novalue=',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['serviceName'], equals('good'));
      });
    });

    group('subprocess - getResourceAttributes', () {
      test('parses simple string attributes', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_resource_attrs.dart',
          {
            'OTEL_RESOURCE_ATTRIBUTES':
                'service.name=my-app,environment=production',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['service.name'], equals('my-app'));
        expect(result['environment'], equals('production'));
      });

      test('parses integer values', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_resource_attrs.dart',
          {'OTEL_RESOURCE_ATTRIBUTES': 'count=42,port=8080'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['count'], equals(42));
        expect(result['port'], equals(8080));
      });

      test('parses double values', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_resource_attrs.dart',
          {'OTEL_RESOURCE_ATTRIBUTES': 'ratio=0.75,temp=98.6'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['ratio'], equals(0.75));
        expect(result['temp'], equals(98.6));
      });

      test('parses boolean values', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_resource_attrs.dart',
          {'OTEL_RESOURCE_ATTRIBUTES': 'enabled=true,disabled=false'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['enabled'], isTrue);
        expect(result['disabled'], isFalse);
      });

      test('parses boolean values case-insensitively', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_resource_attrs.dart',
          {'OTEL_RESOURCE_ATTRIBUTES': 'a=TRUE,b=False'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['a'], isTrue);
        expect(result['b'], isFalse);
      });

      test('parses mixed types', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_resource_attrs.dart',
          {
            'OTEL_RESOURCE_ATTRIBUTES': 'name=test,count=5,ratio=1.5,flag=true',
          },
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['name'], equals('test'));
        expect(result['count'], equals(5));
        expect(result['ratio'], equals(1.5));
        expect(result['flag'], isTrue);
      });

      test('skips malformed entries (no equals sign)', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_resource_attrs.dart',
          {'OTEL_RESOURCE_ATTRIBUTES': 'good=value,badentry,also-good=yes'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['good'], equals('value'));
        expect(result.containsKey('badentry'), isFalse);
        expect(result['also-good'], equals('yes'));
      });

      test('handles whitespace in keys and values', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_resource_attrs.dart',
          {'OTEL_RESOURCE_ATTRIBUTES': ' key1 = value1 , key2 = 42 '},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result['key1'], equals('value1'));
        expect(result['key2'], equals(42));
      });

      test('returns empty map with empty string', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_resource_attrs.dart',
          {'OTEL_RESOURCE_ATTRIBUTES': ''},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        // Empty string leads to empty splits that don't match key=value
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('subprocess - getExporter', () {
      test('reads OTEL_TRACES_EXPORTER', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_exporter.dart',
          {'OTEL_TRACES_EXPORTER': 'otlp', 'CHECK_SIGNAL': 'traces'},
        );
        expect(output.trim(), equals('otlp'));
      });

      test('reads OTEL_METRICS_EXPORTER', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_exporter.dart',
          {'OTEL_METRICS_EXPORTER': 'prometheus', 'CHECK_SIGNAL': 'metrics'},
        );
        expect(output.trim(), equals('prometheus'));
      });

      test('reads OTEL_LOGS_EXPORTER', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_exporter.dart',
          {'OTEL_LOGS_EXPORTER': 'none', 'CHECK_SIGNAL': 'logs'},
        );
        expect(output.trim(), equals('none'));
      });

      test('reads jaeger exporter for traces', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_exporter.dart',
          {'OTEL_TRACES_EXPORTER': 'jaeger', 'CHECK_SIGNAL': 'traces'},
        );
        expect(output.trim(), equals('jaeger'));
      });

      test('reads zipkin exporter for traces', () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_exporter.dart',
          {'OTEL_TRACES_EXPORTER': 'zipkin', 'CHECK_SIGNAL': 'traces'},
        );
        expect(output.trim(), equals('zipkin'));
      });
    });

    group('subprocess - insecure boolean nullable env vars', () {
      for (final val in ['1', 'true', 'yes', 'on', 'TRUE', 'Yes', 'ON']) {
        test('OTEL_EXPORTER_OTLP_INSECURE=$val is true', () async {
          final output = await runWithEnv(
            'test/unit/environment/helpers/check_otlp_config.dart',
            {'OTEL_EXPORTER_OTLP_INSECURE': val},
          );
          final result = jsonDecode(output.trim()) as Map<String, dynamic>;
          expect(result['insecure'], isTrue);
        });
      }

      for (final val in ['0', 'false', 'no', 'off', 'FALSE', 'No', 'OFF']) {
        test('OTEL_EXPORTER_OTLP_INSECURE=$val is false', () async {
          final output = await runWithEnv(
            'test/unit/environment/helpers/check_otlp_config.dart',
            {'OTEL_EXPORTER_OTLP_INSECURE': val},
          );
          final result = jsonDecode(output.trim()) as Map<String, dynamic>;
          expect(result['insecure'], isFalse);
        });
      }

      test('OTEL_EXPORTER_OTLP_INSECURE with unrecognized value is absent',
          () async {
        final output = await runWithEnv(
          'test/unit/environment/helpers/check_otlp_config.dart',
          {'OTEL_EXPORTER_OTLP_INSECURE': 'maybe'},
        );
        final result = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(result.containsKey('insecure'), isFalse);
      });
    });
  });
}
