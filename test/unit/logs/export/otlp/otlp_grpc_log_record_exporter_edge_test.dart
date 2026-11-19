// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Edge coverage for OtlpGrpcLogRecordExporter using in-process mock
// gRPC services, mirroring the span exporter's edge suite: pending
// flush/shutdown, generic errors, retryable gRPC errors, give-up,
// shutdown-during-retry, and channel cleanup.

@Timeout(Duration(seconds: 60))
library;

import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart'
    hide Server;
import 'package:dartastic_opentelemetry/proto/collector/logs/v1/logs_service.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:test/test.dart';

class _SlowLogsService extends LogsServiceBase {
  final Completer<void> exportStarted = Completer();
  final Completer<void> shouldComplete = Completer();

  @override
  Future<ExportLogsServiceResponse> export(
    ServiceCall call,
    ExportLogsServiceRequest request,
  ) async {
    if (!exportStarted.isCompleted) {
      exportStarted.complete();
    }
    await shouldComplete.future;
    return ExportLogsServiceResponse();
  }
}

class _GenericThrowLogsService extends LogsServiceBase {
  @override
  Future<ExportLogsServiceResponse> export(
    ServiceCall call,
    ExportLogsServiceRequest request,
  ) async =>
      throw Exception('Generic non-gRPC error');
}

class _UnavailableThenOkLogsService extends LogsServiceBase {
  int callCount = 0;

  @override
  Future<ExportLogsServiceResponse> export(
    ServiceCall call,
    ExportLogsServiceRequest request,
  ) async {
    callCount++;
    if (callCount == 1) {
      throw const GrpcError.custom(
          StatusCode.unavailable, 'Temporarily unavailable');
    }
    return ExportLogsServiceResponse();
  }
}

class _AlwaysUnavailableLogsService extends LogsServiceBase {
  int callCount = 0;

  @override
  Future<ExportLogsServiceResponse> export(
    ServiceCall call,
    ExportLogsServiceRequest request,
  ) async {
    callCount++;
    throw const GrpcError.custom(StatusCode.unavailable, 'Always unavailable');
  }
}

