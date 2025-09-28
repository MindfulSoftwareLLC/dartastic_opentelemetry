// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import '../../dartastic_opentelemetry.dart';

part 'meter_provider_create.dart';

/// SDK implementation of the APIMeterProvider interface.
///
/// The MeterProvider is the entry point to the metrics API. It is responsible
/// for creating and managing Meters, as well as configuring the metric pipeline
/// via MetricReaders and Views.
///
/// This implementation delegates some functionality to the API MeterProvider
/// implementation while adding SDK-specific behaviors.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/metrics/sdk/
class MeterProvider implements APIMeterProvider {
  /// The underlying API MeterProvider implementation.
  final APIMeterProvider delegate;

  /// The resource associated with this MeterProvider.
  Resource? resource;

  /// List of metric readers associated with this MeterProvider.
  final List<MetricReader> _metricReaders = [];

  /// List of views for configuring metric collection.
  final List<View> _views = [];

  /// Private constructor for creating MeterProvider instances.
  ///
  /// @param delegate The API MeterProvider implementation to delegate to
  /// @param resource Optional Resource describing the entity producing telemetry
  MeterProvider._({
    required this.delegate,
    this.resource,
  }) {
    if (OTelLog.isDebug()) {
      OTelLog.debug('MeterProvider: Created with resource: $resource');
    }
  }

  @override
  String get endpoint => delegate.endpoint;

  @override
  set endpoint(String value) => delegate.endpoint = value;

  @override
  String get serviceName => delegate.serviceName;

  @override
  set serviceName(String value) => delegate.serviceName = value;

  @override
  String? get serviceVersion => delegate.serviceVersion;

  @override
  set serviceVersion(String? value) => delegate.serviceVersion = value;

  @override
  bool get enabled {
    return _enabledOverride ?? true;
  }

  // Track explicit enablement settings
  bool? _enabledOverride;

  @override
  set enabled(bool value) {
    _enabledOverride = value;
    delegate.enabled = value;
  }

  @override
  bool get isShutdown => delegate.isShutdown;

  @override
  set isShutdown(bool value) => delegate.isShutdown = value;

