// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'instruments/counter.dart';
import 'instruments/gauge.dart';
import 'instruments/histogram.dart';
import 'instruments/observable_counter.dart';
import 'instruments/observable_gauge.dart';
import 'instruments/observable_up_down_counter.dart';
import 'instruments/up_down_counter.dart';
import 'meter_provider.dart';

part 'meter_create.dart';

/// SDK implementation of the APIMeter interface.
///
/// A Meter is the entry point for creating instruments that collect measurements for a specific
/// instrumentation scope. Meters are obtained from a MeterProvider, and each Meter is associated
/// with a specific instrumentation library, version, and optional schema URL.
///
/// The Meter follows the OpenTelemetry metrics data model which consists of instruments that
/// record measurements, which are then aggregated into metrics. This implementation delegates
/// to the API implementation while adding SDK-specific behaviors.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/api/
/// https://opentelemetry.io/docs/specs/otel/metrics/sdk/
class Meter implements APIMeter {
  /// The underlying API Meter implementation.
  final APIMeter _delegate;

  /// The MeterProvider that created this Meter.
  final MeterProvider _provider;

  /// Private constructor for creating Meter instances.
  ///
  /// @param delegate The API Meter implementation to delegate to
  /// @param provider The MeterProvider that created this Meter
  Meter._({
    required APIMeter delegate,
    required MeterProvider provider,
  })  : _delegate = delegate,
        _provider = provider;

  /// Gets the name of the instrumentation scope.
  ///
  /// This name uniquely identifies the instrumentation library, such as
  /// the package, module, or class name.
  @override
  String get name => _delegate.name;

  /// Gets the version of the instrumentation scope.
  ///
  /// This represents the version of the instrumentation library.
  @override
  String? get version => _delegate.version;

  /// Gets the schema URL of the instrumentation scope.
  ///
  /// This URL identifies the schema that defines the instrumentation scope.
  @override
  String? get schemaUrl => _delegate.schemaUrl;

  /// Gets the attributes associated with this meter.
  ///
  /// These attributes provide additional context about the instrumentation scope.
  @override
  Attributes? get attributes => _delegate.attributes;

  /// Indicates whether this meter is enabled.
  ///
  /// If false, instruments created by this meter will not record measurements.
  /// This is controlled by the associated MeterProvider.
  @override
  bool get enabled => _provider.enabled;

  /// Gets the MeterProvider that created this Meter.
  ///
  /// @return The MeterProvider instance
  MeterProvider get provider => _provider;

  /// Creates a Counter instrument for recording cumulative, monotonically increasing values.
  ///
  /// Counters are used to measure a non-negative, monotonically increasing value. They only
  /// allow positive increments and are appropriate for values that never decrease, such as
  /// request counts, completed operations, or error counts.
  ///
  /// @param name The name of the instrument, which should be unique within the meter
  /// @param unit Optional unit of measurement (e.g., "ms", "bytes", "requests")
  /// @param description Optional description of what the instrument measures
  /// @return A Counter instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#counter
  @override
  APICounter<T> createCounter<T extends num>(
      {required String name, String? unit, String? description}) {
    // First call the API implementation to get the API object
    final apiCounter = _delegate.createCounter<T>(
        name: name, unit: unit, description: description);

    // Now wrap it with our SDK implementation
    return Counter<T>(
      apiCounter: apiCounter,
      meter: this,
    );
  }

  /// Creates an UpDownCounter instrument for recording cumulative values that can increase or decrease.
  ///
  /// UpDownCounters are used to measure values that can go up or down over time. They are appropriate
  /// for values that represent a current state, such as active requests, queue size, or resource usage.
  ///
  /// @param name The name of the instrument, which should be unique within the meter
  /// @param unit Optional unit of measurement (e.g., "ms", "bytes", "requests")
  /// @param description Optional description of what the instrument measures
  /// @return An UpDownCounter instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#updowncounter
  @override
  APIUpDownCounter<T> createUpDownCounter<T extends num>(
      {required String name, String? unit, String? description}) {
    // First call the API implementation to get the API object
    final apiCounter = _delegate.createUpDownCounter<T>(
        name: name, unit: unit, description: description);

    // Now wrap it with our SDK implementation
    return UpDownCounter<T>(
      apiCounter: apiCounter,
      meter: this,
    );
  }

