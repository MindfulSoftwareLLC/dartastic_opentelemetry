// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

//
//  Generated code. Do not modify.
//  source: opentelemetry/proto/collector/trace/v1/trace_service.proto
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

import 'trace_service.pb.dart' as $0;

export 'trace_service.pb.dart';

@$pb.GrpcServiceName('opentelemetry.proto.collector.trace.v1.TraceService')
class TraceServiceClient extends $grpc.Client {
  static final _$export = $grpc.ClientMethod<$0.ExportTraceServiceRequest, $0.ExportTraceServiceResponse>(
      '/opentelemetry.proto.collector.trace.v1.TraceService/Export',
      ($0.ExportTraceServiceRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ExportTraceServiceResponse.fromBuffer(value));

  TraceServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.ExportTraceServiceResponse> export($0.ExportTraceServiceRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$export, request, options: options);
  }
}

@$pb.GrpcServiceName('opentelemetry.proto.collector.trace.v1.TraceService')
abstract class TraceServiceBase extends $grpc.Service {
  $core.String get $name => 'opentelemetry.proto.collector.trace.v1.TraceService';

  TraceServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ExportTraceServiceRequest, $0.ExportTraceServiceResponse>(
        'Export',
        export_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ExportTraceServiceRequest.fromBuffer(value),
        ($0.ExportTraceServiceResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.ExportTraceServiceResponse> export_Pre($grpc.ServiceCall call, $async.Future<$0.ExportTraceServiceRequest> request) async {
    return export(call, await request);
  }

  $async.Future<$0.ExportTraceServiceResponse> export($grpc.ServiceCall call, $0.ExportTraceServiceRequest request);
}
