// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'meter_provider.dart';
import 'instruments/counter.dart';
import 'instruments/up_down_counter.dart';
import 'instruments/histogram.dart';
import 'instruments/gauge.dart';
import 'instruments/observable_counter.dart';
import 'instruments/observable_up_down_counter.dart';
import 'instruments/observable_gauge.dart';

/// Meter is the SDK implementation of APIMeter.
///
/// It is responsible for creating and managing instruments for recording metrics.
class Meter implements APIMeter {
  /// The underlying API Meter.
  final APIMeter _apiMeter;

  /// The MeterProvider that created this Meter.
  final MeterProvider _provider;

  /// Create a new Meter instance.
  Meter({
    required APIMeter apiMeter,
    required MeterProvider provider,
  }) : _apiMeter = apiMeter,
       _provider = provider;

  @override
  String get name => _apiMeter.name;

  @override
  String? get version => _apiMeter.version;

  @override
  String? get schemaUrl => _apiMeter.schemaUrl;

  @override
  Attributes? get attributes => _apiMeter.attributes;

  @override
  bool get enabled => _apiMeter.enabled && _provider.enabled;

  /// Gets the MeterProvider that created this Meter.
  MeterProvider get provider => _provider;

  @override
  APICounter<T> createCounter<T extends num>({required String name, String? unit, String? description}) {
    // First call the API implementation to get the API object
    final apiCounter = _apiMeter.createCounter<T>(name: name, unit: unit, description: description);

    // Now wrap it with our SDK implementation
    return Counter<T>(
      apiCounter: apiCounter,
      meter: this,
    );
  }

  @override
  APIUpDownCounter<T> createUpDownCounter<T extends num>({required String name, String? unit, String? description}) {
    // First call the API implementation to get the API object
    final apiCounter = _apiMeter.createUpDownCounter<T>(name: name, unit: unit, description: description);

    // Now wrap it with our SDK implementation
    return UpDownCounter<T>(
      apiCounter: apiCounter,
      meter: this,
    );
  }

  @override
  APIHistogram<T> createHistogram<T extends num>({required String name, String? unit, String? description, List<double>? boundaries}) {
    // First call the API implementation to get the API object
    final apiHistogram = _apiMeter.createHistogram<T>(
      name: name,
      unit: unit,
      description: description,
      boundaries: boundaries
    );

    // Now wrap it with our SDK implementation
    return Histogram<T>(
      apiHistogram: apiHistogram,
      meter: this,
      boundaries: boundaries,
    );
  }

  @override
  APIGauge<T> createGauge<T extends num>({required String name, String? unit, String? description}) {
    // First call the API implementation to get the API object
    final apiGauge = _apiMeter.createGauge<T>(name: name, unit: unit, description: description);

    // Now wrap it with our SDK implementation
    return Gauge<T>(
      apiGauge: apiGauge,
      meter: this,
    );
  }

  @override
  APIObservableCounter<T> createObservableCounter<T extends num>({required String name, String? unit, String? description, ObservableCallback? callback}) {
    // First call the API implementation to get the API object
    final apiCounter = _apiMeter.createObservableCounter<T>(
      name: name,
      unit: unit,
      description: description,
      callback: callback,
    );

    // Now wrap it with our SDK implementation
    return ObservableCounter<T>(
      apiCounter: apiCounter,
      meter: this,
    );
  }

  @override
  APIObservableUpDownCounter<T> createObservableUpDownCounter<T extends num>({required String name, String? unit, String? description, ObservableCallback? callback}) {
    // First call the API implementation to get the API object
    final apiCounter = _apiMeter.createObservableUpDownCounter<T>(
      name: name,
      unit: unit,
      description: description,
      callback: callback,
    );

    // Now wrap it with our SDK implementation
    return ObservableUpDownCounter<T>(
      apiCounter: apiCounter,
      meter: this,
    );
  }

  @override
  APIObservableGauge<T> createObservableGauge<T extends num>({required String name, String? unit, String? description, ObservableCallback? callback}) {
    // First call the API implementation to get the API object
    final apiGauge = _apiMeter.createObservableGauge<T>(
      name: name,
      unit: unit,
      description: description,
      callback: callback,
    );

    // Now wrap it with our SDK implementation
    return ObservableGauge<T>(
      apiGauge: apiGauge,
      meter: this,
    );
  }
}
