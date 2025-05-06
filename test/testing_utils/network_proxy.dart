// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry/proto/opentelemetry_proto_dart.dart' as proto;
import 'package:grpc/grpc.dart' as grpc;

class NetworkProxyService extends proto.TraceServiceBase {
  final String targetHost;
  final int targetPort;
  late final grpc.ClientChannel _targetChannel;
  late final proto.TraceServiceClient _targetClient;
  bool _shouldFail = false;
  int _failureCount = 0;
  int? _curFailureCode;
  final _failurePattern = <int?>[];
  int _patternIndex = 0;

  NetworkProxyService(this.targetHost, this.targetPort) {
    _targetChannel = grpc.ClientChannel(
          targetHost,
          port: targetPort,
          options: const grpc.ChannelOptions(
            credentials: grpc.ChannelCredentials.insecure(),
          ),
    );
    _targetClient = proto.TraceServiceClient(_targetChannel);
  }

  @override
  Future<proto.ExportTraceServiceResponse> export(
      grpc.ServiceCall call,
      proto.ExportTraceServiceRequest request,
  ) async {
    // Check for failures
    if (_shouldFail && _failureCount > 0 || _failurePattern.isNotEmpty) {
      int? errorCode;
      if (_failurePattern.isNotEmpty) {
        errorCode = _failurePattern[_patternIndex];
        _patternIndex = (_patternIndex + 1) % _failurePattern.length;
      } else {
        errorCode = _curFailureCode ?? grpc.StatusCode.unavailable;
        _failureCount--;
      }

      if (errorCode != null) {
        throw grpc.GrpcError.custom(errorCode, 'Simulated error');
      }
    }

    // Forward request to target
    return await _targetClient.export(request);
  }

  void failNextRequests(int count, {int errorCode = grpc.StatusCode.unavailable}) {
    _shouldFail = true;
    _failureCount = count;
    _curFailureCode = errorCode;
    _failurePattern.clear();
  }

  void setFailurePattern(List<int?> pattern) {
    _failurePattern.clear();
    _failurePattern.addAll(pattern);
    _patternIndex = 0;
    _shouldFail = false;
    _failureCount = 0;
  }

  void stopFailing() {
    _shouldFail = false;
    _failureCount = 0;
    _curFailureCode = null;
    _failurePattern.clear();
  }

  Future<void> shutdown() async {
    await _targetChannel.shutdown();
  }
}

/// A gRPC proxy that can simulate network issues for testing.
class NetworkProxy {
  int listenPort;
  final String targetHost;
  final int targetPort;

  grpc.Server? _server;
  late NetworkProxyService _service;

  NetworkProxy({
    required this.listenPort,
    required this.targetHost,
    required this.targetPort,
  });

  Future<void> start() async {
    if (_server != null) {
      // If server is already running, stop it first
      try {
        await stop();
      } catch (e) {
        print('Error stopping existing proxy server: $e');
      }
    }
    
    _service = NetworkProxyService(targetHost, targetPort);
    _server = grpc.Server.create(services: [_service]);
    await _server!.serve(port: listenPort);
    print('Network proxy listening on port $listenPort -> $targetHost:$targetPort');
  }

  Future<void> stop() async {
    if (_server != null) {
      try {
        await _server!.shutdown();
        _server = null;
        print('Network proxy stopped');
      } catch (e) {
        print('Error stopping proxy server: $e');
        // Force cleanup if shutdown fails
        _server = null;
      }
    }
    
    try {
      await _service.shutdown();
    } catch (e) {
      print('Error stopping proxy service: $e');
    }
  }

  void failNextRequests(int count, {int errorCode = grpc.StatusCode.unavailable}) {
    _service.failNextRequests(count, errorCode: errorCode);
  }

  void setFailurePattern(List<int?> pattern) {
    _service.setFailurePattern(pattern);
  }

  void stopFailing() {
    _service.stopFailing();
  }
}
