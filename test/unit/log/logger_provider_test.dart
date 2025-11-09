// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('LoggerProvider Tests', () {
    late LoggerProvider loggerProvider;

    setUp(() async {
      await OTel.reset();

      // Initialize OTel
      await OTel.initialize(
        serviceName: 'logger-provider-test-service',
        detectPlatformResources: false,
      );

      loggerProvider = OTel.loggerProvider();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('LoggerProvider properties reflect API delegate', () {
      // Set properties
      loggerProvider.endpoint = 'https://test-endpoint';
      loggerProvider.serviceName = 'updated-service-name';
      loggerProvider.serviceVersion = '1.2.3';
      loggerProvider.enabled = false;

      // Verify properties
      expect(loggerProvider.endpoint, equals('https://test-endpoint'));
      expect(loggerProvider.serviceName, equals('updated-service-name'));
      expect(loggerProvider.serviceVersion, equals('1.2.3'));
      expect(loggerProvider.enabled, isFalse);

      // Reset enabled back to true for other tests
      loggerProvider.enabled = true;
    });

    test('LoggerProvider returns same logger for same configuration', () {
      final logger1 = loggerProvider.getLogger('test-logger');
      final logger2 = loggerProvider.getLogger('test-logger');
      final logger3 = loggerProvider.getLogger('different-logger');

      // Same name should return same logger
      expect(identical(logger1, logger2), isTrue);

      // Different name should return different logger
      expect(identical(logger1, logger3), isFalse);
    });

    test('ensureResourceIsSet sets resource if null', () {
      // Initially resource is default from OTel.initialize
      expect(loggerProvider.resource, isNotNull);

      // Set resource to null
      loggerProvider.resource = null;
      expect(loggerProvider.resource, isNull);

      // Call ensureResourceIsSet
      loggerProvider.ensureResourceIsSet();

      // Resource should now be set to default
      expect(loggerProvider.resource, isNotNull);
      expect(loggerProvider.resource, equals(OTel.defaultResource));
    });

    test('resource can be set and retrieved', () {
      final newResource =
          OTel.resource({'custom.key': 'custom.value'}.toAttributes());

      loggerProvider.resource = newResource;
      expect(loggerProvider.resource, equals(newResource));
    });
  });
}
