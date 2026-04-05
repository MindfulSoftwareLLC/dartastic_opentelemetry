// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/collector/logs/v1/logs_service.proto.

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

import 'logs_service.pb.dart' as $0;

export 'logs_service.pb.dart';

/// Service that can be used to push logs between one Application instrumented with
/// OpenTelemetry and an collector, or between an collector and a central collector (in this
/// case logs are sent/received to/from multiple Applications).
@$pb.GrpcServiceName('opentelemetry.proto.collector.logs.v1.LogsService')
class LogsServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  LogsServiceClient(super.channel, {super.options, super.interceptors});

  /// For performance reasons, it is recommended to keep this RPC
  /// alive for the entire life of the application.
  $grpc.ResponseFuture<$0.ExportLogsServiceResponse> export(
    $0.ExportLogsServiceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$export, request, options: options);
  }

  // method descriptors

  static final _$export = $grpc.ClientMethod<$0.ExportLogsServiceRequest,
          $0.ExportLogsServiceResponse>(
      '/opentelemetry.proto.collector.logs.v1.LogsService/Export',
      ($0.ExportLogsServiceRequest value) => value.writeToBuffer(),
      $0.ExportLogsServiceResponse.fromBuffer);
}

@$pb.GrpcServiceName('opentelemetry.proto.collector.logs.v1.LogsService')
abstract class LogsServiceBase extends $grpc.Service {
  $core.String get $name => 'opentelemetry.proto.collector.logs.v1.LogsService';

  LogsServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ExportLogsServiceRequest,
            $0.ExportLogsServiceResponse>(
        'Export',
        export_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ExportLogsServiceRequest.fromBuffer(value),
        ($0.ExportLogsServiceResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.ExportLogsServiceResponse> export_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ExportLogsServiceRequest> $request) async {
    return export($call, await $request);
  }

  $async.Future<$0.ExportLogsServiceResponse> export(
      $grpc.ServiceCall call, $0.ExportLogsServiceRequest request);
}
