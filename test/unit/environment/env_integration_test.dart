// Test to verify environment variable behavior
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Initialize with and without environment variables', () {
    tearDown(() async {
      await OTel.reset();
      EnvironmentService.instance.clearTestEnvironment();
    });

    test('initialize with explicit parameters ignores environment variables', () async {
      // Set environment variables
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'env-service',
        'OTEL_SERVICE_VERSION': '9.9.9',
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://env-endpoint:9999',
      });

      // Initialize with explicit values
      await OTel.initialize(
        serviceName: 'explicit-service',
        serviceVersion: '1.2.3',
        endpoint: 'https://explicit:4317',
      );

      // Should use explicit values, not environment values
      final attrs = OTel.defaultResource!.attributes.toList();
      final serviceName = attrs.firstWhere((a) => a.key == 'service.name');
      final serviceVersion = attrs.firstWhere((a) => a.key == 'service.version');
      
      expect(serviceName.value, equals('explicit-service'));
      expect(serviceVersion.value, equals('1.2.3'));
    });

    test('initialize with default values as explicit parameters ignores environment variables', () async {
      // Set environment variables
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'env-service',
        'OTEL_SERVICE_VERSION': '9.9.9',
      });

      // Initialize with explicit values that match defaults
      await OTel.initialize(
        serviceName: '@dart/dartastic_opentelemetry', // Same as default
        serviceVersion: '1.0.0', // Same as default
      );

      // Should use explicit values (even though they match defaults), not environment values
      final attrs = OTel.defaultResource!.attributes.toList();
      final serviceName = attrs.firstWhere((a) => a.key == 'service.name');
      final serviceVersion = attrs.firstWhere((a) => a.key == 'service.version');
      
      expect(serviceName.value, equals('@dart/dartastic_opentelemetry'));
      expect(serviceVersion.value, equals('1.0.0'));
    });

    test('initialize without parameters uses environment variables', () async {
      // Set environment variables
      EnvironmentService.instance.setupTestEnvironment({
        'OTEL_SERVICE_NAME': 'env-service',
        'OTEL_SERVICE_VERSION': '9.9.9',
      });

      // Initialize without parameters
      await OTel.initialize();

      // Should use environment values
      final attrs = OTel.defaultResource!.attributes.toList();
      final serviceName = attrs.firstWhere((a) => a.key == 'service.name');
      final serviceVersion = attrs.firstWhere((a) => a.key == 'service.version');
      
      expect(serviceName.value, equals('env-service'));
      expect(serviceVersion.value, equals('9.9.9'));
    });

    test('initialize without environment uses defaults', () async {
      // No environment variables set

      // Initialize without parameters
      await OTel.initialize();

      // Should use default values
      final attrs = OTel.defaultResource!.attributes.toList();
      final serviceName = attrs.firstWhere((a) => a.key == 'service.name');
      final serviceVersion = attrs.firstWhere((a) => a.key == 'service.version');
      
      expect(serviceName.value, equals('@dart/dartastic_opentelemetry'));
      expect(serviceVersion.value, equals('1.0.0'));
    });

    test('basic factory test still works', () async {
      await OTel.initialize(serviceName: 'test-service');
      
      final tracer = OTel.tracer();
      expect(tracer, isNotNull);
      
      final span = tracer.startSpan('test');
      expect(span, isNotNull);
      span.end();
    });
  });
}