  /// Creates a Histogram instrument for recording a distribution of values.
  ///
  /// Histograms are used to measure the distribution of values, such as request durations or
  /// response sizes. They provide statistics about the distribution, including count, sum,
  /// min, max, and quantiles.
  ///
  /// @param name The name of the instrument, which should be unique within the meter
  /// @param unit Optional unit of measurement (e.g., "ms", "bytes")
  /// @param description Optional description of what the instrument measures
  /// @param boundaries Optional explicit histogram bucket boundaries in increasing order
  /// @return A Histogram instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#histogram
  @override
  APIHistogram<T> createHistogram<T extends num>(
      {required String name,
      String? unit,
      String? description,
      List<double>? boundaries}) {
    // First call the API implementation to get the API object
    final apiHistogram = _delegate.createHistogram<T>(
        name: name,
        unit: unit,
        description: description,
        boundaries: boundaries);

    // Now wrap it with our SDK implementation
    return Histogram<T>(
      apiHistogram: apiHistogram,
      meter: this,
      boundaries: boundaries,
    );
  }

  /// Creates a Gauge instrument for recording the current value at the time of measurement.
  ///
  /// Gauges are used to measure the instantaneous value of something, such as the current
  /// CPU usage, memory usage, or temperature. They report the most recently observed value.
  ///
  /// @param name The name of the instrument, which should be unique within the meter
  /// @param unit Optional unit of measurement (e.g., "ms", "bytes", "percent")
  /// @param description Optional description of what the instrument measures
  /// @return A Gauge instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#gauge
  @override
  APIGauge<T> createGauge<T extends num>(
      {required String name, String? unit, String? description}) {
    // First call the API implementation to get the API object
    final apiGauge = _delegate.createGauge<T>(
        name: name, unit: unit, description: description);

    // Now wrap it with our SDK implementation
    return Gauge<T>(
      apiGauge: apiGauge,
      meter: this,
    );
  }

