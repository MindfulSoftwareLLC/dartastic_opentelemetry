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
  bool get enabled => _provider.enabled;

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
    final counter = ObservableCounter<T>(
      apiCounter: apiCounter,
      meter: this,
    );

    // Register the instrument with the meter provider
    _provider.registerInstrument(name, counter);

    return counter;
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
    final counter = ObservableUpDownCounter<T>(
      apiCounter: apiCounter,
      meter: this,
    );

    // Register the instrument with the meter provider
    _provider.registerInstrument(name, counter);

    return counter;
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
    final gauge = ObservableGauge<T>(
      apiGauge: apiGauge,
      meter: this,
    );

    // Register the instrument with the meter provider
    _provider.registerInstrument(name, gauge);

    return gauge;
  }
}

/// A no-op implementation of Meter that doesn't record any metrics.
/// Used when the MeterProvider has been shut down.
class NoopMeter implements APIMeter {
  @override
  final String name;
  
  @override
  final String? version;
  
  @override
  final String? schemaUrl;
  
  @override
  final Attributes? attributes = null;
  
  @override
  final bool enabled = false;
  
  NoopMeter({
    required this.name,
    this.version,
    this.schemaUrl,
  });
  
  @override
  APICounter<T> createCounter<T extends num>({required String name, String? unit, String? description}) {
    return NoopCounter<T>(name: name, unit: unit, description: description);
  }
  
  @override
  APIUpDownCounter<T> createUpDownCounter<T extends num>({required String name, String? unit, String? description}) {
    return NoopUpDownCounter<T>(name: name, unit: unit, description: description);
  }
  
  @override
  APIHistogram<T> createHistogram<T extends num>({required String name, String? unit, String? description, List<double>? boundaries}) {
    return NoopHistogram<T>(name: name, unit: unit, description: description, boundaries: boundaries);
  }
  
  @override
  APIGauge<T> createGauge<T extends num>({required String name, String? unit, String? description}) {
    return NoopGauge<T>(name: name, unit: unit, description: description);
  }
  
  @override
  APIObservableCounter<T> createObservableCounter<T extends num>({required String name, String? unit, String? description, ObservableCallback<T>? callback}) {
    return NoopObservableCounter<T>(name: name, unit: unit, description: description, callback: callback);
  }
  
  @override
  APIObservableUpDownCounter<T> createObservableUpDownCounter<T extends num>({required String name, String? unit, String? description, ObservableCallback<T>? callback}) {
    return NoopObservableUpDownCounter<T>(name: name, unit: unit, description: description, callback: callback);
  }
  
  @override
  APIObservableGauge<T> createObservableGauge<T extends num>({required String name, String? unit, String? description, ObservableCallback<T>? callback}) {
    return NoopObservableGauge<T>(name: name, unit: unit, description: description, callback: callback);
  }
}

/// No-op implementations of instrument classes

class NoopCounter<T extends num> implements APICounter<T> {
  @override
  final String name;
  
  @override
  final String? description;
  
  @override
  final String? unit;
  
  @override
  final bool enabled = false;
  
  @override
  final APIMeter meter;
  
  NoopCounter({required this.name, this.unit, this.description}) : 
    meter = NoopMeter(name: 'noop-meter');
  
  @override
  void add(T value, [Attributes? attributes]) {
    // No-op
  }
  
  @override
  void addWithMap(T value, Map<String, Object> attributeMap) {
    // No-op
  }
  
  @override
  bool get isCounter => true;
  
  @override
  bool get isGauge => false;
  
  @override
  bool get isHistogram => false;
  
  @override
  bool get isUpDownCounter => false;
}

class NoopUpDownCounter<T extends num> implements APIUpDownCounter<T> {
  @override
  final String name;
  
  @override
  final String? description;
  
  @override
  final String? unit;
  
  @override
  final bool enabled = false;
  
  @override
  final APIMeter meter;
  
  NoopUpDownCounter({required this.name, this.unit, this.description}) : 
    meter = NoopMeter(name: 'noop-meter');
  
  @override
  void add(T value, [Attributes? attributes]) {
    // No-op
  }
  
  @override
  void addWithMap(T value, Map<String, Object> attributeMap) {
    // No-op
  }
  
  @override
  bool get isCounter => false;
  
  @override
  bool get isGauge => false;
  
  @override
  bool get isHistogram => false;
  
  @override
  bool get isUpDownCounter => true;
}

class NoopHistogram<T extends num> implements APIHistogram<T> {
  @override
  final String name;
  
  @override
  final String? description;
  
  @override
  final String? unit;
  
  @override
  final List<double>? boundaries;
  
  @override
  final bool enabled = false;
  
  @override
  final APIMeter meter;
  
  NoopHistogram({required this.name, this.unit, this.description, this.boundaries}) : 
    meter = NoopMeter(name: 'noop-meter');
  
  @override
  void record(T value, [Attributes? attributes]) {
    // No-op
  }
  
  @override
  void recordWithMap(T value, Map<String, Object> attributeMap) {
    // No-op
  }
  
  @override
  bool get isCounter => false;
  
