// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    as api;
import 'package:test/test.dart';

// Regression for #50 against dartastic_opentelemetry_api >= 1.0.0-beta.8:
// the API lazily installs its no-op factory whenever API code runs before
// the SDK initializes (e.g. OTel.initialize() itself parses
// OTEL_RESOURCE_ATTRIBUTES through the API before its once-only guard).
// The auto-installed no-op reports isAPIFactory == true and must be
// replaced by initialize(), not treated as prior initialization.
//
// This must run before anything else in the process installs a factory, so
// it lives in its own file — the `test` package runs each test file in its
// own isolate, giving a pristine (uninitialized) copy of all library statics.
void main() {
  tearDown(() async {
    await OTel.reset();
  });

  test('OTel.initialize succeeds after API code installs the no-op factory',
      () async {
    api.OTelAPI.attributesFromMap({'service.namespace': 'test'});
    expect(OTelFactory.otelFactory, isNotNull);
    expect(OTelFactory.otelFactory!.isAPIFactory, isTrue);

    await OTel.initialize(
      serviceName: 'api-first-service',
      detectPlatformResources: false,
    );
    expect(OTelFactory.otelFactory, isA<OTelSDKFactory>());
    expect(OTel.tracerProvider(), isA<TracerProvider>());
  });
}