void main() {
  group('OtlpGrpcLogRecordExporter edge cases', () {
    setUp(() async {
      await OTel.reset();
      OTelLog.logFunction = (_) {};
      await OTel.initialize(
        serviceName: 'grpc-log-edge-test',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
      );
      OTelLog.enableTraceLogging();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
      OTelLog.logFunction = null;
      OTelLog.currentLevel = LogLevel.info;
    });

    ReadableLogRecord record(String body) => SDKLogRecord(
          instrumentationScope:
              OTel.instrumentationScope(name: 'grpc-edge', version: '1.0.0'),
          severityNumber: Severity.INFO,
          body: body,
        );

    OtlpGrpcLogRecordExporter exporterFor(int port, {int maxRetries = 2}) {
      return OtlpGrpcLogRecordExporter(
        OtlpGrpcLogRecordExporterConfig(
          endpoint: 'localhost:$port',
          insecure: true,
          maxRetries: maxRetries,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );
    }

    test('forceFlush waits for a pending export; shutdown cleans the channel',
        () async {
      final service = _SlowLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final exporter = exporterFor(server.port!);

      final pending = exporter.export([record('slow')]);
      await service.exportStarted.future;
      final flush = exporter.forceFlush();
      service.shouldComplete.complete();
      await pending;
      await flush;

      await exporter.shutdown();
      await server.shutdown();
    });

    test('generic non-gRPC error fails the export', () async {
      final service = _GenericThrowLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final exporter = exporterFor(server.port!, maxRetries: 1);

      final result = await exporter.export([record('generic')]).then((r) => r,
          onError: (_) => ExportResult.failure);
      expect(result, isNot(equals(ExportResult.success)));

      await exporter.shutdown();
      await server.shutdown();
    });

    test('retryable unavailable error retries then succeeds', () async {
      final service = _UnavailableThenOkLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final exporter = exporterFor(server.port!, maxRetries: 3);

      await exporter.export([record('retry-me')]);
      expect(service.callCount, equals(2));

      await exporter.shutdown();
      await server.shutdown();
    });

    test('gives up after max retries of unavailable', () async {
      final service = _AlwaysUnavailableLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final exporter = exporterFor(server.port!, maxRetries: 2);

      final result = await exporter.export([record('doomed')]).then((r) => r,
          onError: (_) => ExportResult.failure);
      expect(result, isNot(equals(ExportResult.success)));
      expect(service.callCount, greaterThanOrEqualTo(2));

      await exporter.shutdown();
      await server.shutdown();
    });

    test('shutdown during backoff reports the original gRPC error once',
        () async {
      final service = _AlwaysUnavailableLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      addTearDown(server.shutdown);
      final errors = <Object>[];
      final stacks = <StackTrace?>[];
      OTel.setErrorHandler((error, stack) {
        errors.add(error);
        stacks.add(stack);
      });
      addTearDown(() => OTel.setErrorHandler(null));
      final retrying = Completer<void>();
      OTelLog.currentLevel = LogLevel.debug;
      OTelLog.logFunction = (message) {
        if (message.contains('Retrying after') && !retrying.isCompleted) {
          retrying.complete();
        }
      };
      final exporter =
          OtlpGrpcLogRecordExporter(OtlpGrpcLogRecordExporterConfig(
        endpoint: 'localhost:${server.port}',
        insecure: true,
        maxRetries: 1,
        baseDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(milliseconds: 100),
      ));
      addTearDown(exporter.shutdown);
      final pending = exporter.export([record('shutdown')]);
      await retrying.future;
      await exporter.shutdown();
      expect(await pending, ExportResult.failure);
      expect(service.callCount, 1);
      expect(errors, hasLength(1));
      expect(
          errors.single,
          isA<GrpcError>()
              .having((e) => e.code, 'code', StatusCode.unavailable));
      expect(stacks.single, isNotNull);
    });

    test('invalid CA and transport failure are reported independently',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('otel-invalid-ca');
      addTearDown(() => directory.delete(recursive: true));
      final ca =
          await File('${directory.path}/ca.pem').writeAsString('garbage PEM');
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      final errors = <Object>[];
      final stacks = <StackTrace?>[];
      OTel.setErrorHandler((error, stack) {
        errors.add(error);
        stacks.add(stack);
      });
      addTearDown(() => OTel.setErrorHandler(null));
      final exporter =
          OtlpGrpcLogRecordExporter(OtlpGrpcLogRecordExporterConfig(
        endpoint: '127.0.0.1:$port',
        insecure: false,
        certificate: ca.path,
        maxRetries: 0,
        timeout: const Duration(seconds: 1),
      ));
      final processor = SimpleLogRecordProcessor(exporter);
      addTearDown(processor.shutdown);
      await processor.onEmit(
          SDKLogRecord(
            instrumentationScope: OTel.instrumentationScope(name: 'invalid-ca'),
            body: 'test',
          ),
          null);
      expect(errors, hasLength(2));
      expect(errors.first, isA<TlsException>());
      expect(
          errors.last,
          isA<GrpcError>().having((e) => e.code, 'code',
              anyOf(StatusCode.unavailable, StatusCode.deadlineExceeded)));
      expect(stacks, everyElement(isNotNull));
      await processor.shutdown();
      expect(errors, hasLength(2));
    });

    test('connection refused fails the export', () async {
      final exporter = exporterFor(1, maxRetries: 1); // nothing listens on 1
      final result = await exporter.export([record('refused')]).then((r) => r,
          onError: (_) => ExportResult.failure);
      expect(result, isNot(equals(ExportResult.success)));
      await exporter.shutdown();
    });

    test('export after shutdown fails; flush and re-shutdown are no-ops',
        () async {
      final exporter = exporterFor(1);
      await exporter.shutdown();
      final result = await exporter.export([record('late')]).then((r) => r,
          onError: (_) => ExportResult.failure);
      expect(result, isNot(equals(ExportResult.success)));
      await exporter.forceFlush();
      await exporter.shutdown();
    });

    test('empty batch succeeds without contacting the server', () async {
      final exporter = exporterFor(1);
      final result = await exporter.export([]);
      expect(result, equals(ExportResult.success));
      await exporter.shutdown();
    });
  });
}
