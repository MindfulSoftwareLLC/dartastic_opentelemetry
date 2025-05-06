// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:grpc/grpc.dart';

import '../../../../dartastic_opentelemetry.dart';
import '../../../../proto/collector/metrics/v1/metrics_service.pbgrpc.dart';
import '../../../../proto/common/v1/common.pb.dart' as common_proto;
import '../../../../proto/metrics/v1/metrics.pb.dart' as proto;
import 'metric_transformer.dart';

/// OtlpGrpcMetricExporter exports metrics to the OpenTelemetry collector via gRPC.
class OtlpGrpcMetricExporter implements MetricExporter {
  // ignore: unused_field
  final OtlpGrpcMetricExporterConfig _config;
  final MetricsServiceClient _client;
  bool _shutdown = false;

  // Static channel reference to allow shutdown
  static late ClientChannel _channel;

  /// Creates a new OtlpGrpcMetricExporter with the given configuration.
  OtlpGrpcMetricExporter(this._config) : _client = _createClient(_config);

  static MetricsServiceClient _createClient(OtlpGrpcMetricExporterConfig config) {
    final channelOptions = ChannelOptions(
      credentials: config.insecure ? const ChannelCredentials.insecure() : const ChannelCredentials.secure(),
      codecRegistry: CodecRegistry(codecs: const [GzipCodec()]),
    );

    // Parse host and port from endpoint
    final Uri uri = Uri.parse(config.endpoint);
    final String host = uri.host;
    final int port = uri.port > 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);

    if (OTelLog.isLogExport()) {
      OTelLog.logExport('OtlpGrpcMetricExporter: Creating client for $host:$port');
    }

    // We store the channel separately to be able to shut it down later
    _channel = ClientChannel(
      host,
      port: port,
      options: channelOptions,
    );

    return MetricsServiceClient(
      _channel,
      options: CallOptions(timeout: Duration(milliseconds: config.timeoutMillis)),
    );
  }

  @override
  Future<bool> export(MetricData data) async {
    if (_shutdown) {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport('OtlpGrpcMetricExporter: Cannot export after shutdown');
      }
      return false;
    }

    if (data.metrics.isEmpty) {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport('OtlpGrpcMetricExporter: No metrics to export');
      }
      return true;
    }

    try {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport('OtlpGrpcMetricExporter: Exporting ${data.metrics.length} metrics');
        for (final metric in data.metrics) {
          OTelLog.logExport('  - ${metric.name} (${metric.type}): ${metric.points.length} data points');
        }
      }

      // Transform metrics data to protocol buffers
      final request = _buildExportRequest(data);

      // Export to the collector
      await _client.export(request);

      if (OTelLog.isLogExport()) {
        OTelLog.logExport('OtlpGrpcMetricExporter: Export successful');
      }
      return true;
    } catch (e, stackTrace) {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport('OtlpGrpcMetricExporter: Export failed: $e');
        OTelLog.logExport('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Builds the export request from the given metrics data.
  ExportMetricsServiceRequest _buildExportRequest(MetricData data) {
    final request = ExportMetricsServiceRequest();
    final resourceMetrics = proto.ResourceMetrics();

    // Add resource
    if (data.resource != null) {
      resourceMetrics.resource = MetricTransformer.transformResource(data.resource!);
    } else {
      // Create empty resource if none provided
      resourceMetrics.resource = MetricTransformer.transformResource(OTel.resource(null));
    }

    // Add scope metrics
    final scopeMetrics = proto.ScopeMetrics();
    scopeMetrics.metrics.addAll(data.metrics.map(MetricTransformer.transformMetric));

    // Add instrumentation scope (hardcoded for now)
    final scope = common_proto.InstrumentationScope();
    scope.name = '@dart/dartastic_opentelemetry';
    scope.version = '1.0.0';
    scopeMetrics.scope = scope;

    resourceMetrics.scopeMetrics.add(scopeMetrics);
    request.resourceMetrics.add(resourceMetrics);

    return request;
  }

  @override
  Future<bool> forceFlush() async {
    // No-op for this exporter
    return true;
  }

  @override
  Future<bool> shutdown() async {
    if (_shutdown) {
      return true;
    }

    _shutdown = true;
    try {
      // Close the gRPC channel
      // Shutdown the stored channel
      await _channel.shutdown();

      if (OTelLog.isLogExport()) {
        OTelLog.logExport('OtlpGrpcMetricExporter: Channel shutdown completed');
      }
      return true;
    } catch (e) {
      if (OTelLog.isLogExport()) {
        OTelLog.logExport('OtlpGrpcMetricExporter: Shutdown failed: $e');
      }
      return false;
    }
  }
}
