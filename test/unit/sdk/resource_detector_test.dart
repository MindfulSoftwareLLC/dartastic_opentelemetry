// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io' as io;

import 'package:dartastic_opentelemetry/src/environment/environment_service/environment_service.dart';
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/resource/resource.dart';
import 'package:dartastic_opentelemetry/src/resource/resource_detector.dart';
import 'package:test/test.dart';

void main() {
  group('ResourceDetector Tests', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize();
    });

    test('ProcessResourceDetector provides basic process information',
        () async {
      final detector = ProcessResourceDetector();
      final resource = await detector.detect();
      final attrs = resource.attributes.toMap();

      expect(attrs['process.executable.name']?.value, isNotEmpty);
      expect(attrs['process.runtime.name']?.value, equals('dart'));
      expect(attrs['process.runtime.version']?.value, isNotEmpty);
      expect(attrs['process.num_threads']?.value, isNotNull);
    });

    test('HostResourceDetector provides host information on macOS', () async {
      // Skip if not on macOS
      if (!io.Platform.isMacOS) {
        return;
      }

      final detector = HostResourceDetector();
      final resource = await detector.detect();
      final attrs = resource.attributes.toMap();

      expect(attrs['host.name']?.value, isNotEmpty);
      expect(attrs['host.arch']?.value, isNotEmpty);
      expect(attrs['host.processors']?.value, greaterThan(0));
      expect(attrs['host.os.name']?.value, equals('macos'));
      expect(attrs['host.locale']?.value, isNotEmpty);
      expect(attrs['os.type']?.value, equals('macos'));
      expect(attrs['os.version']?.value, isNotEmpty);
    });

    test('EnvVarResourceDetector handles OTEL_RESOURCE_ATTRIBUTES', () async {
      final envService = EnvironmentService.instance;
      envService.setupTestEnvironment({
        'OTEL_RESOURCE_ATTRIBUTES':
            'key1=value1,key2=value2,key3=value%20with%20spaces'
      });

      final detector = EnvVarResourceDetector(envService);
      final resource = await detector.detect();
      final attrs = resource.attributes.toMap();

      expect(attrs['key1']?.value, equals('value1'));
      expect(attrs['key2']?.value, equals('value2'));
      expect(attrs['key3']?.value, equals('value with spaces'));

      // Cleanup
      envService.clearTestEnvironment();
    });

    test('EnvVarResourceDetector handles escaped commas', () async {
      final envService = EnvironmentService.instance;
      envService.setupTestEnvironment(
          {'OTEL_RESOURCE_ATTRIBUTES': 'key1=value1\\,part2,key2=value2'});

      final detector = EnvVarResourceDetector(envService);
      final resource = await detector.detect();
      final attrs = resource.attributes.toMap();

      expect(attrs['key1']?.value, equals('value1,part2'));
      expect(attrs['key2']?.value, equals('value2'));

      // Cleanup
      envService.clearTestEnvironment();
    });

    test('CompositeResourceDetector combines multiple detectors', () async {
      // Skip if not on macOS
      if (!io.Platform.isMacOS) {
        return;
      }

      final detector = CompositeResourceDetector([
        ProcessResourceDetector(),
        HostResourceDetector(),
      ]);

      final resource = await detector.detect();
      final attrs = resource.attributes.toMap();

      // Process attributes
      expect(attrs['process.executable.name']?.value, isNotEmpty);
      expect(attrs['process.runtime.name']?.value, equals('dart'));

      // Host attributes
      expect(attrs['host.name']?.value, isNotEmpty);
      expect(attrs['os.type']?.value, equals('macos'));
    });

    test('CompositeResourceDetector continues after detector failure',
        () async {
      final failingDetector = _FailingResourceDetector();
      final workingDetector = ProcessResourceDetector();

      final detector = CompositeResourceDetector([
        failingDetector,
        workingDetector,
      ]);

      final resource = await detector.detect();
      final attrs = resource.attributes.toMap();

      // Should still have process attributes despite the failing detector
      expect(attrs['process.executable.name']?.value, isNotEmpty);
      expect(attrs['process.runtime.name']?.value, equals('dart'));
    });

    test('PlatformResourceDetector creates appropriate detectors', () async {
      final detector = PlatformResourceDetector.create();
      final resource = await detector.detect();
      final attrs = resource.attributes.toMap();

      // Should have both process and host information
      expect(attrs['process.runtime.name']?.value, equals('dart'));
      expect(attrs['host.name']?.value, isNotEmpty);
    });
  });
}

class _FailingResourceDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    throw Exception('Simulated detector failure');
  }
}
