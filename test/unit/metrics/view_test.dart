// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

import '../../testing_utils/memory_metric_exporter.dart';

void main() {
  group('View Tests', () {
    late MemoryMetricExporter memoryExporter;
    late MemoryMetricReader metricReader;

    setUp(() async {
      await OTel.reset();
      memoryExporter = MemoryMetricExporter();
      metricReader = MemoryMetricReader(exporter: memoryExporter);
      await OTel.initialize(
        serviceName: 'test',
        metricReader: metricReader,
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    // ---------------------------------------------------------------
    // 1. View constructor sets all properties
    // ---------------------------------------------------------------
    test('View constructor sets all properties', () {
      final view = View(
        name: 'test-view',
        description: 'Test description',
        instrumentNamePattern: 'test_counter*',
        instrumentType: APICounter,
        meterName: 'test-meter',
        aggregationType: AggregationType.sum,
        attributeKeys: ['key1', 'key2'],
      );

      expect(view.name, equals('test-view'));
      expect(view.description, equals('Test description'));
      expect(view.instrumentNamePattern, equals('test_counter*'));
      expect(view.instrumentType, equals(APICounter));
      expect(view.meterName, equals('test-meter'));
      expect(view.aggregationType, equals(AggregationType.sum));
      expect(view.attributeKeys, equals(['key1', 'key2']));
    });

    test('View constructor defaults aggregationType to defaultAggregation', () {
      final view = View(instrumentNamePattern: 'foo');

      expect(view.name, isNull);
      expect(view.description, isNull);
      expect(view.instrumentType, isNull);
      expect(view.meterName, isNull);
      expect(view.aggregationType, equals(AggregationType.defaultAggregation));
      expect(view.attributeKeys, isNull);
    });

    // ---------------------------------------------------------------
    // 2. View.all() creates wildcard pattern
    // ---------------------------------------------------------------
    test('View.all() creates a wildcard view matching all instruments', () {
      final view = View.all(
        name: 'all-view',
        description: 'All instruments view',
        aggregationType: AggregationType.histogram,
        attributeKeys: ['attr1', 'attr2'],
      );

      expect(view.name, equals('all-view'));
      expect(view.description, equals('All instruments view'));
      expect(view.instrumentNamePattern, equals('*'));
      expect(view.instrumentType, isNull);
      expect(view.meterName, isNull);
      expect(view.aggregationType, equals(AggregationType.histogram));
      expect(view.attributeKeys, equals(['attr1', 'attr2']));
    });

    test('View.all() with no arguments uses defaults', () {
      final view = View.all();

      expect(view.name, isNull);
      expect(view.description, isNull);
      expect(view.instrumentNamePattern, equals('*'));
      expect(view.instrumentType, isNull);
      expect(view.meterName, isNull);
      expect(view.aggregationType, equals(AggregationType.defaultAggregation));
      expect(view.attributeKeys, isNull);
    });

    // ---------------------------------------------------------------
    // Helper to create all instrument kinds from a single meter
    // ---------------------------------------------------------------
    group('matches() -', () {
      late APIMeter meter;
      late APICounter<int> counter;
      late APIUpDownCounter<int> upDownCounter;
      late APIHistogram<double> histogram;
      late APIGauge<double> gauge;
      late APIObservableCounter<int> obsCounter;
      late APIObservableUpDownCounter<int> obsUpDown;
      late APIObservableGauge<double> obsGauge;

      setUp(() {
        meter = OTel.meterProvider().getMeter(name: 'test-meter');
        counter = meter.createCounter<int>(name: 'my_counter');
        upDownCounter = meter.createUpDownCounter<int>(name: 'my_updown');
        histogram = meter.createHistogram<double>(name: 'my_histogram');
        gauge = meter.createGauge<double>(name: 'my_gauge');
        obsCounter = meter.createObservableCounter<int>(
          name: 'my_obs_counter',
          callback: (_) {},
        );
        obsUpDown = meter.createObservableUpDownCounter<int>(
          name: 'my_obs_updown',
          callback: (_) {},
        );
        obsGauge = meter.createObservableGauge<double>(
          name: 'my_obs_gauge',
          callback: (_) {},
        );
      });

      // -----------------------------------------------------------
      // 3. Exact name matching
      // -----------------------------------------------------------
      test('matches with exact name returns true', () {
        final view = View(instrumentNamePattern: 'my_counter');
        expect(view.matches('my_counter', counter), isTrue);
      });

      test('matches with exact name that does not match returns false', () {
        final view = View(instrumentNamePattern: 'my_counter');
        expect(view.matches('other_counter', counter), isFalse);
      });

      // -----------------------------------------------------------
      // 4. Wildcard '*' matches everything
      // -----------------------------------------------------------
      test('matches with wildcard * matches any name', () {
        final view = View(instrumentNamePattern: '*');
        expect(view.matches('my_counter', counter), isTrue);
        expect(view.matches('my_histogram', histogram), isTrue);
        expect(view.matches('anything', gauge), isTrue);
        expect(view.matches('', counter), isTrue);
      });

      // -----------------------------------------------------------
      // 5. Prefix wildcard 'my_*'
      // -----------------------------------------------------------
      test('matches with prefix wildcard my_*', () {
        final view = View(instrumentNamePattern: 'my_*');
        expect(view.matches('my_counter', counter), isTrue);
        expect(view.matches('my_histogram', histogram), isTrue);
        expect(view.matches('your_counter', counter), isFalse);
      });

      // -----------------------------------------------------------
      // 6. Suffix wildcard '*_counter'
      // -----------------------------------------------------------
      test('matches with suffix wildcard *_counter', () {
        final view = View(instrumentNamePattern: '*_counter');
        expect(view.matches('my_counter', counter), isTrue);
        expect(view.matches('your_counter', counter), isTrue);
        expect(view.matches('my_histogram', histogram), isFalse);
      });

      // -----------------------------------------------------------
      // 7. Middle wildcard 'my_*_counter'
      // -----------------------------------------------------------
      test('matches with middle wildcard my_*_counter', () {
        final view = View(instrumentNamePattern: 'my_*_counter');
        expect(view.matches('my_obs_counter', obsCounter), isTrue);
        expect(view.matches('my_special_counter', counter), isTrue);
        expect(view.matches('my_histogram', histogram), isFalse);
        expect(view.matches('your_obs_counter', obsCounter), isFalse);
      });

      // -----------------------------------------------------------
      // 8. instrumentType = APICounter only matches counters
      // -----------------------------------------------------------
      test('matches with instrumentType APICounter only matches counters', () {
        final view = View(
          instrumentNamePattern: '*',
          instrumentType: APICounter,
        );
        expect(view.matches('my_counter', counter), isTrue);
        expect(view.matches('my_updown', upDownCounter), isFalse);
        expect(view.matches('my_histogram', histogram), isFalse);
        expect(view.matches('my_gauge', gauge), isFalse);
        expect(view.matches('my_obs_counter', obsCounter), isFalse);
        expect(view.matches('my_obs_updown', obsUpDown), isFalse);
        expect(view.matches('my_obs_gauge', obsGauge), isFalse);
      });

      // -----------------------------------------------------------
      // 9. instrumentType = APIUpDownCounter
      // -----------------------------------------------------------
      test(
        'matches with instrumentType APIUpDownCounter only matches up-down counters',
        () {
          final view = View(
            instrumentNamePattern: '*',
            instrumentType: APIUpDownCounter,
          );
          expect(view.matches('my_updown', upDownCounter), isTrue);
          expect(view.matches('my_counter', counter), isFalse);
          expect(view.matches('my_histogram', histogram), isFalse);
          expect(view.matches('my_gauge', gauge), isFalse);
        },
      );

      // -----------------------------------------------------------
      // 10. instrumentType = APIHistogram
      // -----------------------------------------------------------
      test(
        'matches with instrumentType APIHistogram only matches histograms',
        () {
          final view = View(
            instrumentNamePattern: '*',
            instrumentType: APIHistogram,
          );
          expect(view.matches('my_histogram', histogram), isTrue);
          expect(view.matches('my_counter', counter), isFalse);
          expect(view.matches('my_updown', upDownCounter), isFalse);
          expect(view.matches('my_gauge', gauge), isFalse);
        },
      );

      // -----------------------------------------------------------
      // 11. instrumentType = APIGauge
      // -----------------------------------------------------------
      test('matches with instrumentType APIGauge only matches gauges', () {
        final view = View(instrumentNamePattern: '*', instrumentType: APIGauge);
        expect(view.matches('my_gauge', gauge), isTrue);
        expect(view.matches('my_counter', counter), isFalse);
        expect(view.matches('my_updown', upDownCounter), isFalse);
        expect(view.matches('my_histogram', histogram), isFalse);
      });

      // -----------------------------------------------------------
      // 12. instrumentType = APIObservableCounter
      // -----------------------------------------------------------
      test(
        'matches with instrumentType APIObservableCounter only matches observable counters',
        () {
          final view = View(
            instrumentNamePattern: '*',
            instrumentType: APIObservableCounter,
          );
          expect(view.matches('my_obs_counter', obsCounter), isTrue);
          expect(view.matches('my_counter', counter), isFalse);
          expect(view.matches('my_obs_updown', obsUpDown), isFalse);
          expect(view.matches('my_obs_gauge', obsGauge), isFalse);
        },
      );

      // -----------------------------------------------------------
      // 13. instrumentType = APIObservableUpDownCounter
      // -----------------------------------------------------------
      test(
        'matches with instrumentType APIObservableUpDownCounter matches observable up-down counters',
        () {
          final view = View(
            instrumentNamePattern: '*',
            instrumentType: APIObservableUpDownCounter,
          );
          expect(view.matches('my_obs_updown', obsUpDown), isTrue);
          expect(view.matches('my_obs_counter', obsCounter), isFalse);
          expect(view.matches('my_obs_gauge', obsGauge), isFalse);
          expect(view.matches('my_counter', counter), isFalse);
        },
      );

      // -----------------------------------------------------------
      // 14. instrumentType = APIObservableGauge
      // -----------------------------------------------------------
      test(
        'matches with instrumentType APIObservableGauge matches observable gauges',
        () {
          final view = View(
            instrumentNamePattern: '*',
            instrumentType: APIObservableGauge,
          );
          expect(view.matches('my_obs_gauge', obsGauge), isTrue);
          expect(view.matches('my_obs_counter', obsCounter), isFalse);
          expect(view.matches('my_obs_updown', obsUpDown), isFalse);
          expect(view.matches('my_gauge', gauge), isFalse);
        },
      );

      // -----------------------------------------------------------
      // 15. meterName filters by meter
      // -----------------------------------------------------------
      test('matches with correct meterName returns true', () {
        final view = View(instrumentNamePattern: '*', meterName: 'test-meter');
        expect(view.matches('my_counter', counter), isTrue);
        expect(view.matches('my_histogram', histogram), isTrue);
      });

      // -----------------------------------------------------------
      // 16. Wrong meterName does not match
      // -----------------------------------------------------------
      test('matches with wrong meterName returns false', () {
        final view = View(instrumentNamePattern: '*', meterName: 'other-meter');
        expect(view.matches('my_counter', counter), isFalse);
        expect(view.matches('my_histogram', histogram), isFalse);
      });

      // -----------------------------------------------------------
      // 17. Combined instrumentType + meterName filter
      // -----------------------------------------------------------
      test('matches with combined instrumentType and meterName filter', () {
        final view = View(
          instrumentNamePattern: 'my_*',
          instrumentType: APICounter,
          meterName: 'test-meter',
        );
        // Counter with correct name pattern and meter => match
        expect(view.matches('my_counter', counter), isTrue);
        // Histogram with correct pattern and meter => wrong type
        expect(view.matches('my_histogram', histogram), isFalse);
        // Counter with wrong name pattern => no match
        expect(view.matches('other_counter', counter), isFalse);
      });

      test(
        'matches with combined filter rejects when meterName does not match',
        () {
          final view = View(
            instrumentNamePattern: '*',
            instrumentType: APICounter,
            meterName: 'wrong-meter',
          );
          expect(view.matches('my_counter', counter), isFalse);
        },
      );
    });

    // ---------------------------------------------------------------
    // AggregationType enum values
    // ---------------------------------------------------------------
    group('AggregationType', () {
      test('has all expected values', () {
        expect(
          AggregationType.values,
          containsAll([
            AggregationType.sum,
            AggregationType.lastValue,
            AggregationType.histogram,
            AggregationType.drop,
            AggregationType.defaultAggregation,
          ]),
        );
        expect(AggregationType.values.length, equals(5));
      });
    });
  });
}
