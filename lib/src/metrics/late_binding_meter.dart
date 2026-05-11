// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Late-binding proxy for [MeterProvider] only.
///
/// See `lib/src/trace/late_binding_tracer.dart` for the full design
/// rationale. Provider-level late binding is enough for module-load
/// `OTel.meterProvider()` capture; `OTel.meter()` itself does *not*
/// proxy — it resolves to the current real [Meter] at call time.
///
/// ## Why no [Meter] proxy
///
/// Concrete instruments (counters, histograms, gauges, observable
/// variants) hold a back-reference to their [Meter] via
/// `instrument.meter`. Library code and tests commonly compare
/// `instrument.meter == meter`, which only holds if `meter` is the
/// same object the underlying SDK passed into the instrument. A
/// proxy meter would fail those identity checks, so the cost of
/// breaking that contract outweighs the niche "I captured `OTel.meter()`
/// at module load" use case. If a real consumer needs late-binding
/// for meters, we can revisit by minting per-instrument proxies, but
/// for now the meter-level resolution-at-call-time matches
/// expectations.
library;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../otel.dart';
import '../resource/resource.dart';
import 'data/metric.dart';
import 'instruments/base_instrument.dart';
import 'meter_provider.dart';
import 'metric_reader.dart';
import 'view.dart';

/// A [MeterProvider] proxy that re-resolves its underlying SDK
/// MeterProvider on every call.
///
/// Identity is stable across `OTel.initialize`; cleared only on
/// `OTel.reset`. Constructed and cached by [OTel].
class LateBindingMeterProvider implements MeterProvider {
  /// Internal: do not construct directly. Use `OTel.meterProvider()`.
  LateBindingMeterProvider();

  MeterProvider _real() => OTel.internalResolveRealMeterProvider();

  @override
  APIMeter getMeter({
    required String name,
    String? version,
    String? schemaUrl,
    Attributes? attributes,
  }) =>
      _real().getMeter(
        name: name,
        version: version,
        schemaUrl: schemaUrl,
        attributes: attributes,
      );

  @override
  APIMeterProvider get delegate => _real().delegate;

  @override
  Resource? get resource => _real().resource;
  @override
  set resource(Resource? value) => _real().resource = value;

  @override
  String get endpoint => _real().endpoint;
  @override
  set endpoint(String value) => _real().endpoint = value;

  @override
  String get serviceName => _real().serviceName;
  @override
  set serviceName(String value) => _real().serviceName = value;

  @override
  String? get serviceVersion => _real().serviceVersion;
  @override
  set serviceVersion(String? value) => _real().serviceVersion = value;

  @override
  bool get enabled => _real().enabled;
  @override
  set enabled(bool value) => _real().enabled = value;

  @override
  bool get isShutdown => _real().isShutdown;
  @override
  set isShutdown(bool value) => _real().isShutdown = value;

  @override
  Future<bool> shutdown() => _real().shutdown();

  @override
  Future<bool> forceFlush() => _real().forceFlush();

  @override
  void addMetricReader(MetricReader reader) => _real().addMetricReader(reader);

  @override
  void addView(View view) => _real().addView(view);

  @override
  List<View> get views => _real().views;

  @override
  List<MetricReader> get metricReaders => _real().metricReaders;

  @override
  void registerInstrument(String instrumentName, SDKInstrument instrument) =>
      _real().registerInstrument(instrumentName, instrument);

  @override
  Future<List<Metric>> collectAllMetrics() => _real().collectAllMetrics();
}

