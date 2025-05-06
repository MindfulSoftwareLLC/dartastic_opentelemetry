// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// A memory-based metric exporter for testing purposes
/// This exporter stores metrics in memory instead of sending them to an endpoint
class MemoryMetricExporter implements MetricExporter {
  final List<Metric> _exportedMetrics = [];
  bool _isShutdown = false;

  // Constructor
  MemoryMetricExporter();

  // Get all exported metrics
  List<Metric> get exportedMetrics => List.unmodifiable(_exportedMetrics);

  // Clear all exported metrics
  void clear() {
    _exportedMetrics.clear();
  }

  String get name => 'MemoryMetricExporter';

  @override
  Future<bool> export(MetricData data) async {
    if (_isShutdown) {
      return false;
    }

    _exportedMetrics.addAll(data.metrics);
    return true;
  }

  @override
  Future<bool> forceFlush() async {
    return !_isShutdown;
  }

  @override
  Future<bool> shutdown() async {
    _isShutdown = true;
    return true;
  }
}

/// A memory-based metric reader for testing purposes
class MemoryMetricReader implements MetricReader {
  final MemoryMetricExporter _exporter;
  MeterProvider? _meterProvider;
  bool _isShutdown = false;

  // Constructor
  MemoryMetricReader({MemoryMetricExporter? exporter})
      : _exporter = exporter ?? MemoryMetricExporter();

  // Get the underlying exporter
  MemoryMetricExporter get exporter => _exporter;

  @override
  MeterProvider? get meterProvider => _meterProvider;

  @override
  Future<MetricData> collect() async {
    if (_isShutdown || _meterProvider == null) {
      return MetricData.empty();
    }

    // Collect metrics from all instruments in the meter provider
    final metrics = await _meterProvider!.collectAllMetrics();

    return MetricData(
      resource: _meterProvider!.resource,
      metrics: metrics,
    );
  }

  @override
  Future<bool> forceFlush() async {
    if (_isShutdown || _meterProvider == null) {
      return false;
    }

    try {
      // Collect metrics
      final data = await collect();

      // Export metrics regardless if empty or not for testing purposes
      return await _exporter.export(data);
    } catch (e) {
      print('Error during MemoryMetricReader forceFlush: $e');
      return false;
    }
  }

  @override
  void registerMeterProvider(MeterProvider meterProvider) {
    _meterProvider = meterProvider;
  }

  @override
  Future<bool> shutdown() async {
    _isShutdown = true;
    return await _exporter.shutdown();
  }
}