  @override
  bool get isGauge => false;
  
  @override
  bool get isHistogram => true;
  
  @override
  bool get isUpDownCounter => false;
}

class NoopGauge<T extends num> implements APIGauge<T> {
  @override
  final String name;
  
  @override
  final String? description;
  
  @override
  final String? unit;
  
  @override
  final bool enabled = false;
  
  @override
  final APIMeter meter;
  
  NoopGauge({required this.name, this.unit, this.description}) : 
    meter = NoopMeter(name: 'noop-meter');
  
  @override
  void set(T value, [Attributes? attributes]) {
    // No-op
  }
  
  @override
  void setWithMap(T value, Map<String, Object> attributeMap) {
    // No-op
  }
  
  @override
  void record(T value, [Attributes? attributes]) {
    // No-op
  }
  
  @override
  void recordWithMap(T value, Map<String, Object> attributeMap) {
    // No-op
  }
  
  @override
  bool get isCounter => false;
  
  @override
  bool get isGauge => true;
  
  @override
  bool get isHistogram => false;
  
  @override
  bool get isUpDownCounter => false;
}

class NoopObservableCounter<T extends num> implements APIObservableCounter<T> {
  @override
  final String name;
  
  @override
  final String? description;
  
  @override
  final String? unit;
  
  @override
  final bool enabled = false;
  
  @override
  final APIMeter meter;
  
  final List<ObservableCallback<T>> _callbacks = [];
  
  NoopObservableCounter({required this.name, this.unit, this.description, ObservableCallback<T>? callback}) : 
    meter = NoopMeter(name: 'noop-meter') {
    if (callback != null) {
      addCallback(callback);
    }
  }
  
  @override
  List<ObservableCallback<T>> get callbacks => List.unmodifiable(_callbacks);
  
  @override
  APICallbackRegistration<T> addCallback(ObservableCallback<T> callback) {
    _callbacks.add(callback);
    return _NoopCallbackRegistration<T>(this, callback);
  }
  
  @override
  void removeCallback(ObservableCallback<T> callback) {
    _callbacks.remove(callback);
  }
  
  @override
  List<Measurement> collect() {
    return <Measurement>[];
  }
}

class NoopObservableUpDownCounter<T extends num> implements APIObservableUpDownCounter<T> {
  @override
  final String name;
  
  @override
  final String? description;
  
  @override
  final String? unit;
  
  @override
  final bool enabled = false;
  
  @override
  final APIMeter meter;
  
  final List<ObservableCallback<T>> _callbacks = [];
  
  NoopObservableUpDownCounter({required this.name, this.unit, this.description, ObservableCallback<T>? callback}) : 
    meter = NoopMeter(name: 'noop-meter') {
    if (callback != null) {
      addCallback(callback);
    }
  }
  
  @override
  List<ObservableCallback<T>> get callbacks => List.unmodifiable(_callbacks);
  
  @override
  APICallbackRegistration<T> addCallback(ObservableCallback<T> callback) {
    _callbacks.add(callback);
    return _NoopCallbackRegistration<T>(this, callback);
  }
  
  @override
  void removeCallback(ObservableCallback<T> callback) {
    _callbacks.remove(callback);
  }
  
  @override
  List<Measurement> collect() {
    return <Measurement>[];
  }
}

class NoopObservableGauge<T extends num> implements APIObservableGauge<T> {
  @override
  final String name;
  
  @override
  final String? description;
  
  @override
  final String? unit;
  
  @override
  final bool enabled = false;
  
  @override
  final APIMeter meter;
  
  final List<ObservableCallback<T>> _callbacks = [];
  
  NoopObservableGauge({required this.name, this.unit, this.description, ObservableCallback<T>? callback}) : 
    meter = NoopMeter(name: 'noop-meter') {
    if (callback != null) {
      addCallback(callback);
    }
  }
  
  @override
  List<ObservableCallback<T>> get callbacks => List.unmodifiable(_callbacks);
  
  @override
  APICallbackRegistration<T> addCallback(ObservableCallback<T> callback) {
    _callbacks.add(callback);
    return _NoopCallbackRegistration<T>(this, callback);
  }
  
  @override
  void removeCallback(ObservableCallback<T> callback) {
    _callbacks.remove(callback);
  }
  
  @override
  List<Measurement> collect() {
    return <Measurement>[];
  }
}

/// Default callback registration for no-op observable instruments
class _NoopCallbackRegistration<T extends num> implements APICallbackRegistration<T> {
  final dynamic _instrument;
  final ObservableCallback<T> _callback;

  _NoopCallbackRegistration(this._instrument, this._callback);

  @override
  void unregister() {
    if (_instrument is APIObservableCounter<T>) {
      (_instrument as APIObservableCounter<T>).removeCallback(_callback);
    } else if (_instrument is APIObservableUpDownCounter<T>) {
      (_instrument as APIObservableUpDownCounter<T>).removeCallback(_callback);
    } else if (_instrument is APIObservableGauge<T>) {
      (_instrument as APIObservableGauge<T>).removeCallback(_callback);
    }
  }
}