// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/version.dart';
import 'package:test/test.dart';

void main() {
  test('Basic initialization works', () async {
    // Simple test to see if basic initialization works
    await OTel.initialize(serviceName: 'test-service', serviceVersion: '1.0.0');

    expect(OTel.defaultResource, isNotNull);

    final attrs = OTel.defaultResource!.attributes.toList();
    final serviceName = attrs.firstWhere((a) => a.key == 'service.name');
    expect(serviceName.value, equals('test-service'));

    await OTel.reset();
  });

  test('Default resource includes telemetry.sdk.* attributes', () async {
    await OTel.initialize(serviceName: 'test-service');

    final attrs = OTel.defaultResource!.attributes.toList();

    final sdkLanguage =
        attrs.firstWhere((a) => a.key == 'telemetry.sdk.language');
    expect(sdkLanguage.value, equals('dart'));

    final sdkName = attrs.firstWhere((a) => a.key == 'telemetry.sdk.name');
    expect(sdkName.value, equals('opentelemetry'));

    final sdkVersion =
        attrs.firstWhere((a) => a.key == 'telemetry.sdk.version');
    expect(sdkVersion.value, equals(packageVersion));

    await OTel.reset();
  });
}
