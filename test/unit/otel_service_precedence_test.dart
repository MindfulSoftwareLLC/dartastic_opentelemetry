// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Precedence of service.name and service.version at initialization.
//
// The spec requires, highest to lowest:
//   explicit argument
//     > OTEL_SERVICE_NAME
//       > service.name in OTEL_RESOURCE_ATTRIBUTES
//         > default
//
// Regression coverage for #103: OTEL_RESOURCE_ATTRIBUTES was applied twice,
// once via EnvVarResourceDetector (correctly, below the service resource) and
// once folded into resourceAttributes and merged last at the highest
// precedence. The second copy overrode both rungs above it, so an explicit
// serviceName argument silently lost to an environment variable.
//
// Both merge paths are covered: detectPlatformResources true routes
// OTEL_RESOURCE_ATTRIBUTES through EnvVarResourceDetector, false does not.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// The value of [key] in [resource], or null when absent.
String? attributeOf(Resource resource, String key) {
  for (final attribute in resource.attributes.toList()) {
    if (attribute.key == key) return '${attribute.value}';
  }
  return null;
}

void main() {
  group('service.name / service.version precedence', () {
    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
      EnvironmentService.testOverrides = null;
    });

    /// Initializes with [vars] as the entire environment and returns the
    /// resulting default resource.
    Future<Resource> initWith(
      Map<String, String> vars, {
      String? serviceName,
      String? serviceVersion,
      Attributes? resourceAttributes,
      bool detectPlatformResources = false,
    }) async {
      EnvironmentService.testOverrides = {
        'OTEL_TRACES_EXPORTER': 'none',
        'OTEL_METRICS_EXPORTER': 'none',
        'OTEL_LOGS_EXPORTER': 'none',
        ...vars,
      };
      await OTel.initialize(
        serviceName: serviceName,
        serviceVersion: serviceVersion,
        resourceAttributes: resourceAttributes,
        detectPlatformResources: detectPlatformResources,
        enableMetrics: false,
        enableLogs: false,
      );
      return OTel.defaultResource!;
    }

    for (final detectPlatformResources in [false, true]) {
      final suffix = ' (detectPlatformResources: $detectPlatformResources)';

      test('explicit serviceName beats OTEL_RESOURCE_ATTRIBUTES$suffix',
          () async {
        final resource = await initWith(
          {'OTEL_RESOURCE_ATTRIBUTES': 'service.name=from-resource-attrs'},
          serviceName: 'explicit-service',
          detectPlatformResources: detectPlatformResources,
        );
        expect(
          attributeOf(resource, 'service.name'),
          equals('explicit-service'),
        );
      });

      test('explicit serviceVersion beats OTEL_RESOURCE_ATTRIBUTES$suffix',
          () async {
        final resource = await initWith(
          {'OTEL_RESOURCE_ATTRIBUTES': 'service.version=8.8.8'},
          serviceVersion: '9.9.9',
          detectPlatformResources: detectPlatformResources,
        );
        expect(attributeOf(resource, 'service.version'), equals('9.9.9'));
      });

      test('OTEL_SERVICE_NAME beats OTEL_RESOURCE_ATTRIBUTES$suffix', () async {
        final resource = await initWith(
          {
            'OTEL_SERVICE_NAME': 'from-service-name',
            'OTEL_RESOURCE_ATTRIBUTES': 'service.name=from-resource-attrs',
          },
          detectPlatformResources: detectPlatformResources,
        );
        expect(
          attributeOf(resource, 'service.name'),
          equals('from-service-name'),
        );
      });

      test('OTEL_RESOURCE_ATTRIBUTES applies when nothing outranks it$suffix',
          () async {
        final resource = await initWith(
          {
            'OTEL_RESOURCE_ATTRIBUTES':
                'service.name=from-resource-attrs,service.version=8.8.8',
          },
          detectPlatformResources: detectPlatformResources,
        );
        expect(
          attributeOf(resource, 'service.name'),
          equals('from-resource-attrs'),
        );
        expect(attributeOf(resource, 'service.version'), equals('8.8.8'));
      });

      test('non-service attributes still come through$suffix', () async {
        final resource = await initWith(
          {
            'OTEL_RESOURCE_ATTRIBUTES':
                'service.name=from-resource-attrs,deployment.environment=staging',
          },
          serviceName: 'explicit-service',
          detectPlatformResources: detectPlatformResources,
        );
        // The service key is overridden, everything else is preserved.
        expect(
          attributeOf(resource, 'service.name'),
          equals('explicit-service'),
        );
        expect(
          attributeOf(resource, 'deployment.environment'),
          equals('staging'),
        );
      });
    }

    test('explicit resourceAttributes still beat the environment', () async {
      final resource = await initWith(
        {
          'OTEL_RESOURCE_ATTRIBUTES':
              'deployment.environment=staging,service.name=from-resource-attrs',
        },
        resourceAttributes: OTel.attributesFromMap({
          'deployment.environment': 'production',
        }),
      );
      expect(
        attributeOf(resource, 'deployment.environment'),
        equals('production'),
      );
    });

    test('defaults apply with an empty environment', () async {
      final resource = await initWith({});
      expect(attributeOf(resource, 'service.name'), isNotNull);
      expect(attributeOf(resource, 'service.name'), isNotEmpty);
      // service.version is not set when not provided (issue #204)
      expect(attributeOf(resource, 'service.version'), isNull);
    });
  });
}
