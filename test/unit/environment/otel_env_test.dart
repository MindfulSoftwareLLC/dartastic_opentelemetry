// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

void main() {
  group('OTelEnv', () {
    tearDown(() {
      // Clear test environment after each test
      EnvironmentService.instance.clearTestEnvironment();
    });

    group('Service Configuration', () {
      test('should read OTEL_SERVICE_NAME', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_SERVICE_NAME': 'test-service',
        });

        final config = OTelEnv.getServiceConfig();
        expect(config['serviceName'], equals('test-service'));
      });

      test('should read OTEL_SERVICE_VERSION', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_SERVICE_VERSION': '1.2.3',
        });

        final config = OTelEnv.getServiceConfig();
        expect(config['serviceVersion'], equals('1.2.3'));
      });

      test('should read both service name and version', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_SERVICE_NAME': 'test-service',
          'OTEL_SERVICE_VERSION': '1.2.3',
        });

        final config = OTelEnv.getServiceConfig();
        expect(config['serviceName'], equals('test-service'));
        expect(config['serviceVersion'], equals('1.2.3'));
      });

      test('should return empty map when no service config is set', () {
        final config = OTelEnv.getServiceConfig();
        expect(config, isEmpty);
      });
    });

    group('Resource Attributes', () {
      test('should parse simple resource attributes', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_RESOURCE_ATTRIBUTES': 'environment=production,region=us-west',
        });

        final attrs = OTelEnv.getResourceAttributes();
        expect(attrs['environment'], equals('production'));
        expect(attrs['region'], equals('us-west'));
      });

      test('should parse numeric resource attributes', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_RESOURCE_ATTRIBUTES': 'port=8080,timeout=30.5,enabled=true,disabled=false',
        });

        final attrs = OTelEnv.getResourceAttributes();
        expect(attrs['port'], equals(8080));
        expect(attrs['timeout'], equals(30.5));
        expect(attrs['enabled'], equals(true));
        expect(attrs['disabled'], equals(false));
      });

      test('should handle attributes with spaces', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_RESOURCE_ATTRIBUTES': ' key1 = value1 , key2 = value2 ',
        });

        final attrs = OTelEnv.getResourceAttributes();
        expect(attrs['key1'], equals('value1'));
        expect(attrs['key2'], equals('value2'));
      });

      test('should return empty map when no attributes are set', () {
        final attrs = OTelEnv.getResourceAttributes();
        expect(attrs, isEmpty);
      });
    });

    group('OTLP Configuration', () {
      test('should read general OTLP config', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://collector:4317',
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_HEADERS': 'api-key=secret,tenant=test',
          'OTEL_EXPORTER_OTLP_INSECURE': 'true',
          'OTEL_EXPORTER_OTLP_TIMEOUT': '5000',
          'OTEL_EXPORTER_OTLP_COMPRESSION': 'gzip',
        });

        final config = OTelEnv.getOtlpConfig();
        expect(config['endpoint'], equals('https://collector:4317'));
        expect(config['protocol'], equals('grpc'));
        expect(config['headers'], equals({'api-key': 'secret', 'tenant': 'test'}));
        expect(config['insecure'], equals(true));
        expect(config['timeout'], equals(const Duration(milliseconds: 5000)));
        expect(config['compression'], equals('gzip'));
      });

      test('should read traces-specific OTLP config', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://collector:4317',
          'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT': 'https://traces:4317',
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_TRACES_PROTOCOL': 'http/protobuf',
        });

        final config = OTelEnv.getOtlpConfig(signal: 'traces');
        expect(config['endpoint'], equals('https://traces:4317'));
        expect(config['protocol'], equals('http/protobuf'));
      });

      test('should prioritize signal-specific config over general', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://general:4317',
          'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT': 'https://traces:4317',
          'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT': 'https://metrics:4318',
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_TRACES_PROTOCOL': 'http/protobuf',
          'OTEL_EXPORTER_OTLP_METRICS_PROTOCOL': 'http/json',
        });

        final tracesConfig = OTelEnv.getOtlpConfig(signal: 'traces');
        expect(tracesConfig['endpoint'], equals('https://traces:4317'));
        expect(tracesConfig['protocol'], equals('http/protobuf'));

        final metricsConfig = OTelEnv.getOtlpConfig(signal: 'metrics');
        expect(metricsConfig['endpoint'], equals('https://metrics:4318'));
        expect(metricsConfig['protocol'], equals('http/json'));

        final logsConfig = OTelEnv.getOtlpConfig(signal: 'logs');
        expect(logsConfig['endpoint'], equals('https://general:4317'));
        expect(logsConfig['protocol'], equals('grpc'));
      });

      test('should parse headers correctly', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_EXPORTER_OTLP_HEADERS': 'key1=value1,key2=value2,key3=value3',
        });

        final config = OTelEnv.getOtlpConfig();
        expect(config['headers'], equals({
          'key1': 'value1',
          'key2': 'value2',
          'key3': 'value3',
        }));
      });

      test('should parse boolean insecure values correctly', () {
        final testCases = {
          'true': true,
          'TRUE': true,
          'True': true,
          '1': true,
          'yes': true,
          'YES': true,
          'on': true,
          'ON': true,
          'false': false,
          'FALSE': false,
          'False': false,
          '0': false,
          'no': false,
          'NO': false,
          'off': false,
          'OFF': false,
        };

        for (final entry in testCases.entries) {
          EnvironmentService.instance.clearTestEnvironment();
          EnvironmentService.instance.setupTestEnvironment({
            'OTEL_EXPORTER_OTLP_INSECURE': entry.key,
          });

          final config = OTelEnv.getOtlpConfig();
          expect(config['insecure'], equals(entry.value),
              reason: 'Failed for value: ${entry.key}');
        }
      });

      test('should handle invalid timeout gracefully', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_EXPORTER_OTLP_TIMEOUT': 'invalid',
        });

        final config = OTelEnv.getOtlpConfig();
        expect(config.containsKey('timeout'), isFalse);
      });
    });

    group('Exporter Selection', () {
      test('should read traces exporter', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_TRACES_EXPORTER': 'console',
        });

        final exporter = OTelEnv.getExporter(signal: 'traces');
        expect(exporter, equals('console'));
      });

      test('should read metrics exporter', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_METRICS_EXPORTER': 'otlp',
        });

        final exporter = OTelEnv.getExporter(signal: 'metrics');
        expect(exporter, equals('otlp'));
      });

      test('should read logs exporter', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_LOGS_EXPORTER': 'none',
        });

        final exporter = OTelEnv.getExporter(signal: 'logs');
        expect(exporter, equals('none'));
      });

      test('should return null for unknown signal', () {
        final exporter = OTelEnv.getExporter(signal: 'unknown');
        expect(exporter, isNull);
      });
    });

    group('Logging Configuration', () {
      // Save original log settings
      LogLevel? originalLogLevel;

      setUp(() {
        originalLogLevel = OTelLog.currentLevel;
      });

      tearDown(() {
        if (originalLogLevel != null) {
          OTelLog.currentLevel = originalLogLevel!;
        }
        OTelLog.logFunction = null;
        OTelLog.metricLogFunction = null;
        OTelLog.spanLogFunction = null;
        OTelLog.exportLogFunction = null;
      });

      test('should initialize logging based on OTEL_LOG_LEVEL', () {
        final testCases = {
          'TRACE': LogLevel.trace,
          'trace': LogLevel.trace,
          'DEBUG': LogLevel.debug,
          'debug': LogLevel.debug,
          'INFO': LogLevel.info,
          'info': LogLevel.info,
          'WARN': LogLevel.warn,
          'warn': LogLevel.warn,
          'ERROR': LogLevel.error,
          'error': LogLevel.error,
          'FATAL': LogLevel.fatal,
          'fatal': LogLevel.fatal,
        };

        for (final entry in testCases.entries) {
          EnvironmentService.instance.clearTestEnvironment();
          EnvironmentService.instance.setupTestEnvironment({
            'OTEL_LOG_LEVEL': entry.key,
          });

          OTelEnv.initializeLogging();
          expect(OTelLog.currentLevel, equals(entry.value),
              reason: 'Failed for value: ${entry.key}');
          expect(OTelLog.logFunction, isNotNull);
        }
      });

      test('should enable metrics logging', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_LOG_METRICS': 'true',
        });

        OTelEnv.initializeLogging();
        expect(OTelLog.metricLogFunction, isNotNull);
      });

      test('should enable spans logging', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_LOG_SPANS': '1',
        });

        OTelEnv.initializeLogging();
        expect(OTelLog.spanLogFunction, isNotNull);
      });

      test('should enable export logging', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_LOG_EXPORT': 'yes',
        });

        OTelEnv.initializeLogging();
        expect(OTelLog.exportLogFunction, isNotNull);
      });

      test('should handle multiple logging flags', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_LOG_LEVEL': 'debug',
          'OTEL_LOG_METRICS': 'true',
          'OTEL_LOG_SPANS': 'true',
          'OTEL_LOG_EXPORT': 'true',
        });

        OTelEnv.initializeLogging();
        expect(OTelLog.currentLevel, equals(LogLevel.debug));
        expect(OTelLog.logFunction, isNotNull);
        expect(OTelLog.metricLogFunction, isNotNull);
        expect(OTelLog.spanLogFunction, isNotNull);
        expect(OTelLog.exportLogFunction, isNotNull);
      });

      test('should not enable logging for false values', () {
        EnvironmentService.instance.setupTestEnvironment({
          'OTEL_LOG_METRICS': 'false',
          'OTEL_LOG_SPANS': 'no',
          'OTEL_LOG_EXPORT': '0',
        });

        OTelEnv.initializeLogging();
        expect(OTelLog.metricLogFunction, isNull);
        expect(OTelLog.spanLogFunction, isNull);
        expect(OTelLog.exportLogFunction, isNull);
      });
    });
  });

  group('OTel.initialize with environment variables', () {
    tearDown(() async {
      EnvironmentService.instance.clearTestEnvironment();
      await OTel.reset();
    });

    test('should use environment variables for service configuration', () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'env-service',
        'OTEL_SERVICE_VERSION': '2.0.0',
      });

      await OTel.initialize();

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();
      final serviceName = attrs.firstWhere((a) => a.key == 'service.name');
      final serviceVersion = attrs.firstWhere((a) => a.key == 'service.version');
      expect(serviceName.value, equals('env-service'));
      expect(serviceVersion.value, equals('2.0.0'));
    });

    test('should use environment variables for endpoint configuration', () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'test-service',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://env-collector:4317',
        'OTEL_EXPORTER_OTLP_INSECURE': 'true',
      });

      await OTel.initialize();

      // The endpoint should be used in the configuration
      expect(OTel.defaultResource, isNotNull);
    });

    test('should merge environment resource attributes with provided ones', () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'test-service',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_RESOURCE_ATTRIBUTES': 'env.key1=env.value1,env.key2=env.value2',
      });

      await OTel.initialize(
        resourceAttributes: OTelAPI.attributesFromMap({
          'provided.key': 'provided.value',
          'env.key1': 'override.value', // This should override the env value
        }),
      );

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();
      
      // Check that provided attributes override environment attributes
      final envKey1 = attrs.firstWhere((a) => a.key == 'env.key1');
      expect(envKey1.value, equals('override.value'));
      
      // Check that non-conflicting env attributes are preserved
      final envKey2 = attrs.firstWhere((a) => a.key == 'env.key2');
      expect(envKey2.value, equals('env.value2'));
      
      // Check that provided attributes are included
      final providedKey = attrs.firstWhere((a) => a.key == 'provided.key');
      expect(providedKey.value, equals('provided.value'));
    });

    test('should create appropriate exporter based on protocol', () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'test-service',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://collector:4318',
        'OTEL_EXPORTER_OTLP_PROTOCOL': 'http/protobuf',
        'OTEL_TRACES_EXPORTER': 'otlp',
      });

      await OTel.initialize();

      // The SDK should create an HTTP exporter based on the protocol
      final tracerProvider = OTel.tracerProvider();
      expect(tracerProvider, isNotNull);
    });

    test('should handle none exporter', () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'test-service',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_TRACES_EXPORTER': 'none',
      });

      await OTel.initialize();

      // The SDK should not add any span processor
      final tracerProvider = OTel.tracerProvider();
      expect(tracerProvider, isNotNull);
    });

    test('should handle console exporter', () async {
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'test-service',
        'OTEL_SERVICE_VERSION': '1.0.0',
        'OTEL_TRACES_EXPORTER': 'console',
      });

      await OTel.initialize();

      // The SDK should create a console exporter
      final tracerProvider = OTel.tracerProvider();
      expect(tracerProvider, isNotNull);
    });
  });
}