  @override
  APIMeter getMeter(
      {required String name,
      String? version,
      String? schemaUrl,
      Attributes? attributes}) {
    // Check if provider is shutdown
    if (isShutdown) {
      // Return a no-op meter instead of throwing
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'MeterProvider: Attempting to get meter "$name" after shutdown. Returning a no-op meter.');
      }
      return NoopMeter(name: name, version: version, schemaUrl: schemaUrl);
    }

    // Create a unique key for this meter
    final meterKey = '$name:${version ?? ''}:${schemaUrl ?? ''}';

    // Return an existing meter if we already have one with this configuration
    if (_meters.containsKey(meterKey)) {
      return _meters[meterKey]!;
    }

    // Call the API implementation first
    final apiMeter = delegate.getMeter(
        name: name,
        version: version,
        schemaUrl: schemaUrl,
        attributes: attributes);

    // Wrap it with our SDK implementation
    final meter = MeterCreate.create(
      delegate: apiMeter,
      provider: this,
    );

    // Store the meter in the registry
    _meters[meterKey] = meter;

    // Initialize the instruments set for this meter
    _instruments[meterKey] = {};

    if (OTelLog.isLogMetrics()) {
      OTelLog.logMetric(
          'MeterProvider: Created meter "$name" (version: $version)');
    }

    return meter;
  }

  /// Adds a MetricReader to this MeterProvider.
  ///
  /// MetricReaders are responsible for collecting and exporting metrics.
  /// They can be configured to collect metrics at different intervals and
  /// export them to different backends.
  ///
  /// @param reader The MetricReader to add
  void addMetricReader(MetricReader reader) {
    if (!_metricReaders.contains(reader)) {
      _metricReaders.add(reader);
      reader.registerMeterProvider(this);
    }
  }

  /// Adds a View to this MeterProvider.
  ///
  /// Views allow for customizing how metrics are collected and aggregated.
  /// They can be used to filter, transform, and aggregate metrics before
  /// they are exported.
  ///
  /// @param view The View to add
  void addView(View view) {
    _views.add(view);
  }

  /// Gets all views configured for this MeterProvider.
  ///
  /// @return An unmodifiable list of all views
  List<View> get views => List.unmodifiable(_views);

  /// Gets all metric readers associated with this MeterProvider.
  ///
  /// @return An unmodifiable list of all metric readers
  List<MetricReader> get metricReaders => List.unmodifiable(_metricReaders);

  /// Registry of all meters created by this provider
  final Map<String, Meter> _meters = {};

  /// Registry of active instruments across all meters
  final Map<String, Set<SDKInstrument>> _instruments = {};

  /// Registers an instrument with this provider.
  ///
  /// This allows the provider to track all active instruments for metrics collection.
  ///
  /// @param instrumentName The name of the instrument
  /// @param instrument The instrument to register
  void registerInstrument(String instrumentName, SDKInstrument instrument) {
    final meterKey = instrument.meter.name;
    if (!_instruments.containsKey(meterKey)) {
      _instruments[meterKey] = {};
    }

    _instruments[meterKey]!.add(instrument);

    if (OTelLog.isLogMetrics()) {
      OTelLog.logMetric(
          'MeterProvider: Registered instrument "${instrument.name}" for meter "${instrument.meter.name}"');
    }
  }

  /// Collects all metrics from all instruments across all meters.
  ///
  /// This is called by metric readers to gather the current metrics.
  ///
  /// @return A list of all collected metrics
  Future<List<Metric>> collectAllMetrics() async {
    if (isShutdown) {
      return [];
    }

    final allMetrics = <Metric>[];

    // Collect from each meter's instruments
    for (final entry in _instruments.entries) {
      final meterName = entry.key;
      final instruments = entry.value;

      if (OTelLog.isLogMetrics()) {
        OTelLog.logMetric(
            'MeterProvider: Collecting metrics from ${instruments.length} instruments in meter "$meterName"');
      }

      // Collect metrics from each instrument
      for (final instrument in instruments) {
        try {
          final metrics = instrument.collectMetrics();
          if (metrics.isNotEmpty) {
            allMetrics.addAll(metrics);

            if (OTelLog.isLogMetrics()) {
              OTelLog.logMetric(
                  'MeterProvider: Collected ${metrics.length} metrics from instrument "${instrument.name}"');
            }
          }
        } catch (e) {
          if (OTelLog.isLogMetrics()) {
            OTelLog.logMetric(
                'MeterProvider: Error collecting metrics from instrument "${instrument.name}": $e');
          }
        }
      }
    }

    if (OTelLog.isLogMetrics()) {
      OTelLog.logMetric(
          'MeterProvider: Collected ${allMetrics.length} total metrics');
    }

    return allMetrics;
  }

  /// Force flushes metrics through all associated MetricReaders.
  ///
  /// This method forces an immediate collection and export of metrics
  /// through all registered metric readers.
  ///
  /// @return true if all flushes were successful, false otherwise
  @override
  Future<bool> forceFlush() async {
    if (isShutdown) {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport('MeterProvider: Cannot flush after shutdown');
      }
      return false;
    }

    if (OTelLog.isLogExport()) {
      OTelLog.logExport(
          'MeterProvider: Force flushing metrics through ${_metricReaders.length} readers');
    }

    bool success = true;
    for (final reader in _metricReaders) {
      final result = await reader.forceFlush();
      success = success && result;
    }
    return success;
  }

  /// Shuts down this MeterProvider and all associated resources.
  ///
  /// This method shuts down all metric readers and prevents the creation
  /// of new meters. Any subsequent calls to getMeter() will return a no-op
  /// meter.
  ///
  /// @return true if shutdown was successful, false otherwise
  @override
  Future<bool> shutdown() async {
    if (isShutdown) {
      return true; // Already shut down
    }

    // Mark as shut down immediately to prevent new interactions
    isShutdown = true;

    bool success = true;

    // Shutdown all metric readers
    for (final reader in _metricReaders) {
      final result = await reader.shutdown();
      success = success && result;
    }

    // Clear collections
    _metricReaders.clear();
    _views.clear();

    // Finally call the underlying API implementation
    await delegate.shutdown();

    return success;
  }
}
