// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io' as io;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

/// A custom detector that returns a resource with the given attributes.
class _TestDetector implements ResourceDetector {
  final Map<String, Object> attrs;
  _TestDetector(this.attrs);

  @override
  Future<Resource> detect() async {
    return ResourceCreate.create(
        OTelFactory.otelFactory!.attributesFromMap(attrs));
  }
}

/// A detector that always throws, used to test error handling in
/// CompositeResourceDetector.
class _FailingDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    throw Exception('Simulated detector failure');
  }
}

void main() {
  group('ResourceDetector Tests', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
          serviceName: 'test', detectPlatformResources: false);
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    // ---------------------------------------------------------------
    // ProcessResourceDetector
    // ---------------------------------------------------------------
    group('ProcessResourceDetector', () {
      test('detect() returns resource with process attributes', () async {
        final detector = ProcessResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        expect(attrs, isNotEmpty);
        expect(attrs.containsKey('process.executable.name'), isTrue);
        expect(attrs.containsKey('process.command_line'), isTrue);
        expect(attrs.containsKey('process.runtime.name'), isTrue);
        expect(attrs.containsKey('process.runtime.version'), isTrue);
        expect(attrs.containsKey('process.num_threads'), isTrue);
      });

      test('detect() includes process.executable.name', () async {
        final detector = ProcessResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        // The executable name should be a non-empty string matching
        // Platform.executable (the dart binary path).
        final executableName = attrs['process.executable.name']?.value;
        expect(executableName, isA<String>());
        expect((executableName as String).isNotEmpty, isTrue);
        expect(executableName, equals(io.Platform.executable));
      });

      test('detect() includes process.runtime.name as dart', () async {
        final detector = ProcessResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        expect(attrs['process.runtime.name']?.value, equals('dart'));
      });

      test('detect() includes process.runtime.version', () async {
        final detector = ProcessResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        final version = attrs['process.runtime.version']?.value;
        expect(version, isA<String>());
        expect(version, equals(io.Platform.version));
      });

      test('detect() includes process.num_threads as string', () async {
        final detector = ProcessResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        final numThreads = attrs['process.num_threads']?.value;
        expect(numThreads, isA<String>());
        expect(numThreads, equals(io.Platform.numberOfProcessors.toString()));
      });

      test('detect() includes process.command_line', () async {
        final detector = ProcessResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        // command_line is the joined executable arguments; it may be empty
        // in a test context but should be present.
        expect(attrs.containsKey('process.command_line'), isTrue);
        expect(attrs['process.command_line']?.value, isA<String>());
      });
    });

    // ---------------------------------------------------------------
    // HostResourceDetector
    // ---------------------------------------------------------------
    group('HostResourceDetector', () {
      test('detect() returns resource with host attributes', () async {
        final detector = HostResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        expect(attrs, isNotEmpty);
        expect(attrs.containsKey('host.name'), isTrue);
        expect(attrs.containsKey('host.arch'), isTrue);
        expect(attrs.containsKey('host.processors'), isTrue);
        expect(attrs.containsKey('host.os.name'), isTrue);
        expect(attrs.containsKey('host.locale'), isTrue);
        expect(attrs.containsKey('os.version'), isTrue);
      });

      test('detect() includes host.name', () async {
        final detector = HostResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        final hostName = attrs['host.name']?.value;
        expect(hostName, isA<String>());
        expect((hostName as String).isNotEmpty, isTrue);
        expect(hostName, equals(io.Platform.localHostname));
      });

      test('detect() includes os.type matching the current platform', () async {
        final detector = HostResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        expect(attrs.containsKey('os.type'), isTrue);
        final osType = attrs['os.type']?.value as String;

        if (io.Platform.isLinux) {
          expect(osType, equals('linux'));
        } else if (io.Platform.isWindows) {
          expect(osType, equals('windows'));
        } else if (io.Platform.isMacOS) {
          expect(osType, equals('macos'));
        } else if (io.Platform.isAndroid) {
          expect(osType, equals('android'));
        } else if (io.Platform.isIOS) {
          expect(osType, equals('ios'));
        }
      });

      test('detect() includes host.os.name', () async {
        final detector = HostResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        final osName = attrs['host.os.name']?.value;
        expect(osName, isA<String>());
        expect((osName as String).isNotEmpty, isTrue);
        expect(osName, equals(io.Platform.operatingSystem));
      });

      test('detect() includes host.processors as integer', () async {
        final detector = HostResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        final processors = attrs['host.processors']?.value;
        expect(processors, isA<int>());
        expect(processors as int, greaterThan(0));
        expect(processors, equals(io.Platform.numberOfProcessors));
      });

      test('detect() includes os.version', () async {
        final detector = HostResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        final osVersion = attrs['os.version']?.value;
        expect(osVersion, isA<String>());
        expect((osVersion as String).isNotEmpty, isTrue);
        expect(osVersion, equals(io.Platform.operatingSystemVersion));
      });

      test('detect() includes host.locale', () async {
        final detector = HostResourceDetector();
        final resource = await detector.detect();
        final attrs = resource.attributes.toMap();

        final locale = attrs['host.locale']?.value;
        expect(locale, isA<String>());
        expect((locale as String).isNotEmpty, isTrue);
        expect(locale, equals(io.Platform.localeName));
      });
    });

    // ---------------------------------------------------------------
    // EnvVarResourceDetector
    // ---------------------------------------------------------------
    group('EnvVarResourceDetector', () {
      test('detect() returns empty resource when env var is not set', () async {
        // In a typical test run, OTEL_RESOURCE_ATTRIBUTES is not set.
        final detector = EnvVarResourceDetector();
        final resource = await detector.detect();

        // When no env var is set, should return Resource.empty.
        expect(resource.attributes.isEmpty, isTrue);
      });

      test('detect() uses the default EnvironmentService singleton', () async {
        // Calling without an argument should not throw.
        final detector = EnvVarResourceDetector();
        final resource = await detector.detect();
        expect(resource, isNotNull);
      });

      test('detect() uses provided EnvironmentService instance', () async {
        // Pass the singleton explicitly to exercise the constructor parameter.
        final detector = EnvVarResourceDetector(EnvironmentService.instance);
        final resource = await detector.detect();
        // Should behave identically to the default.
        expect(resource, isNotNull);
      });
    });

    // ---------------------------------------------------------------
    // CompositeResourceDetector
    // ---------------------------------------------------------------
    group('CompositeResourceDetector', () {
      test('detect() with empty detector list returns empty resource',
          () async {
        final detector = CompositeResourceDetector([]);
        final resource = await detector.detect();

        expect(resource.attributes.isEmpty, isTrue);
      });

      test('detect() merges resources from multiple detectors', () async {
        final detector1 = _TestDetector({
          'key1': 'value1',
          'shared': 'from-first',
        });
        final detector2 = _TestDetector({
          'key2': 'value2',
          'shared': 'from-second',
        });

        final composite = CompositeResourceDetector([detector1, detector2]);
        final resource = await composite.detect();
        final attrs = resource.attributes.toMap();

        // Both detectors' unique keys should be present.
        expect(attrs['key1']?.value, equals('value1'));
        expect(attrs['key2']?.value, equals('value2'));

        // When keys overlap, the later detector's value takes precedence
        // (because Resource.merge gives precedence to the "other" resource).
        expect(attrs['shared']?.value, equals('from-second'));
      });

      test('detect() merges resources from three detectors', () async {
        final detector1 = _TestDetector({'a': 'alpha'});
        final detector2 = _TestDetector({'b': 'bravo'});
        final detector3 = _TestDetector({'c': 'charlie'});

        final composite =
            CompositeResourceDetector([detector1, detector2, detector3]);
        final resource = await composite.detect();
        final attrs = resource.attributes.toMap();

        expect(attrs['a']?.value, equals('alpha'));
        expect(attrs['b']?.value, equals('bravo'));
        expect(attrs['c']?.value, equals('charlie'));
      });

      test('detect() continues even if one detector throws', () async {
        final failing = _FailingDetector();
        final working = _TestDetector({
          'survived': 'yes',
          'answer': 42,
        });

        final composite = CompositeResourceDetector([failing, working]);
        final resource = await composite.detect();
        final attrs = resource.attributes.toMap();

        // The working detector's attributes should still be present.
        expect(attrs['survived']?.value, equals('yes'));
        expect(attrs['answer']?.value, equals(42));
      });

      test('detect() continues when failing detector is in the middle',
          () async {
        final first = _TestDetector({'first': 'one'});
        final failing = _FailingDetector();
        final last = _TestDetector({'last': 'three'});

        final composite = CompositeResourceDetector([first, failing, last]);
        final resource = await composite.detect();
        final attrs = resource.attributes.toMap();

        expect(attrs['first']?.value, equals('one'));
        expect(attrs['last']?.value, equals('three'));
      });

      test('detect() returns empty resource when all detectors fail', () async {
        final composite = CompositeResourceDetector([
          _FailingDetector(),
          _FailingDetector(),
        ]);
        final resource = await composite.detect();

        expect(resource.attributes.isEmpty, isTrue);
      });

      test('detect() with single detector returns that detector result',
          () async {
        final single = _TestDetector({'solo': 'value'});
        final composite = CompositeResourceDetector([single]);
        final resource = await composite.detect();

        expect(resource.attributes.toMap()['solo']?.value, equals('value'));
      });

      test('detect() combines real process and host detectors', () async {
        final composite = CompositeResourceDetector([
          ProcessResourceDetector(),
          HostResourceDetector(),
        ]);

        final resource = await composite.detect();
        final attrs = resource.attributes.toMap();

        // Process attributes present.
        expect(attrs['process.runtime.name']?.value, equals('dart'));
        expect(attrs['process.executable.name']?.value, isNotEmpty);

        // Host attributes present.
        expect(attrs['host.name']?.value, isNotEmpty);
        expect(attrs.containsKey('os.type'), isTrue);
      });
    });

    // ---------------------------------------------------------------
    // CompositeResourceDetector - OTel not initialized
    // ---------------------------------------------------------------
    group('CompositeResourceDetector without OTel initialized', () {
      test('detect() throws when OTel has not been initialized', () async {
        await OTel.shutdown();
        await OTel.reset();

        final composite = CompositeResourceDetector([]);
        expect(composite.detect, throwsA(isA<String>()));
      });

      test('ProcessResourceDetector detect() throws when OTel not initialized',
          () async {
        await OTel.shutdown();
        await OTel.reset();

        final detector = ProcessResourceDetector();
        expect(detector.detect, throwsA(isA<String>()));
      });

      test('HostResourceDetector detect() throws when OTel not initialized',
          () async {
        await OTel.shutdown();
        await OTel.reset();

        final detector = HostResourceDetector();
        expect(detector.detect, throwsA(isA<String>()));
      });

      test('EnvVarResourceDetector detect() throws when OTel not initialized',
          () async {
        await OTel.shutdown();
        await OTel.reset();

        final detector = EnvVarResourceDetector();
        // Even though env var is not set, the factory null check happens first.
        expect(detector.detect, throwsA(isA<String>()));
      });
    });

    // ---------------------------------------------------------------
    // PlatformResourceDetector
    // ---------------------------------------------------------------
    group('PlatformResourceDetector', () {
      test('create() returns a ResourceDetector', () {
        final detector = PlatformResourceDetector.create();
        expect(detector, isA<ResourceDetector>());
      });

      test('create() returns a CompositeResourceDetector', () {
        final detector = PlatformResourceDetector.create();
        expect(detector, isA<CompositeResourceDetector>());
      });

      test('create() result can detect resources', () async {
        final detector = PlatformResourceDetector.create();
        final resource = await detector.detect();

        expect(resource, isNotNull);
        final attrs = resource.attributes.toMap();

        // On native platforms, should have process and host info.
        expect(attrs['process.runtime.name']?.value, equals('dart'));
        expect(attrs['host.name']?.value, isNotEmpty);
      });

      test('create() result includes EnvVarResourceDetector output', () async {
        // The composite from PlatformResourceDetector always includes
        // EnvVarResourceDetector. When OTEL_RESOURCE_ATTRIBUTES is not set,
        // it contributes an empty resource, so the merged result should
        // still work (just no env-var-based attrs).
        final detector = PlatformResourceDetector.create();
        final resource = await detector.detect();
        expect(resource, isNotNull);
      });
    });

    // ---------------------------------------------------------------
    // ResourceDetector interface contract
    // ---------------------------------------------------------------
    group('ResourceDetector interface', () {
      test('custom detector implementing ResourceDetector works', () async {
        final custom = _TestDetector({'custom.key': 'custom.value'});
        final resource = await custom.detect();

        expect(resource.attributes.toMap()['custom.key']?.value,
            equals('custom.value'));
      });

      test('custom detector with multiple attribute types', () async {
        final custom = _TestDetector({
          'string.attr': 'hello',
          'int.attr': 42,
          'double.attr': 3.14,
          'bool.attr': true,
        });
        final resource = await custom.detect();
        final attrs = resource.attributes.toMap();

        expect(attrs['string.attr']?.value, equals('hello'));
        expect(attrs['int.attr']?.value, equals(42));
        expect(attrs['double.attr']?.value, equals(3.14));
        expect(attrs['bool.attr']?.value, equals(true));
      });

      test('failing detector throws as expected', () async {
        final failing = _FailingDetector();
        expect(failing.detect, throwsA(isA<Exception>()));
      });
    });
  });
}
