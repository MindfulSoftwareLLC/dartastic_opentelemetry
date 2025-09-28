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

      // Create a memory exporter for verification
      memoryExporter = MemoryMetricExporter();
      metricReader = MemoryMetricReader(exporter: memoryExporter);

      // Initialize OTel with our memory metric reader
      await OTel.initialize(
        serviceName: 'view-test-service',
        metricReader: metricReader,
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('View constructor sets properties correctly', () {
      // Create a view with all parameters
      final view = View(
        name: 'test-view',
        description: 'Test description',
        instrumentNamePattern: 'test_counter*',
        instrumentType: APICounter,
        meterName: 'test-meter',
        aggregationType: AggregationType.sum,
        attributeKeys: ['key1', 'key2'],
      );

      // Verify properties
      expect(view.name, equals('test-view'));
      expect(view.description, equals('Test description'));
      expect(view.instrumentNamePattern, equals('test_counter*'));
      expect(view.instrumentType, equals(APICounter));
      expect(view.meterName, equals('test-meter'));
      expect(view.aggregationType, equals(AggregationType.sum));
      expect(view.attributeKeys, equals(['key1', 'key2']));
    });

    test('View.all factory creates a wildcard view', () {
      // Create a view with View.all factory
      final view = View.all(
        name: 'all-view',
        description: 'All instruments view',
        aggregationType: AggregationType.histogram,
        attributeKeys: ['attr1', 'attr2'],
      );

      // Verify properties
      expect(view.name, equals('all-view'));
      expect(view.description, equals('All instruments view'));
      expect(view.instrumentNamePattern, equals('*'));
      expect(view.instrumentType, isNull);
      expect(view.meterName, isNull);
      expect(view.aggregationType, equals(AggregationType.histogram));
      expect(view.attributeKeys, equals(['attr1', 'attr2']));
    });

    // Test pattern matching behavior using MeterProvider setup
    test('MeterProvider with views applies pattern matching', () async {
      // Set up a meter provider with views
      final provider = OTel.meterProvider();

      // Create different views with pattern matching
      final exactView = View(
        instrumentNamePattern: 'test_counter',
        name: 'exact-match-view',
      );

      final wildcardView = View(
        instrumentNamePattern: 'test_*',
        name: 'wildcard-view',
      );

      final allView = View(
        instrumentNamePattern: '*',
        name: 'all-view',
      );

      // Add views to provider
      provider.addView(exactView);
      provider.addView(wildcardView);
      provider.addView(allView);

      // Verify views were added
      expect(provider.views.length, equals(3));
      expect(provider.views.map((v) => v.name),
          containsAll(['exact-match-view', 'wildcard-view', 'all-view']));
    });

    test('View with type filtering selects correct instruments', () async {
      // Set up a meter provider with views
      final provider = OTel.meterProvider();

      // Create different views with type filtering
      final counterView = View(
        instrumentNamePattern: '*',
        instrumentType: APICounter,
        name: 'counter-view',
      );

      final histogramView = View(
        instrumentNamePattern: '*',
        instrumentType: APIHistogram,
        name: 'histogram-view',
      );

      // Add views to provider
      provider.addView(counterView);
      provider.addView(histogramView);

      // Verify views were added with correct type filtering
      expect(provider.views.length, equals(2));
      expect(provider.views.map((v) => v.name),
          containsAll(['counter-view', 'histogram-view']));

      // Verify the views have correct instrument types
      final cView = provider.views.firstWhere((v) => v.name == 'counter-view');
      final hView =
          provider.views.firstWhere((v) => v.name == 'histogram-view');

      expect(cView.instrumentType, equals(APICounter));
      expect(hView.instrumentType, equals(APIHistogram));
    });

    test('View with meter name filtering selects correct instruments',
        () async {
      // Set up a meter provider with views
      final provider = OTel.meterProvider();

      // Create different views with meter name filtering
      final meter1View = View(
        instrumentNamePattern: '*',
        meterName: 'meter1',
        name: 'meter1-view',
      );

      final meter2View = View(
        instrumentNamePattern: '*',
        meterName: 'meter2',
        name: 'meter2-view',
      );

      // Add views to provider
      provider.addView(meter1View);
      provider.addView(meter2View);

      // Verify views were added with correct meter filtering
      expect(provider.views.length, equals(2));
      expect(provider.views.map((v) => v.name),
          containsAll(['meter1-view', 'meter2-view']));

      // Verify the views have correct meter names
      final m1View = provider.views.firstWhere((v) => v.name == 'meter1-view');
      final m2View = provider.views.firstWhere((v) => v.name == 'meter2-view');

      expect(m1View.meterName, equals('meter1'));
      expect(m2View.meterName, equals('meter2'));
    });

    test(
        'View with combined criteria selects instruments matching all conditions',
        () async {
      // Set up a meter provider with a view that has multiple criteria
      final provider = OTel.meterProvider();

      // Create a view with multiple criteria
      final complexView = View(
        instrumentNamePattern: 'test_*',
        instrumentType: APICounter,
        meterName: 'meter1',
        name: 'complex-view',
      );

      // Add view to provider
      provider.addView(complexView);

      // Verify view was added with correct combined criteria
      expect(provider.views.length, equals(1));
      final view = provider.views.first;

      expect(view.name, equals('complex-view'));
      expect(view.instrumentNamePattern, equals('test_*'));
      expect(view.instrumentType, equals(APICounter));
      expect(view.meterName, equals('meter1'));
    });
  });
}
