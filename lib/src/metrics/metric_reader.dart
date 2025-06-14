// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart' show OTelLog;

import 'data/metric_data.dart';
import 'meter_provider.dart';
import 'metric_exporter.dart';

/// MetricReader is responsible for collecting metrics from a MeterProvider
/// and passing them to a MetricExporter.
abstract class MetricReader {
  /// The MeterProvider this reader is associated with.
  MeterProvider? _meterProvider;

  /// Register a MeterProvider with this reader.
  ///
  /// This allows the reader to collect metrics from the provider.
  void registerMeterProvider(MeterProvider provider) {
    _meterProvider = provider;
  }

  /// Get the MeterProvider this reader is associated with.
  MeterProvider? get meterProvider => _meterProvider;

  /// Collect metrics from the MeterProvider.
  ///
  /// This method triggers the collection of metrics, and returns the
  /// collected data as an object containing resource and metric information.
  Future<MetricData> collect();

  /// Force flush metrics through the associated exporter.
  ///
  /// Returns true if the flush was successful, false otherwise.
  Future<bool> forceFlush();

  /// Shutdown the metric reader.
  ///
  /// This should clean up any resources and perform final exports.
  Future<bool> shutdown();
}

/// PeriodicExportingMetricReader is a MetricReader that periodically
/// collects metrics and exports them.
class PeriodicExportingMetricReader extends MetricReader {
  /// The exporter to send metrics to.
  final MetricExporter _exporter;

  /// How often to collect and export metrics.
  final Duration _interval;

  /// Maximum time to wait for export operations.
  final Duration _timeout;

  /// Timer for periodic collection.
  Timer? _timer;

  /// Creates a new PeriodicExportingMetricReader.
  ///
  /// [interval] How often to collect and export metrics (default: 60 seconds).
  /// [timeout] Maximum time to wait for export operations (default: 30 seconds).
  PeriodicExportingMetricReader(
    this._exporter, {
    Duration interval = const Duration(seconds: 60),
    Duration timeout = const Duration(seconds: 30),
  }) : _interval = interval,
       _timeout = timeout {
    // Start the timer
    _startTimer();
  }

  /// Start the periodic collection timer.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _collectAndExport());
  }

  /// Collect and export metrics.
  Future<void> _collectAndExport() async {
    if (meterProvider == null) return;

    try {
      // Collect metrics
      final data = await collect();

      // Export metrics
      if (data.metrics.isNotEmpty) {
        final exportFuture = _exporter.export(data);

        // Apply timeout to export
        await exportFuture.timeout(_timeout, onTimeout: () {
          print('Metric export timed out after $_timeout');
          return false;
        });
      }
    } catch (e) {
      print('Error during metric collection/export: $e');
    }
  }

  @override
  Future<MetricData> collect() async {
    if (meterProvider == null) {
      if (OTelLog.isLogMetrics()) {
        OTelLog.logMetric('PeriodicExportingMetricReader: No meter provider registered');
      }
      // Return an empty container with no metrics
      return MetricData.empty();
    }

    // Get the meter provider as an SDK MeterProvider to access the metric storage
    final sdkMeterProvider = meterProvider as MeterProvider;

    // Collect metrics from all instruments in the meter provider
    final metrics = await sdkMeterProvider.collectAllMetrics();

    if (OTelLog.isLogMetrics()) {
      OTelLog.logMetric('PeriodicExportingMetricReader: Collected ${metrics.length} metrics');
    }

    return MetricData(
      resource: meterProvider!.resource,
      metrics: metrics,
    );
  }

  @override
  Future<bool> forceFlush() async {
    try {
      // Collect and export immediately
      await _collectAndExport();
      return await _exporter.forceFlush();
    } catch (e) {
      print('Error during forceFlush: $e');
      return false;
    }
  }

  @override
  Future<bool> shutdown() async {
    _timer?.cancel();
    _timer = null;

    try {
      // Perform one final collection and export
      await _collectAndExport();
      return await _exporter.shutdown();
    } catch (e) {
      print('Error during shutdown: $e');
      return false;
    }
  }
}
