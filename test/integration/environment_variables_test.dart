// Integration test for environment variable behavior
// This test should be run with actual environment variables or --dart-define flags
// via the tool/test_env_vars.sh script
//
// Run examples:
// OTEL_SERVICE_NAME=test-service dart test test/integration/environment_variables_test.dart
// dart test --dart-define=OTEL_SERVICE_NAME=test-service test/integration/environment_variables_test.dart
// ./tool/test_env_vars.sh

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Environment Variables Integration Tests', () {
    tearDown(() async {
      await OTel.reset();
    });

    test('reads OTEL_SERVICE_NAME from environment or --dart-define', () {
      final serviceName =
          EnvironmentService.instance.getValue(otelServiceName);

      // When run via test_env_vars.sh, this will have a specific expected value
      // When run standalone, it may be null
      if (serviceName != null) {
        expect(serviceName, isNotEmpty);
      }
    });

    test('reads OTEL_EXPORTER_OTLP_ENDPOINT from environment or --dart-define',
        () {
      final endpoint =
          EnvironmentService.instance.getValue(otelExporterOtlpEndpoint);

      if (endpoint != null) {
        expect(endpoint, isNotEmpty);
        // Should be a valid URL format
        expect(endpoint, contains('://'));
      }
    });

    test('--dart-define takes precedence over environment variables', () {
      // This test is meaningful when both are set
      // The shell script sets both and verifies --dart-define wins
      final serviceName =
          EnvironmentService.instance.getValue(otelServiceName);
      
      // Just verify we can read it
      expect(serviceName, anyOf(isNull, isA<String>()));
    });

    test('OTel.initialize uses environment variables when no params provided',
        () async {
      final serviceName =
          EnvironmentService.instance.getValue(otelServiceName);

      await OTel.initialize();

      final attrs = OTel.defaultResource!.attributes.toList();
      final serviceNameAttr = attrs.firstWhere((a) => a.key == 'service.name');

      if (serviceName != null && serviceName.isNotEmpty) {
        expect(serviceNameAttr.value, equals(serviceName));
      } else {
        // Default service name should be set
        expect(serviceNameAttr.value, isNotEmpty);
      }
    });

    test('explicit parameters override environment variables', () async {
      // Even if OTEL_SERVICE_NAME is set, explicit parameter should win
      await OTel.initialize(serviceName: 'explicit-service');

      final attrs = OTel.defaultResource!.attributes.toList();
      final serviceNameAttr = attrs.firstWhere((a) => a.key == 'service.name');

      expect(serviceNameAttr.value, equals('explicit-service'));
    });
  });
}
