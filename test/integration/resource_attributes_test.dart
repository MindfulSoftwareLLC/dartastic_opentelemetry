// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Integration tests for OTEL_RESOURCE_ATTRIBUTES environment variable
// Run with actual environment variables or --dart-define flags
// via tool/test_all_env_vars.sh

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OTEL_RESOURCE_ATTRIBUTES Integration Tests', () {
    tearDown(() async {
      await OTel.reset();
    });

    test('EnvVarResourceDetector reads OTEL_RESOURCE_ATTRIBUTES from env',
        () async {
      final envService = EnvironmentService.instance;
      final resourceAttrs = envService.getValue(otelResourceAttributes);

      // Test only runs if OTEL_RESOURCE_ATTRIBUTES is set
      if (resourceAttrs != null && resourceAttrs.isNotEmpty) {
        final detector = EnvVarResourceDetector(envService);
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        // Verify at least one attribute was parsed
        expect(attrs.isNotEmpty, isTrue);
      }
    });

    test('handles URL-encoded spaces in resource attributes', () async {
      final envService = EnvironmentService.instance;
      final resourceAttrs = envService.getValue(otelResourceAttributes);

      // This test expects: OTEL_RESOURCE_ATTRIBUTES="key3=value%20with%20spaces"
      if (resourceAttrs != null && resourceAttrs.contains('%20')) {
        final detector = EnvVarResourceDetector(envService);
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        // Should decode %20 to spaces
        final key3Value = attrs['key3']?.value;
        if (key3Value != null) {
          expect(key3Value, contains(' '));
        }
      }
    });

    test('handles escaped commas in resource attributes', () async {
      final envService = EnvironmentService.instance;
      final resourceAttrs = envService.getValue(otelResourceAttributes);

      // This test expects: OTEL_RESOURCE_ATTRIBUTES="key1=value1\\,part2"
      if (resourceAttrs != null && resourceAttrs.contains('\\,')) {
        final detector = EnvVarResourceDetector(envService);
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        // Should handle escaped commas
        final key1Value = attrs['key1']?.value as String?;
        if (key1Value != null) {
          expect(key1Value, contains(','));
        }
      }
    });

    test('resource attributes available in OTel.initialize()', () async {
      final serviceName = EnvironmentService.instance.getValue(otelServiceName);
      
      await OTel.initialize();

      final resource = OTel.defaultResource;
      expect(resource, isNotNull);

      final attrs = resource!.attributes.toMap();
      
      // Service name should be set
      final serviceNameAttr = attrs['service.name'];
      expect(serviceNameAttr, isNotNull);

      // If env var was set, it should match
      if (serviceName != null && serviceName.isNotEmpty) {
        expect(serviceNameAttr!.value, equals(serviceName));
      }
    });
  });
}
