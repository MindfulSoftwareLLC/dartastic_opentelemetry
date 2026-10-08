// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:meta/meta.dart';

import 'instruments/base_instrument.dart';
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
  Meter._({required APIMeter delegate, required MeterProvider provider})
      : _delegate = delegate,
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
  bool isEnabled() => _provider.enabled;

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
  APICounter<T> createCounter<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
  }) {
    // First call the API implementation to get the API object
    final apiCounter = _delegate.createCounter<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
    );

    // Now wrap it with our SDK implementation
    return Counter<T>(apiCounter: apiCounter, meter: this);
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
  APIUpDownCounter<T> createUpDownCounter<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
  }) {
    // First call the API implementation to get the API object
    final apiCounter = _delegate.createUpDownCounter<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
    );

    // Now wrap it with our SDK implementation
    return UpDownCounter<T>(apiCounter: apiCounter, meter: this);
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
  /// @param boundaries Deprecated: use `advisory.explicitBucketBoundaries`.
  ///   When both are given, [boundaries] wins so existing callers keep
  ///   their buckets.
  /// @param advisory Optional advisory parameters; the SDK honors
  ///   `explicitBucketBoundaries` for the bucket layout
  /// @return A Histogram instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#histogram
  @override
  APIHistogram<T> createHistogram<T extends num>({
    required String name,
    String? unit,
    String? description,
    @Deprecated(
        'Use advisory: InstrumentAdvisory(explicitBucketBoundaries: ...) instead')
    List<double>? boundaries,
    InstrumentAdvisory? advisory,
  }) {
    // First call the API implementation to get the API object. It merges
    // boundaries into the advisory, so the SDK Histogram reads the
    // effective boundaries from apiHistogram.advisory.
    final apiHistogram = _delegate.createHistogram<T>(
      name: name,
      unit: unit,
      description: description,
      // ignore: deprecated_member_use
      boundaries: boundaries,
      advisory: advisory,
    );

    // Now wrap it with our SDK implementation
    return Histogram<T>(apiHistogram: apiHistogram, meter: this);
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
  APIGauge<T> createGauge<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
  }) {
    // First call the API implementation to get the API object
    final apiGauge = _delegate.createGauge<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
    );

    // Now wrap it with our SDK implementation
    return Gauge<T>(apiGauge: apiGauge, meter: this);
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
  /// @param advisory Optional advisory parameters for the instrument
  /// @param callbacks Callback functions invoked when measurements are collected
  /// @param callback Deprecated: use [callbacks]; a [callback] is prepended to it
  /// @return An ObservableCounter instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#asynchronous-counter
  @override
  APIObservableCounter<T> createObservableCounter<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
    List<ObservableCallback<T>> callbacks = const [],
    @Deprecated('Use callbacks instead') ObservableCallback<T>? callback,
  }) {
    // First call the API implementation to get the API object. It merges
    // the deprecated callback into callbacks.
    final apiCounter = _delegate.createObservableCounter<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
      callbacks: callbacks,
      // ignore: deprecated_member_use
      callback: callback,
    );

    // Now wrap it with our SDK implementation
    final counter = ObservableCounter<T>(apiCounter: apiCounter, meter: this);

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
  /// @param advisory Optional advisory parameters for the instrument
  /// @param callbacks Callback functions invoked when measurements are collected
  /// @param callback Deprecated: use [callbacks]; a [callback] is prepended to it
  /// @return An ObservableUpDownCounter instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#asynchronous-updowncounter
  @override
  APIObservableUpDownCounter<T> createObservableUpDownCounter<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
    List<ObservableCallback<T>> callbacks = const [],
    @Deprecated('Use callbacks instead') ObservableCallback<T>? callback,
  }) {
    // First call the API implementation to get the API object. It merges
    // the deprecated callback into callbacks.
    final apiCounter = _delegate.createObservableUpDownCounter<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
      callbacks: callbacks,
      // ignore: deprecated_member_use
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
  /// @param advisory Optional advisory parameters for the instrument
  /// @param callbacks Callback functions invoked when measurements are collected
  /// @param callback Deprecated: use [callbacks]; a [callback] is prepended to it
  /// @return An ObservableGauge instrument of the specified numeric type
  ///
  /// More information:
  /// https://opentelemetry.io/docs/specs/otel/metrics/api/#asynchronous-gauge
  @override
  APIObservableGauge<T> createObservableGauge<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
    List<ObservableCallback<T>> callbacks = const [],
    @Deprecated('Use callbacks instead') ObservableCallback<T>? callback,
  }) {
    // First call the API implementation to get the API object. It merges
    // the deprecated callback into callbacks.
    final apiGauge = _delegate.createObservableGauge<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
      callbacks: callbacks,
      // ignore: deprecated_member_use
      callback: callback,
    );

    // Now wrap it with our SDK implementation
    final gauge = ObservableGauge<T>(apiGauge: apiGauge, meter: this);

    // Register the instrument with the meter provider
    _provider.registerInstrument(name, gauge);

    return gauge;
  }

  /// Batch callbacks registered through [registerBatchCallback], run once
  /// per collection by [MeterProvider.collectAllMetrics].
  final List<_BatchCallbackRegistration> _batchCallbacks = [];

  /// Registers one callback that observes several of this meter's
  /// asynchronous instruments at once.
  ///
  /// Per metrics/api.md the instruments MUST all belong to this meter; an
  /// instrument from another meter, or one that is not an SDK asynchronous
  /// instrument, is reported through [OTelErrorHandling] and the callback is
  /// not registered. The returned registration's `unregister()` stops the
  /// callback from being invoked on later collections.
  @override
  APIBatchCallbackRegistration registerBatchCallback(
    BatchObservableCallback callback,
    Set<APIObservableInstrument> instruments,
  ) {
    for (final instrument in instruments) {
      if (!identical(instrument.meter, this) ||
          instrument is! SDKObservableInstrument) {
        OTelErrorHandling.report(ArgumentError(
          'registerBatchCallback: instrument "${instrument.name}" belongs '
          'to a different Meter; the callback was not registered.',
        ));
        return _NoopBatchCallbackRegistration();
      }
    }
    final registration = _BatchCallbackRegistration(
      meter: this,
      callback: callback,
      instruments: instruments.cast<SDKObservableInstrument>().toSet(),
    );
    _batchCallbacks.add(registration);
    return registration;
  }

  /// Invokes every registered batch callback once, queuing its observations
  /// on the instruments it covers for their next `collect()`.
  ///
  /// Called by [MeterProvider.collectAllMetrics] before the instruments
  /// collect. A callback that throws is reported and the rest still run.
  void runBatchCallbacks() {
    if (!isEnabled() || _batchCallbacks.isEmpty) return;
    for (final registration in List.of(_batchCallbacks)) {
      final result = _BatchObservableResult(registration.instruments);
      try {
        registration.callback(result);
      } catch (e, stackTrace) {
        OTelErrorHandling.report(e, stackTrace);
      }
    }
  }
}

