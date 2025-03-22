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

part 'meter_create.dart';

/// Meter is the SDK implementation of APIMeter.
///
/// It is responsible for creating and managing instruments for recording metrics.
class Meter implements APIMeter {
  /// The underlying API Meter.
  final APIMeter _delegate;

  /// The MeterProvider that created this Meter.
  final MeterProvider _provider;

  /// Create a new Meter instance.
  Meter._({
    required APIMeter delegate,
    required MeterProvider provider,
  }) : _delegate = delegate,
       _provider = provider;

  @override
  String get name => _delegate.name;

  @override
  String? get version => _delegate.version;

  @override
  String? get schemaUrl => _delegate.schemaUrl;

  @override
  Attributes? get attributes => _delegate.attributes;

  @override
  bool get enabled => _delegate.enabled && _provider.enabled;

  /// Gets the MeterProvider that created this Meter.
  MeterProvider get provider => _provider;

  @override
  APICounter<T> createCounter<T extends num>({required String name, String? unit, String? description}) {
    // First call the API implementation to get the API object
    final apiCounter = _delegate.createCounter<T>(name: name, unit: unit, description: description);

    // Now wrap it with our SDK implementation
    return Counter<T>(
      apiCounter: apiCounter,
      meter: this,
    );
  }

  @override
  APIUpDownCounter<T> createUpDownCounter<T extends num>({required String name, String? unit, String? description}) {
    // First call the API implementation to get the API object
    final apiCounter = _delegate.createUpDownCounter<T>(name: name, unit: unit, description: description);

    // Now wrap it with our SDK implementation
    return UpDownCounter<T>(
      apiCounter: apiCounter,
      meter: this,
    );
  }

  @override
  APIHistogram<T> createHistogram<T extends num>({required String name, String? unit, String? description, List<double>? boundaries}) {
    // First call the API implementation to get the API object
    final apiHistogram = _delegate.createHistogram<T>(
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
    final apiGauge = _delegate.createGauge<T>(name: name, unit: unit, description: description);

    // Now wrap it with our SDK implementation
    return Gauge<T>(
      apiGauge: apiGauge,
      meter: this,
    );
  }

  @override
  APIObservableCounter<T> createObservableCounter<T extends num>({required String name, String? unit, String? description, ObservableCallback<T>? callback}) {
    // First call the API implementation to get the API object
    final apiCounter = _delegate.createObservableCounter<T>(
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
  APIObservableUpDownCounter<T> createObservableUpDownCounter<T extends num>({required String name, String? unit, String? description, ObservableCallback<T>? callback}) {
    // First call the API implementation to get the API object
    final apiCounter = _delegate.createObservableUpDownCounter<T>(
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
  APIObservableGauge<T> createObservableGauge<T extends num>({required String name, String? unit, String? description, ObservableCallback<T>? callback}) {
    // First call the API implementation to get the API object
    final apiGauge = _delegate.createObservableGauge<T>(
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
