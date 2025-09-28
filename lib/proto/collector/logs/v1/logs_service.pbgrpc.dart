// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

//
//  Generated code. Do not modify.
//  source: opentelemetry/proto/collector/logs/v1/logs_service.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references, public_member_api_docs
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'logs_service.pb.dart' as $2;

export 'logs_service.pb.dart';

@$pb.GrpcServiceName('opentelemetry.proto.collector.logs.v1.LogsService')
class LogsServiceClient extends $grpc.Client {
  static final _$export = $grpc.ClientMethod<$2.ExportLogsServiceRequest,
          $2.ExportLogsServiceResponse>(
      '/opentelemetry.proto.collector.logs.v1.LogsService/Export',
      ($2.ExportLogsServiceRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) =>
          $2.ExportLogsServiceResponse.fromBuffer(value));

  LogsServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options, interceptors: interceptors);

  $grpc.ResponseFuture<$2.ExportLogsServiceResponse> export(
      $2.ExportLogsServiceRequest request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$export, request, options: options);
  }
}

@$pb.GrpcServiceName('opentelemetry.proto.collector.logs.v1.LogsService')
abstract class LogsServiceBase extends $grpc.Service {
  $core.String get $name => 'opentelemetry.proto.collector.logs.v1.LogsService';

  LogsServiceBase() {
    $addMethod($grpc.ServiceMethod<$2.ExportLogsServiceRequest,
            $2.ExportLogsServiceResponse>(
        'Export',
        export_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $2.ExportLogsServiceRequest.fromBuffer(value),
        ($2.ExportLogsServiceResponse value) => value.writeToBuffer()));
  }

  $async.Future<$2.ExportLogsServiceResponse> export_Pre($grpc.ServiceCall call,
      $async.Future<$2.ExportLogsServiceRequest> request) async {
    return export(call, await request);
  }

  $async.Future<$2.ExportLogsServiceResponse> export(
      $grpc.ServiceCall call, $2.ExportLogsServiceRequest request);
}