/// A live registration for a batch callback on an SDK [Meter].
class _BatchCallbackRegistration implements APIBatchCallbackRegistration {
  final Meter meter;
  final BatchObservableCallback callback;
  final Set<SDKObservableInstrument> instruments;

  _BatchCallbackRegistration({
    required this.meter,
    required this.callback,
    required this.instruments,
  });

  @override
  void unregister() {
    meter._batchCallbacks.remove(this);
  }
}

/// Registration handed back when a batch callback was rejected or the meter
/// is a no-op; unregistering it does nothing.
class _NoopBatchCallbackRegistration implements APIBatchCallbackRegistration {
  @override
  void unregister() {}
}

/// The [BatchObservableResult] handed to a batch callback.
///
/// An observation for an instrument the callback was not registered with is
/// dropped and reported, per metrics/api.md ("the callback SHOULD only
/// report observations for the instruments it was registered with").
class _BatchObservableResult implements BatchObservableResult {
  final Set<SDKObservableInstrument> _instruments;

  _BatchObservableResult(this._instruments);

  @override
  void observe(APIObservableInstrument instrument, num value,
      [Attributes? attributes]) {
    if (instrument is! SDKObservableInstrument ||
        !_instruments.contains(instrument)) {
      OTelErrorHandling.report(ArgumentError(
        'Batch callback observed instrument "${instrument.name}", which it '
        'was not registered with; the observation was dropped.',
      ));
      return;
    }
    instrument.observeFromBatch(value, attributes);
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
  bool isEnabled() => false;

  /// Creates a new NoopMeter with the specified name and optional version and schema URL.
  ///
  /// @param name The name of the instrumentation scope
  /// @param version Optional version of the instrumentation scope
  /// @param schemaUrl Optional URL of the schema defining the instrumentation scope
  NoopMeter({required this.name, this.version, this.schemaUrl});

  @override
  APICounter<T> createCounter<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
  }) {
    return NoopCounter<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
    );
  }

  @override
  APIUpDownCounter<T> createUpDownCounter<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
  }) {
    return NoopUpDownCounter<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
    );
  }

  @override
  APIHistogram<T> createHistogram<T extends num>({
    required String name,
    String? unit,
    String? description,
    @Deprecated(
        'Use advisory: InstrumentAdvisory(explicitBucketBoundaries: ...) instead')
    List<double>? boundaries,
    InstrumentAdvisory? advisory,
  }) {
    return NoopHistogram<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: boundaries != null
          ? InstrumentAdvisory(
              explicitBucketBoundaries: boundaries,
              attributeKeys: advisory?.attributeKeys,
            )
          : advisory,
    );
  }

  @override
  APIGauge<T> createGauge<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
  }) {
    return NoopGauge<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
    );
  }

  @override
  APIObservableCounter<T> createObservableCounter<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
    List<ObservableCallback<T>> callbacks = const [],
    @Deprecated('Use callbacks instead') ObservableCallback<T>? callback,
  }) {
    return NoopObservableCounter<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
      callbacks: [if (callback != null) callback, ...callbacks],
    );
  }

  @override
  APIObservableUpDownCounter<T> createObservableUpDownCounter<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
    List<ObservableCallback<T>> callbacks = const [],
    @Deprecated('Use callbacks instead') ObservableCallback<T>? callback,
  }) {
    return NoopObservableUpDownCounter<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
      callbacks: [if (callback != null) callback, ...callbacks],
    );
  }

  @override
  APIObservableGauge<T> createObservableGauge<T extends num>({
    required String name,
    String? unit,
    String? description,
    InstrumentAdvisory? advisory,
    List<ObservableCallback<T>> callbacks = const [],
    @Deprecated('Use callbacks instead') ObservableCallback<T>? callback,
  }) {
    return NoopObservableGauge<T>(
      name: name,
      unit: unit,
      description: description,
      advisory: advisory,
      callbacks: [if (callback != null) callback, ...callbacks],
    );
  }

  @override
  APIBatchCallbackRegistration registerBatchCallback(
    BatchObservableCallback callback,
    Set<APIObservableInstrument> instruments,
  ) {
    return _NoopBatchCallbackRegistration();
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
  bool isEnabled() => false;

  @override
  final APIMeter meter;

  /// Creates a new NoopCounter with the specified name, unit, and description.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  @override
  final InstrumentAdvisory? advisory;

  NoopCounter({required this.name, this.unit, this.description, this.advisory})
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
  bool isEnabled() => false;

  @override
  final APIMeter meter;

  /// Creates a new NoopUpDownCounter with the specified name, unit, and description.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  @override
  final InstrumentAdvisory? advisory;

  NoopUpDownCounter(
      {required this.name, this.unit, this.description, this.advisory})
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
  final InstrumentAdvisory? advisory;

  @Deprecated('Use advisory?.explicitBucketBoundaries instead')
  @override
  List<double>? get boundaries => advisory?.explicitBucketBoundaries;

  @override
  bool isEnabled() => false;

  @override
  final APIMeter meter;

  /// Creates a new NoopHistogram with the specified name, unit, description, and advisory.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  /// @param advisory Optional advisory parameters, carrying any bucket boundaries
  NoopHistogram({
    required this.name,
    this.unit,
    this.description,
    this.advisory,
  }) : meter = NoopMeter(name: 'noop-meter');

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
  bool isEnabled() => false;

  @override
  final APIMeter meter;

  /// Creates a new NoopGauge with the specified name, unit, and description.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  @override
  final InstrumentAdvisory? advisory;

  NoopGauge({required this.name, this.unit, this.description, this.advisory})
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
  bool isEnabled() => false;

  @override
  final APIMeter meter;

  @override
  final InstrumentAdvisory? advisory;

  final List<ObservableCallback<T>> _callbacks = [];

  /// Creates a new NoopObservableCounter with the specified name, unit, description, and callbacks.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  /// @param advisory Optional advisory parameters
  /// @param callbacks Callback functions that will be called when measurements are collected
  NoopObservableCounter({
    required this.name,
    this.unit,
    this.description,
    this.advisory,
    List<ObservableCallback<T>> callbacks = const [],
  }) : meter = NoopMeter(name: 'noop-meter') {
    for (final callback in callbacks) {
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
  bool isEnabled() => false;

  @override
  final APIMeter meter;

  @override
  final InstrumentAdvisory? advisory;

  final List<ObservableCallback<T>> _callbacks = [];

  /// Creates a new NoopObservableUpDownCounter with the specified name, unit, description, and callbacks.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  /// @param advisory Optional advisory parameters
  /// @param callbacks Callback functions that will be called when measurements are collected
  NoopObservableUpDownCounter({
    required this.name,
    this.unit,
    this.description,
    this.advisory,
    List<ObservableCallback<T>> callbacks = const [],
  }) : meter = NoopMeter(name: 'noop-meter') {
    for (final callback in callbacks) {
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
  bool isEnabled() => false;

  @override
  final APIMeter meter;

  @override
  final InstrumentAdvisory? advisory;

  final List<ObservableCallback<T>> _callbacks = [];

  /// Creates a new NoopObservableGauge with the specified name, unit, description, and callbacks.
  ///
  /// @param name The name of the instrument
  /// @param unit Optional unit of measurement
  /// @param description Optional description of what the instrument measures
  /// @param advisory Optional advisory parameters
  /// @param callbacks Callback functions that will be called when measurements are collected
  NoopObservableGauge({
    required this.name,
    this.unit,
    this.description,
    this.advisory,
    List<ObservableCallback<T>> callbacks = const [],
  }) : meter = NoopMeter(name: 'noop-meter') {
    for (final callback in callbacks) {
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