  /// Creates an ObservableCounter instrument for asynchronously recording cumulative, monotonically increasing values.
  ///
  /// ObservableCounters are used when measurements are expensive to compute and should be
  /// collected only when needed, or when they come from an external source. They are appropriate
  /// for the same use cases as Counters, but with asynchronous collection.
  ///
  /// @param name The name of the instrument, which should be unique within the meter
  /// @param unit Optional unit of measurement (e.g., "ms", "bytes", "requests")
  /// @param description Optional description of what the instrument measures
  /// @param callback Optional callback function that will be called when measurements are collected
  /// @return An ObservableCounter instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#asynchronous-counter
  @override
  APIObservableCounter<T> createObservableCounter<T extends num>(
      {required String name,
      String? unit,
      String? description,
      ObservableCallback<T>? callback}) {
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

  /// Creates an ObservableUpDownCounter instrument for asynchronously recording cumulative values that can increase or decrease.
  ///
  /// ObservableUpDownCounters are used when measurements are expensive to compute and should be
  /// collected only when needed, or when they come from an external source. They are appropriate
  /// for the same use cases as UpDownCounters, but with asynchronous collection.
  ///
  /// @param name The name of the instrument, which should be unique within the meter
  /// @param unit Optional unit of measurement (e.g., "ms", "bytes", "requests")
  /// @param description Optional description of what the instrument measures
  /// @param callback Optional callback function that will be called when measurements are collected
  /// @return An ObservableUpDownCounter instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#asynchronous-updowncounter
  @override
  APIObservableUpDownCounter<T> createObservableUpDownCounter<T extends num>(
      {required String name,
      String? unit,
      String? description,
      ObservableCallback<T>? callback}) {
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

  /// Creates an ObservableGauge instrument for asynchronously recording the current value at collection time.
  ///
  /// ObservableGauges are used when measurements are expensive to compute and should be
  /// collected only when needed, or when they come from an external source. They are appropriate
  /// for the same use cases as Gauges, but with asynchronous collection.
  ///
  /// @param name The name of the instrument, which should be unique within the meter
  /// @param unit Optional unit of measurement (e.g., "ms", "bytes", "percent")
  /// @param description Optional description of what the instrument measures
  /// @param callback Optional callback function that will be called when measurements are collected
  /// @return An ObservableGauge instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#asynchronous-gauge
  @override
  APIObservableGauge<T> createObservableGauge<T extends num>(
      {required String name,
      String? unit,
      String? description,
      ObservableCallback<T>? callback}) {
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
///
/// This implementation is used when the MeterProvider has been shut down
/// or if metrics collection is disabled. It provides the same interface as
/// a regular Meter but does nothing when measurements are recorded.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/api/#no-op-implementations
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

  /// Creates a new NoopMeter with the specified name and optional version and schema URL.
  ///
  /// @param name The name of the instrumentation scope
  /// @param version Optional version of the instrumentation scope
  /// @param schemaUrl Optional URL of the schema defining the instrumentation scope
  NoopMeter({
    required this.name,
    this.version,
    this.schemaUrl,
  });

  @override
  APICounter<T> createCounter<T extends num>(
      {required String name, String? unit, String? description}) {
    return NoopCounter<T>(name: name, unit: unit, description: description);
  }

  @override
  APIUpDownCounter<T> createUpDownCounter<T extends num>(
      {required String name, String? unit, String? description}) {
    return NoopUpDownCounter<T>(
        name: name, unit: unit, description: description);
  }

  @override
  APIHistogram<T> createHistogram<T extends num>(
      {required String name,
      String? unit,
      String? description,
      List<double>? boundaries}) {
    return NoopHistogram<T>(
        name: name,
        unit: unit,
        description: description,
        boundaries: boundaries);
  }

  @override
  APIGauge<T> createGauge<T extends num>(
      {required String name, String? unit, String? description}) {
    return NoopGauge<T>(name: name, unit: unit, description: description);
  }

  @override
  APIObservableCounter<T> createObservableCounter<T extends num>(
      {required String name,
      String? unit,
      String? description,
      ObservableCallback<T>? callback}) {
    return NoopObservableCounter<T>(
        name: name, unit: unit, description: description, callback: callback);
  }

  @override
  APIObservableUpDownCounter<T> createObservableUpDownCounter<T extends num>(
      {required String name,
      String? unit,
      String? description,
      ObservableCallback<T>? callback}) {
    return NoopObservableUpDownCounter<T>(
        name: name, unit: unit, description: description, callback: callback);
  }

  @override
  APIObservableGauge<T> createObservableGauge<T extends num>(
      {required String name,
      String? unit,
      String? description,
      ObservableCallback<T>? callback}) {
    return NoopObservableGauge<T>(
        name: name, unit: unit, description: description, callback: callback);
  }
}

/// No-op implementation of Counter instrument.
///
/// This implementation conforms to the OpenTelemetry specification for no-op implementations,
/// maintaining the same interface as a functional Counter but performing no operations.
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

  /// Creates a new NoopCounter with the specified name, unit, and description.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  NoopCounter({required this.name, this.unit, this.description})
      : meter = NoopMeter(name: 'noop-meter');

  /// Records a measurement (no-op implementation).
  ///
  /// @param value The measurement value (ignored)
  /// @param attributes Optional attributes to associate with the measurement (ignored)
  @override
  void add(T value, [Attributes? attributes]) {
    // No-op
  }

  /// Records a measurement with attributes as a map (no-op implementation).
  ///
  /// @param value The measurement value (ignored)
  /// @param attributeMap Map of attribute names to values (ignored)
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

/// No-op implementation of UpDownCounter instrument.
///
/// This implementation conforms to the OpenTelemetry specification for no-op implementations,
/// maintaining the same interface as a functional UpDownCounter but performing no operations.
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

  /// Creates a new NoopUpDownCounter with the specified name, unit, and description.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  NoopUpDownCounter({required this.name, this.unit, this.description})
      : meter = NoopMeter(name: 'noop-meter');

  /// Records a measurement (no-op implementation).
  ///
  /// @param value The measurement value (ignored)
  /// @param attributes Optional attributes to associate with the measurement (ignored)
  @override
  void add(T value, [Attributes? attributes]) {
    // No-op
  }

  /// Records a measurement with attributes as a map (no-op implementation).
  ///
  /// @param value The measurement value (ignored)
  /// @param attributeMap Map of attribute names to values (ignored)
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

/// No-op implementation of Histogram instrument.
///
/// This implementation conforms to the OpenTelemetry specification for no-op implementations,
/// maintaining the same interface as a functional Histogram but performing no operations.
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

  /// Creates a new NoopHistogram with the specified name, unit, description, and boundaries.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  /// @param boundaries Optional explicit histogram bucket boundaries
  NoopHistogram(
      {required this.name, this.unit, this.description, this.boundaries})
      : meter = NoopMeter(name: 'noop-meter');

  /// Records a measurement (no-op implementation).
  ///
  /// @param value The measurement value (ignored)
  /// @param attributes Optional attributes to associate with the measurement (ignored)
  @override
  void record(T value, [Attributes? attributes]) {
    // No-op
  }

  /// Records a measurement with attributes as a map (no-op implementation).
  ///
  /// @param value The measurement value (ignored)
  /// @param attributeMap Map of attribute names to values (ignored)
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

/// No-op implementation of Gauge instrument.
///
/// This implementation conforms to the OpenTelemetry specification for no-op implementations,
/// maintaining the same interface as a functional Gauge but performing no operations.
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

  /// Creates a new NoopGauge with the specified name, unit, and description.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  NoopGauge({required this.name, this.unit, this.description})
      : meter = NoopMeter(name: 'noop-meter');

  /// Records a measurement (no-op implementation).
  ///
  /// @param value The measurement value (ignored)
  /// @param attributes Optional attributes to associate with the measurement (ignored)
  @override
  void record(T value, [Attributes? attributes]) {
    // No-op
  }

  /// Records a measurement with attributes as a map (no-op implementation).
  ///
  /// @param value The measurement value (ignored)
  /// @param attributeMap Map of attribute names to values (ignored)
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

/// No-op implementation of ObservableCounter instrument.
///
/// This implementation conforms to the OpenTelemetry specification for no-op implementations,
/// maintaining the same interface as a functional ObservableCounter but performing no operations.
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

  /// Creates a new NoopObservableCounter with the specified name, unit, description, and callback.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  /// @param callback Optional callback function that will be called when measurements are collected
  NoopObservableCounter(
      {required this.name,
      this.unit,
      this.description,
      ObservableCallback<T>? callback})
      : meter = NoopMeter(name: 'noop-meter') {
    if (callback != null) {
      addCallback(callback);
    }
  }

  /// Gets all registered callbacks.
  ///
  /// @return An unmodifiable list of registered callbacks
  @override
  List<ObservableCallback<T>> get callbacks => List.unmodifiable(_callbacks);

  /// Registers a callback function for collecting measurements.
  ///
  /// @param callback The callback function to register
  /// @return A registration object that can be used to unregister the callback
  @override
  APICallbackRegistration<T> addCallback(ObservableCallback<T> callback) {
    _callbacks.add(callback);
    return _NoopCallbackRegistration<T>(this, callback);
  }

  /// Unregisters a previously registered callback function.
  ///
  /// @param callback The callback function to unregister
  @override
  void removeCallback(ObservableCallback<T> callback) {
    _callbacks.remove(callback);
  }

  /// Collects measurements from all registered callbacks (no-op implementation).
  ///
  /// @return An empty list of measurements
  @override
  List<Measurement> collect() {
    return <Measurement>[];
  }
}

/// No-op implementation of ObservableUpDownCounter instrument.
///
/// This implementation conforms to the OpenTelemetry specification for no-op implementations,
/// maintaining the same interface as a functional ObservableUpDownCounter but performing no operations.
class NoopObservableUpDownCounter<T extends num>
    implements APIObservableUpDownCounter<T> {
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

  /// Creates a new NoopObservableUpDownCounter with the specified name, unit, description, and callback.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  /// @param callback Optional callback function that will be called when measurements are collected
  NoopObservableUpDownCounter(
      {required this.name,
      this.unit,
      this.description,
      ObservableCallback<T>? callback})
      : meter = NoopMeter(name: 'noop-meter') {
    if (callback != null) {
      addCallback(callback);
    }
  }

  /// Gets all registered callbacks.
  ///
  /// @return An unmodifiable list of registered callbacks
  @override
  List<ObservableCallback<T>> get callbacks => List.unmodifiable(_callbacks);

  /// Registers a callback function for collecting measurements.
  ///
  /// @param callback The callback function to register
  /// @return A registration object that can be used to unregister the callback
  @override
  APICallbackRegistration<T> addCallback(ObservableCallback<T> callback) {
    _callbacks.add(callback);
    return _NoopCallbackRegistration<T>(this, callback);
  }

  /// Unregisters a previously registered callback function.
  ///
  /// @param callback The callback function to unregister
  @override
  void removeCallback(ObservableCallback<T> callback) {
    _callbacks.remove(callback);
  }

  /// Collects measurements from all registered callbacks (no-op implementation).
  ///
  /// @return An empty list of measurements
  @override
  List<Measurement> collect() {
    return <Measurement>[];
  }
}

/// No-op implementation of ObservableGauge instrument.
///
/// This implementation conforms to the OpenTelemetry specification for no-op implementations,
/// maintaining the same interface as a functional ObservableGauge but performing no operations.
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

  /// Creates a new NoopObservableGauge with the specified name, unit, description, and callback.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  /// @param callback Optional callback function that will be called when measurements are collected
  NoopObservableGauge(
      {required this.name,
      this.unit,
      this.description,
      ObservableCallback<T>? callback})
      : meter = NoopMeter(name: 'noop-meter') {
    if (callback != null) {
      addCallback(callback);
    }
  }

  /// Gets all registered callbacks.
  ///
  /// @return An unmodifiable list of registered callbacks
  @override
  List<ObservableCallback<T>> get callbacks => List.unmodifiable(_callbacks);

  /// Registers a callback function for collecting measurements.
  ///
  /// @param callback The callback function to register
  /// @return A registration object that can be used to unregister the callback
  @override
  APICallbackRegistration<T> addCallback(ObservableCallback<T> callback) {
    _callbacks.add(callback);
    return _NoopCallbackRegistration<T>(this, callback);
  }

  /// Unregisters a previously registered callback function.
  ///
  /// @param callback The callback function to unregister
  @override
  void removeCallback(ObservableCallback<T> callback) {
    _callbacks.remove(callback);
  }

  /// Collects measurements from all registered callbacks (no-op implementation).
  ///
  /// @return An empty list of measurements
  @override
  List<Measurement> collect() {
    return <Measurement>[];
  }
}

/// No-op implementation of callback registration for observable instruments.
///
/// This implementation allows unregistering callbacks from no-op instruments.
class _NoopCallbackRegistration<T extends num>
    implements APICallbackRegistration<T> {
  final dynamic _instrument;
  final ObservableCallback<T> _callback;

  /// Creates a new NoopCallbackRegistration.
  ///
  /// @param instrument The instrument that owns the callback
  /// @param callback The callback function to be unregistered
  _NoopCallbackRegistration(this._instrument, this._callback);

  /// Unregisters the callback from the instrument.
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
