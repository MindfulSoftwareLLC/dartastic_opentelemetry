// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/collector/metrics/v1/metrics_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'metrics_service.pb.dart' as $0;

export 'metrics_service.pb.dart';

/// Service that can be used to push metrics between one Application
/// instrumented with OpenTelemetry and a collector, or between a collector and a
/// central collector.
@$pb.GrpcServiceName('opentelemetry.proto.collector.metrics.v1.MetricsService')
class MetricsServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  MetricsServiceClient(super.channel, {super.options, super.interceptors});

  /// For performance reasons, it is recommended to keep this RPC
  /// alive for the entire life of the application.
  $grpc.ResponseFuture<$0.ExportMetricsServiceResponse> export(
    $0.ExportMetricsServiceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$export, request, options: options);
  }

  // method descriptors

  static final _$export = $grpc.ClientMethod<$0.ExportMetricsServiceRequest,
          $0.ExportMetricsServiceResponse>(
      '/opentelemetry.proto.collector.metrics.v1.MetricsService/Export',
      ($0.ExportMetricsServiceRequest value) => value.writeToBuffer(),
      $0.ExportMetricsServiceResponse.fromBuffer);
}

@$pb.GrpcServiceName('opentelemetry.proto.collector.metrics.v1.MetricsService')
abstract class MetricsServiceBase extends $grpc.Service {
  $core.String get $name =>
      'opentelemetry.proto.collector.metrics.v1.MetricsService';

  MetricsServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ExportMetricsServiceRequest,
            $0.ExportMetricsServiceResponse>(
        'Export',
        export_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ExportMetricsServiceRequest.fromBuffer(value),
        ($0.ExportMetricsServiceResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.ExportMetricsServiceResponse> export_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ExportMetricsServiceRequest> $request) async {
    return export($call, await $request);
  }

  $async.Future<$0.ExportMetricsServiceResponse> export(
      $grpc.ServiceCall call, $0.ExportMetricsServiceRequest request);
}
