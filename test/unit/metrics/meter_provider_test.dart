// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// For runZonedGuarded

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';
import '../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('MeterProvider Tests', () {
    late MemoryMetricExporter memoryExporter;
    late MemoryMetricReader metricReader;

    setUp(() async {
      await OTel.reset();

      // Create a memory exporter for verification
      memoryExporter = MemoryMetricExporter();
      metricReader = MemoryMetricReader(exporter: memoryExporter);

      // Initialize OTel with our memory metric reader
      await OTel.initialize(
        serviceName: 'meter-provider-test-service',
        metricReader: metricReader,
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('MeterProvider exposes service information', () {
      // Get the meter provider
      final meterProvider = OTel.meterProvider();

      // Verify service information from initialization
      expect(meterProvider.serviceName, equals('meter-provider-test-service'));

      // Modify service information
      meterProvider.serviceName = 'updated-service-name';
      meterProvider.serviceVersion = '1.2.3';
      meterProvider.endpoint = 'https://updated.endpoint';

      // Verify updated values
      expect(meterProvider.serviceName, equals('updated-service-name'));
      expect(meterProvider.serviceVersion, equals('1.2.3'));
      expect(meterProvider.endpoint, equals('https://updated.endpoint'));
    });

    test('MeterProvider can be enabled and disabled', () {
      final meterProvider = OTel.meterProvider();

      // By default, enabled is true
      expect(meterProvider.enabled, isTrue);

      // Create a meter and verify it's also enabled
      final meter = meterProvider.getMeter(name: 'test-meter');
      expect(meter.isEnabled(), isTrue);

      // Disable meter provider
      meterProvider.enabled = false;

      // Verify both meter provider and meter are disabled
      expect(meterProvider.enabled, isFalse);
      expect(meter.isEnabled(), isFalse);

      // Re-enable
      meterProvider.enabled = true;
      expect(meterProvider.enabled, isTrue);
      expect(meter.isEnabled(), isTrue);
    });

    test('MeterProvider returns same meter for same configuration', () {
      final meterProvider = OTel.meterProvider();

      // Get meter with specific configuration
      final meter1 = meterProvider.getMeter(name: 'test-meter');

      // Get meter with same configuration
      final meter2 = meterProvider.getMeter(name: 'test-meter');

      // Get meter with different configuration
      final meter3 = meterProvider.getMeter(name: 'test-meter-different');

      // Verify same configuration returns same meter
      expect(identical(meter1, meter2), isTrue);

      // Verify different configuration returns different meter
      expect(identical(meter1, meter3), isFalse);
    });

    test('MeterProvider manages registered instruments', () {
      final meterProvider = OTel.meterProvider();

      // Create a meter and add an observable instrument
      final meter = meterProvider.getMeter(name: 'instrument-test-meter');
      final counter = meter.createObservableCounter<int>(
        name: 'test_counter',
        callbacks: [
          (result) {
            result.observe(42);
          },
        ],
      );

      // We can't directly access the internal _instruments map, but we can
      // verify the counter was properly registered by checking if metrics
      // are collected
      expect(counter, isNotNull);
    });

    group('meter identity and instrument namespaces', () {
      test(
          'meters differing only in version or schemaUrl own separate '
          'instruments', () {
        final meterProvider = OTel.meterProvider();
        final v1 =
            meterProvider.getMeter(name: 'shared', version: '1.0.0') as Meter;
        final v2 =
            meterProvider.getMeter(name: 'shared', version: '2.0.0') as Meter;
        final s1 = meterProvider.getMeter(
          name: 'shared',
          version: '1.0.0',
          schemaUrl: 'https://opentelemetry.io/schemas/1.0.0',
        ) as Meter;

        expect(identical(v1, v2), isFalse);
        expect(identical(v1, s1), isFalse);

        final c1 = v1.createCounter<int>(name: 'requests');
        final c2 = v2.createCounter<int>(name: 'requests');
        final c3 = s1.createCounter<int>(name: 'requests');

        expect(v1.instruments, equals({c1}));
        expect(v2.instruments, equals({c2}));
        expect(s1.instruments, equals({c3}));
      });

      test(
          'meters differing only in attributes are distinct, and attribute '
          'order does not matter', () {
        final meterProvider = OTel.meterProvider();
        final a = meterProvider.getMeter(
          name: 'scoped',
          attributes: OTel.attributesFromMap({'k1': 'v1', 'k2': 'v2'}),
        );
        final sameReordered = meterProvider.getMeter(
          name: 'scoped',
          attributes: OTel.attributesFromMap({'k2': 'v2', 'k1': 'v1'}),
        );
        final different = meterProvider.getMeter(
          name: 'scoped',
          attributes: OTel.attributesFromMap({'k1': 'other'}),
        );
        final none = meterProvider.getMeter(name: 'scoped');

        expect(identical(a, sameReordered), isTrue);
        expect(identical(a, different), isFalse);
        expect(identical(a, none), isFalse);
      });

      test('omitted and empty identity fields return the same meter', () {
        final meterProvider = OTel.meterProvider();
        final omitted = meterProvider.getMeter(name: 'defaults');
        final empty = meterProvider.getMeter(
          name: 'defaults',
          version: '',
          schemaUrl: '',
          attributes: OTel.attributesFromMap({}),
        );

        expect(identical(omitted, empty), isTrue);
      });

      test('a colon in the name cannot collide with the version', () {
        final meterProvider = OTel.meterProvider();
        final colonName = meterProvider.getMeter(name: 'a:b');
        final colonVersion = meterProvider.getMeter(name: 'a', version: 'b');

        expect(identical(colonName, colonVersion), isFalse);
      });

      test('collectAllMetrics collects instruments of every meter', () async {
        final meterProvider = OTel.meterProvider();
        meterProvider
            .getMeter(name: 'collect', version: '1')
            .createCounter<int>(name: 'c_v1')
            .add(1);
        meterProvider
            .getMeter(name: 'collect', version: '2')
            .createCounter<int>(name: 'c_v2')
            .add(2);

        final names =
            (await meterProvider.collectAllMetrics()).map((m) => m.name);

        expect(names, containsAll(<String>['c_v1', 'c_v2']));
      });

      test(
          'deprecated MeterProvider.registerInstrument registers with the '
          'meter', () {
        final meterProvider = OTel.meterProvider();
        final meter = meterProvider.getMeter(name: 'legacy') as Meter;
        final counter =
            meter.createCounter<int>(name: 'legacy_counter') as SDKInstrument;

        meterProvider.registerInstrument('ignored', counter);

        expect(meter.instruments, equals({counter}));
      });
    });

    test('MeterProvider.forceFlush fails after shutdown', () async {
      final meterProvider = OTel.meterProvider();

      // Force flush should succeed initially
      final result1 = await meterProvider.forceFlush();
      expect(result1, isTrue);

      // Shutdown
      await meterProvider.shutdown();
      expect(meterProvider.isShutdown, isTrue);

      // Force flush should fail after shutdown
      final result2 = await meterProvider.forceFlush();
      expect(result2, isFalse);
    });

    test('MeterProvider.shutdown sets isShutdown flag', () async {
      final meterProvider = OTel.meterProvider();

      // Add a view
      final view = View(
        instrumentNamePattern: 'test_metric*',
        name: 'test-view',
        description: 'Test view',
      );
      meterProvider.addView(view);
      expect(meterProvider.views.length, equals(1));

      // Add another reader
      final additionalExporter = MemoryMetricExporter();
      final additionalReader = MemoryMetricReader(exporter: additionalExporter);
      meterProvider.addMetricReader(additionalReader);
      expect(meterProvider.metricReaders.length, equals(2));

      // Shutdown
      await meterProvider.shutdown();

      // Verify provider is shutdown
      expect(meterProvider.isShutdown, isTrue);
    });
  });
}
