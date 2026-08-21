// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Issue #228 coverage for the logs gRPC exporter's User-Agent. The spans
// gRPC exporter is covered in test/unit/otlp_spec_compliance_behavior_test
// and the metrics gRPC exporter in otlp_grpc_metric_exporter_full_test;
// this closes the logs gap.

import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart'
    hide Server;
import 'package:dartastic_opentelemetry/proto/collector/logs/v1/logs_service.pbgrpc.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:test/test.dart';

class _CapturingLogsService extends LogsServiceBase {
  final userAgents = <String?>[];
  final firstCall = Completer<void>();

  @override
  Future<ExportLogsServiceResponse> export(
    grpc.ServiceCall call,
    ExportLogsServiceRequest request,
  ) async {
    userAgents.add(call.clientMetadata?['user-agent']);
    if (!firstCall.isCompleted) firstCall.complete();
    return ExportLogsServiceResponse();
  }
}

void main() {
  setUp(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'red-228-logs-grpc',
      detectPlatformResources: false,
      enableMetrics: false,
      enableLogs: false,
    );
  });

  tearDown(() async {
    await OTel.reset();
  });

  test('logs gRPC export identifies the exporter per spec (issue #228)',
      () async {
    final svc = _CapturingLogsService();
    final server = grpc.Server.create(services: [svc]);
    await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
    addTearDown(server.shutdown);

    final exporter = OtlpGrpcLogRecordExporter(
      OtlpGrpcLogRecordExporterConfig(
        endpoint: 'http://localhost:${server.port}',
        insecure: true,
      ),
    );
    addTearDown(exporter.shutdown);

    final scope =
        OTel.instrumentationScope(name: 'review-red', version: '1.0.0');
    await exporter.export([
      SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'user-agent-check',
      ),
    ]);

    await svc.firstCall.future.timeout(const Duration(seconds: 5));
    expect(svc.userAgents.first, startsWith('OTel-OTLP-Exporter-Dart/'));
  });
}
