// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

import '../../data/metric_data.dart';
import '../../meter_provider.dart';
import '../../metric_reader.dart';
import 'prometheus_exporter.dart';
import 'prometheus_server_stub.dart'
    if (dart.library.io) 'prometheus_server_io.dart';

part 'prometheus_metric_reader_create.dart';

/// Collects cumulative metrics on each HTTP GET /metrics, without a timer.
///
/// Create with `OTel.prometheusMetricReader()` and register with a provider,
/// or select `OTEL_METRICS_EXPORTER=prometheus` during initialization.
class PrometheusMetricReader extends MetricReader {
  /// Whether the current platform can run a Prometheus scrape server.
  static const isSupported = PrometheusServer.supported;

  /// Host configured for the HTTP listener.
  final String host;

  /// Requested port. Zero asks the operating system for an ephemeral port.
  final int port;
  final _server = PrometheusServer();
  final _exporter = PrometheusExporter();
  final _lock = Lock();
  Future<bool>? _ready;
  Future<bool>? _closing;
  bool _shutdown = false;

  PrometheusMetricReader._({required this.host, required this.port}) {
    if (host.trim().isEmpty) throw ArgumentError.value(host, 'host');
    RangeError.checkValueInInterval(port, 0, 65535, 'port');
  }

  /// Resolves after binding, or false if unsupported, unregistered or failed.
  /// Binding failures are logged without disrupting application startup.
  Future<bool> get ready => _ready ?? Future.value(false);

  /// Actual listening port, or null before startup and after shutdown.
  int? get boundPort => _server.port;

  @override
  void registerMeterProvider(MeterProvider provider) {
    if (_shutdown) throw StateError('Prometheus reader has shut down.');
    if (meterProvider != null && !identical(meterProvider, provider)) {
      throw StateError('Prometheus reader is already registered.');
    }
    super.registerMeterProvider(provider);
    _ready ??= _start();
  }

  Future<bool> _start() async {
    try {
      await _server.start(host, port, _scrape);
      return true;
    } catch (error) {
      if (OTelLog.isError()) {
        OTelLog.error('Prometheus listener failed on $host:$port: $error');
      }
      return false;
    }
  }

  Future<String> _scrape() => _lock.synchronized(() async {
        if (_shutdown) throw StateError('Prometheus reader has shut down.');
        final data = await collect();
        if (!await _exporter.export(data)) {
          throw StateError('Prometheus metric conversion failed.');
        }
        return _exporter.prometheusData;
      });

  @override
  Future<MetricData> collect() async {
    final provider = meterProvider;
    if (_shutdown || provider == null) return MetricData.empty();
    return MetricData(
      resource: provider.resource,
      metrics: await provider.collectAllMetrics(),
    );
  }

  /// Pull readers have no buffered exports to flush.
  @override
  Future<bool> forceFlush() async => !_shutdown;

  @override
  Future<bool> shutdown() => _closing ??= _close();

  Future<bool> _close() async {
    _shutdown = true;
    await ready;
    await _server.close();
    return _lock.synchronized(_exporter.shutdown);
  }
}
