// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// OTEL_RESOURCE_ATTRIBUTES is operator-supplied text. A malformed value
// must degrade - the SDK drops what it cannot read and keeps running -
// never abort initialization. error-handling.md: the API and SDK must
// not throw unhandled exceptions for user misconfiguration.
//
// A throw here is worse than it looks: OTelFactory is installed before
// resource detection, so the caller cannot even retry - the second
// initialize() reports "can only be called once" while no processors
// were ever installed.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('malformed OTEL_RESOURCE_ATTRIBUTES does not abort initialize', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      EnvironmentService.testOverrides = null;
      await OTel.reset();
    });

    // Each row is a value an operator could plausibly type.
    const malformed = <(String, String)>[
      ('a bare percent sign', 'discount=50%'),
      ('an invalid escape', 'note=%zz'),
      ('an incomplete escape at the end', 'note=abc%'),
    ];

    for (final (label, value) in malformed) {
      test('survives $label', () async {
        EnvironmentService.testOverrides = {
          'OTEL_RESOURCE_ATTRIBUTES': value,
        };

        await expectLater(
          OTel.initialize(
            serviceName: 'resilience-test',
            detectPlatformResources: false,
          ),
          completes,
          reason: 'a value the parser cannot decode must be dropped with a '
              'diagnostic, not thrown out of initialize',
        );

        // And the SDK must be usable afterwards, not half-built.
        expect(OTel.defaultResource, isNotNull);
        expect(
          OTel.defaultResource!.attributes.getString('service.name'),
          equals('resilience-test'),
          reason: 'attributes that parsed fine must still reach the resource',
        );
      });
    }

    test('a well-formed value still lands', () async {
      EnvironmentService.testOverrides = {
        'OTEL_RESOURCE_ATTRIBUTES': 'deployment.environment=staging',
      };

      await OTel.initialize(
        serviceName: 'resilience-test',
        detectPlatformResources: false,
      );

      expect(
        OTel.defaultResource!.attributes.getString('deployment.environment'),
        equals('staging'),
      );
    });
  });
}
