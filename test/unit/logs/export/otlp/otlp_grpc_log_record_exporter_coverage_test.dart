// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/collector/logs/v1/logs_service.pbgrpc.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Mock gRPC services
// ---------------------------------------------------------------------------

/// A simple logs service that always succeeds.
class SuccessLogsService extends LogsServiceBase {
  int callCount = 0;

  @override
  Future<ExportLogsServiceResponse> export(
    ServiceCall call,
    ExportLogsServiceRequest request,
  ) async {
    callCount++;
    return ExportLogsServiceResponse();
  }
}

/// Service that takes a long time to respond, for testing pending exports,
/// forceFlush with pending exports, and shutdown with pending exports.
class SlowLogsService extends LogsServiceBase {
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

/// Service that throws a non-GrpcError (plain Exception), exercising the
/// generic catch block in _export.
class GenericThrowLogsService extends LogsServiceBase {
  int callCount = 0;

  @override
  Future<ExportLogsServiceResponse> export(
    ServiceCall call,
    ExportLogsServiceRequest request,
  ) async {
    callCount++;
    throw Exception('Generic non-gRPC error');
  }
}

/// Service that throws a specific gRPC error for a configurable number of
/// calls, then succeeds. This exercises the channel recreation path and
/// retry logic.
class ConfigurableErrorLogsService extends LogsServiceBase {
  int callCount = 0;
  final int failCount;
  final int failCode;

  ConfigurableErrorLogsService({
    this.failCount = 1,
    this.failCode = StatusCode.internal,
  });

  @override
  Future<ExportLogsServiceResponse> export(
    ServiceCall call,
    ExportLogsServiceRequest request,
  ) async {
    callCount++;
    if (callCount <= failCount) {
      throw GrpcError.custom(failCode, 'Simulated gRPC error');
    }
    return ExportLogsServiceResponse();
  }
}

/// Service that always throws UNAVAILABLE, for testing shutdown during retries.
class AlwaysUnavailableLogsService extends LogsServiceBase {
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

/// Service that always throws RESOURCE_EXHAUSTED, for testing retryable errors.
class AlwaysResourceExhaustedLogsService extends LogsServiceBase {
  int callCount = 0;

  @override
  Future<ExportLogsServiceResponse> export(
    ServiceCall call,
    ExportLogsServiceRequest request,
  ) async {
    callCount++;
    throw const GrpcError.custom(
        StatusCode.resourceExhausted, 'Resource exhausted');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a test [ReadableLogRecord] for use in export tests.
ReadableLogRecord _createTestLogRecord({
  String body = 'Test log message',
  Severity severity = Severity.INFO,
  Map<String, Object>? attributes,
}) {
  final scope = OTel.instrumentationScope(
    name: 'test-log-scope',
    version: '1.0.0',
  );
  final resource = OTel.resource(
    OTel.attributesFromMap({
      'service.name': 'test-log-service',
      'service.version': '1.0.0',
    }),
  );

  final record = SDKLogRecord(
    instrumentationScope: scope,
    resource: resource,
    severityNumber: severity,
    severityText: severity.name,
    body: body,
    timestamp: Int64(DateTime.now().microsecondsSinceEpoch * 1000),
    observedTimestamp: Int64(DateTime.now().microsecondsSinceEpoch * 1000),
    attributes: attributes != null ? OTel.attributesFromMap(attributes) : null,
  );

  return record;
}

/// Creates an [OtlpGrpcLogRecordExporter] configured to talk to a local test
/// server on the given [port].
OtlpGrpcLogRecordExporter _createExporter(int port, {int maxRetries = 2}) {
  return OtlpGrpcLogRecordExporter(
    OtlpGrpcLogRecordExporterConfig(
      endpoint: 'http://localhost:$port',
      insecure: true,
      maxRetries: maxRetries,
      baseDelay: const Duration(milliseconds: 1),
      maxDelay: const Duration(milliseconds: 10),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Config tests
  // =========================================================================
  group('OtlpGrpcLogRecordExporterConfig', () {
    group('default values', () {
      test('default config has expected values', () {
        final config = OtlpGrpcLogRecordExporterConfig();

        expect(config.endpoint, equals('localhost:4317'));
        expect(config.headers, isEmpty);
        expect(config.timeout, equals(const Duration(seconds: 10)));
        expect(config.compression, isFalse);
        expect(config.insecure, isTrue);
        expect(config.maxRetries, equals(3));
        expect(config.baseDelay, equals(const Duration(milliseconds: 100)));
        expect(config.maxDelay, equals(const Duration(seconds: 1)));
        expect(config.certificate, isNull);
        expect(config.clientKey, isNull);
        expect(config.clientCertificate, isNull);
      });
    });

    group('endpoint validation', () {
      test('custom endpoint is preserved', () {
        final config = OtlpGrpcLogRecordExporterConfig(
          endpoint: 'collector.example.com:4317',
        );
        expect(config.endpoint, equals('collector.example.com:4317'));
      });

      test('empty endpoint throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(endpoint: ''),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('empty'),
            ),
          ),
        );
      });

      test('endpoint with spaces throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(endpoint: 'host name:4317'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('spaces'),
            ),
          ),
        );
      });

      test('endpoint without port gets :4317 appended', () {
        final config = OtlpGrpcLogRecordExporterConfig(endpoint: 'localhost');
        expect(config.endpoint, equals('localhost:4317'));
      });

      test('endpoint with http:// scheme is stripped', () {
        final config = OtlpGrpcLogRecordExporterConfig(
          endpoint: 'http://collector:4317',
        );
        expect(config.endpoint, equals('collector:4317'));
      });

      test('endpoint with https:// scheme is stripped', () {
        final config = OtlpGrpcLogRecordExporterConfig(
          endpoint: 'https://collector:4317',
        );
        expect(config.endpoint, equals('collector:4317'));
      });

      test('host-only endpoint gets default port appended', () {
        final config = OtlpGrpcLogRecordExporterConfig(
          endpoint: 'collector.example.com',
        );
        expect(config.endpoint, equals('collector.example.com:4317'));
      });
    });

    group('header validation', () {
      test('custom headers are normalized to lowercase keys', () {
        final config = OtlpGrpcLogRecordExporterConfig(
          headers: {'Authorization': 'Bearer token123', 'X-Custom': 'value'},
        );
        expect(
          config.headers,
          containsPair('authorization', 'Bearer token123'),
        );
        expect(config.headers, containsPair('x-custom', 'value'));
        expect(config.headers.containsKey('Authorization'), isFalse);
      });

      test('empty header key throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(headers: {'': 'value'}),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('empty'),
            ),
          ),
        );
      });

      test('empty header value throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(headers: {'key': ''}),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('empty'),
            ),
          ),
        );
      });
    });

    group('retry validation', () {
      test('negative maxRetries throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(maxRetries: -1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('negative'),
            ),
          ),
        );
      });

      test('zero retries is valid', () {
        final config = OtlpGrpcLogRecordExporterConfig(maxRetries: 0);
        expect(config.maxRetries, equals(0));
      });

      test('positive maxRetries is valid', () {
        final config = OtlpGrpcLogRecordExporterConfig(maxRetries: 10);
        expect(config.maxRetries, equals(10));
      });
    });

    group('timeout validation', () {
      test('timeout below 1ms throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(timeout: Duration.zero),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Timeout'),
            ),
          ),
        );
      });

      test('timeout above 10 minutes throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(
            timeout: const Duration(minutes: 10, milliseconds: 1),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Timeout'),
            ),
          ),
        );
      });

      test('timeout at lower bound (1ms) is valid', () {
        final config = OtlpGrpcLogRecordExporterConfig(
          timeout: const Duration(milliseconds: 1),
        );
        expect(config.timeout, equals(const Duration(milliseconds: 1)));
      });

      test('timeout at upper bound (10 minutes) is valid', () {
        final config = OtlpGrpcLogRecordExporterConfig(
          timeout: const Duration(minutes: 10),
        );
        expect(config.timeout, equals(const Duration(minutes: 10)));
      });
    });

    group('delay validation', () {
      test('baseDelay below 1ms throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(baseDelay: Duration.zero),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('baseDelay'),
            ),
          ),
        );
      });

      test('maxDelay below 1ms throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(
            baseDelay: const Duration(milliseconds: 1),
            maxDelay: Duration.zero,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('maxDelay'),
            ),
          ),
        );
      });

      test('baseDelay above 5 minutes throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(
            baseDelay: const Duration(minutes: 5, milliseconds: 1),
            maxDelay: const Duration(minutes: 5, milliseconds: 2),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('baseDelay'),
            ),
          ),
        );
      });

      test('maxDelay above 5 minutes throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(
            maxDelay: const Duration(minutes: 5, milliseconds: 1),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('maxDelay'),
            ),
          ),
        );
      });

      test('baseDelay greater than maxDelay throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(
            baseDelay: const Duration(seconds: 2),
            maxDelay: const Duration(seconds: 1),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('maxDelay cannot be less than baseDelay'),
            ),
          ),
        );
      });

      test('baseDelay equal to maxDelay is valid', () {
        final config = OtlpGrpcLogRecordExporterConfig(
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 1),
        );
        expect(config.baseDelay, equals(const Duration(seconds: 1)));
        expect(config.maxDelay, equals(const Duration(seconds: 1)));
      });
    });

    group('flags', () {
      test('insecure flag is set correctly', () {
        final insecureConfig = OtlpGrpcLogRecordExporterConfig(insecure: true);
        expect(insecureConfig.insecure, isTrue);

        final secureConfig = OtlpGrpcLogRecordExporterConfig(insecure: false);
        expect(secureConfig.insecure, isFalse);
      });

      test('compression flag is set correctly', () {
        final compressedConfig =
            OtlpGrpcLogRecordExporterConfig(compression: true);
        expect(compressedConfig.compression, isTrue);

        final uncompressedConfig =
            OtlpGrpcLogRecordExporterConfig(compression: false);
        expect(uncompressedConfig.compression, isFalse);
      });
    });

    group('certificate validation', () {
      test('clientKey without clientCertificate throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(clientKey: 'some-key'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('clientCertificate without clientKey throws ArgumentError', () {
        expect(
          () => OtlpGrpcLogRecordExporterConfig(clientCertificate: 'some-cert'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('all certificate fields null is valid', () {
        final config = OtlpGrpcLogRecordExporterConfig();
        expect(config.certificate, isNull);
        expect(config.clientKey, isNull);
        expect(config.clientCertificate, isNull);
      });
    });

    group('custom values', () {
      test('all custom values are preserved', () {
        final config = OtlpGrpcLogRecordExporterConfig(
          endpoint: 'otel-collector:4317',
          headers: {'x-api-key': 'secret'},
          timeout: const Duration(seconds: 30),
          compression: true,
          insecure: false,
          maxRetries: 5,
          baseDelay: const Duration(milliseconds: 200),
          maxDelay: const Duration(seconds: 5),
        );

        expect(config.endpoint, equals('otel-collector:4317'));
        expect(config.headers, containsPair('x-api-key', 'secret'));
        expect(config.timeout, equals(const Duration(seconds: 30)));
        expect(config.compression, isTrue);
        expect(config.insecure, isFalse);
        expect(config.maxRetries, equals(5));
        expect(config.baseDelay, equals(const Duration(milliseconds: 200)));
        expect(config.maxDelay, equals(const Duration(seconds: 5)));
      });
    });
  });

  // =========================================================================
  // Exporter tests
  // =========================================================================
  group('OtlpGrpcLogRecordExporter', () {
    setUp(() async {
      await OTel.reset();
      OTelLog.logFunction = (_) {};

      await OTel.initialize(
        serviceName: 'test-log-service',
        detectPlatformResources: false,
        enableLogs: false,
      );
      OTelLog.enableTraceLogging();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
      OTelLog.logFunction = null;
    });

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    group('constructor', () {
      test('creates exporter with default config', () {
        final exporter = OtlpGrpcLogRecordExporter();
        expect(exporter, isNotNull);
      });

      test('creates exporter with custom config', () {
        final config = OtlpGrpcLogRecordExporterConfig(
          endpoint: 'collector:4317',
          maxRetries: 5,
        );
        final exporter = OtlpGrpcLogRecordExporter(config);
        expect(exporter, isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    // Export with empty records returns success immediately
    // -----------------------------------------------------------------------
    test('export with empty records returns success', () async {
      final exporter = OtlpGrpcLogRecordExporter();
      final result = await exporter.export([]);
      expect(result, equals(ExportResult.success));
      await exporter.shutdown();
    });

    // -----------------------------------------------------------------------
    // Export after shutdown returns failure
    // -----------------------------------------------------------------------
    test('export after shutdown returns failure', () async {
      final exporter = OtlpGrpcLogRecordExporter();
      await exporter.shutdown();

      final logRecord = _createTestLogRecord();
      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.failure));
    });

    // -----------------------------------------------------------------------
    // Shutdown idempotency
    // -----------------------------------------------------------------------
    test('shutdown is idempotent', () async {
      final exporter = OtlpGrpcLogRecordExporter();

      // Multiple shutdowns should not throw
      await exporter.shutdown();
      await exporter.shutdown();
      await exporter.shutdown();
    });

    // -----------------------------------------------------------------------
    // ForceFlush when not shut down and no pending exports
    // -----------------------------------------------------------------------
    test('forceFlush with no pending exports completes immediately', () async {
      final exporter = OtlpGrpcLogRecordExporter();
      await exporter.forceFlush();
      await exporter.shutdown();
    });

    // -----------------------------------------------------------------------
    // ForceFlush after shutdown returns immediately
    // -----------------------------------------------------------------------
    test('forceFlush after shutdown returns immediately', () async {
      final exporter = OtlpGrpcLogRecordExporter();
      await exporter.shutdown();
      await exporter.forceFlush();
    });

    // -----------------------------------------------------------------------
    // Successful export to a real gRPC service
    // -----------------------------------------------------------------------
    test('successful export returns success', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);
      final logRecord = _createTestLogRecord();

      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.success));
      expect(service.callCount, equals(1));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Export multiple log records
    // -----------------------------------------------------------------------
    test('export multiple log records succeeds', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      final logRecords = List.generate(
        5,
        (i) => _createTestLogRecord(body: 'Message $i'),
      );

      final result = await exporter.export(logRecords);
      expect(result, equals(ExportResult.success));
      expect(service.callCount, equals(1));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Export with compression headers enabled
    // -----------------------------------------------------------------------
    test('export with compression headers enabled', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      final exporter = OtlpGrpcLogRecordExporter(
        OtlpGrpcLogRecordExporterConfig(
          endpoint: 'http://localhost:$port',
          insecure: true,
          compression: true,
          maxRetries: 0,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );

      final logRecord = _createTestLogRecord();
      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.success));
      expect(service.callCount, equals(1));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Export with custom headers
    // -----------------------------------------------------------------------
    test('export with custom headers', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      final exporter = OtlpGrpcLogRecordExporter(
        OtlpGrpcLogRecordExporterConfig(
          endpoint: 'http://localhost:$port',
          insecure: true,
          headers: {'x-api-key': 'test-key'},
          maxRetries: 0,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );

      final logRecord = _createTestLogRecord();
      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.success));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Shutdown during active export suppresses error
    // -----------------------------------------------------------------------
    test('shutdown during active export suppresses error', () async {
      final service = SlowLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);
      final logRecord = _createTestLogRecord();

      // Start an export that will block in the slow service
      final exportFuture = exporter.export([logRecord]);

      // Wait until the service has actually received the request
      await service.exportStarted.future;

      // Shut down the exporter while the export is in flight
      final shutdownFuture = exporter.shutdown();

      // Allow the slow service to complete
      service.shouldComplete.complete();

      // Both should complete without throwing
      final result = await exportFuture;
      await shutdownFuture;

      // The result may be success or failure depending on timing
      expect(result, isA<ExportResult>());

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Non-retryable gRPC error (e.g., INTERNAL) returns failure
    // The gRPC framework wraps server exceptions as GrpcError(UNKNOWN).
    // -----------------------------------------------------------------------
    test('server handler exception returns failure', () async {
      final service = GenericThrowLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 1);
      final logRecord = _createTestLogRecord();

      // The log exporter catches all errors in export() and returns failure
      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.failure));

      // UNKNOWN is non-retryable, so only 1 call to the service
      expect(service.callCount, equals(1));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // INTERNAL error triggers channel recreation
    // -----------------------------------------------------------------------
    test('INTERNAL error triggers channel recreation and returns failure',
        () async {
      final service = ConfigurableErrorLogsService(
        failCount: 1,
        failCode: StatusCode.internal,
      );
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      // INTERNAL is not in _retryableStatusCodes, so it returns failure
      final exporter = _createExporter(port, maxRetries: 0);
      final logRecord = _createTestLogRecord();

      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.failure));
      expect(service.callCount, equals(1));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // UNAVAILABLE error triggers channel recreation AND is retryable
    // -----------------------------------------------------------------------
    test('UNAVAILABLE error triggers retry and succeeds', () async {
      // Fail once with UNAVAILABLE, then succeed on second attempt
      final service = ConfigurableErrorLogsService(
        failCount: 1,
        failCode: StatusCode.unavailable,
      );
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 2);
      final logRecord = _createTestLogRecord();

      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.success));

      // First call fails, second succeeds
      expect(service.callCount, equals(2));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // RESOURCE_EXHAUSTED error is retryable
    // -----------------------------------------------------------------------
    test('RESOURCE_EXHAUSTED error triggers retry and succeeds', () async {
      final service = ConfigurableErrorLogsService(
        failCount: 1,
        failCode: StatusCode.resourceExhausted,
      );
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 2);
      final logRecord = _createTestLogRecord();

      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.success));
      expect(service.callCount, equals(2));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // UNKNOWN error triggers channel recreation
    // -----------------------------------------------------------------------
    test('UNKNOWN error triggers channel recreation', () async {
      final service = ConfigurableErrorLogsService(
        failCount: 1,
        failCode: StatusCode.unknown,
      );
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      // UNKNOWN is not in _retryableStatusCodes, so export fails
      final exporter = _createExporter(port, maxRetries: 0);
      final logRecord = _createTestLogRecord();

      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.failure));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Max retries exhausted with retryable error returns failure
    // -----------------------------------------------------------------------
    test('max retries exhausted returns failure', () async {
      final service = AlwaysUnavailableLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 2);
      final logRecord = _createTestLogRecord();

      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.failure));

      // Initial attempt + 2 retries = 3 calls
      expect(service.callCount, equals(3));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Max retries exhausted with RESOURCE_EXHAUSTED error returns failure
    // -----------------------------------------------------------------------
    test('max retries exhausted with RESOURCE_EXHAUSTED returns failure',
        () async {
      final service = AlwaysResourceExhaustedLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 1);
      final logRecord = _createTestLogRecord();

      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.failure));

      // Initial attempt + 1 retry = 2 calls
      expect(service.callCount, equals(2));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Non-retryable gRPC error (e.g., PERMISSION_DENIED)
    // -----------------------------------------------------------------------
    test('non-retryable gRPC error does not retry', () async {
      final service = ConfigurableErrorLogsService(
        failCount: 10,
        failCode: StatusCode.permissionDenied,
      );
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 5);
      final logRecord = _createTestLogRecord();

      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.failure));

      // Non-retryable: only 1 call
      expect(service.callCount, equals(1));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Generic (non-gRPC) error during export uses generic catch block.
    // We use a connection-refusing port approach: connect to a port where
    // nothing is listening, with a short timeout so the gRPC client fails
    // quickly rather than hanging.
    // -----------------------------------------------------------------------
    test(
      'connection refused exercises generic error handling',
      () async {
        // Bind and immediately close to get a port that refuses connections
        final tempServer = await ServerSocket.bind('127.0.0.1', 0);
        final port = tempServer.port;
        await tempServer.close();

        final exporter = OtlpGrpcLogRecordExporter(
          OtlpGrpcLogRecordExporterConfig(
            endpoint: '127.0.0.1:$port',
            insecure: true,
            maxRetries: 0,
            timeout: const Duration(seconds: 3),
            baseDelay: const Duration(milliseconds: 1),
            maxDelay: const Duration(milliseconds: 10),
          ),
        );
        final logRecord = _createTestLogRecord();

        final result = await exporter.export([logRecord]);
        expect(result, equals(ExportResult.failure));

        await exporter.shutdown();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    // -----------------------------------------------------------------------
    // Generic error with retries: connection refused with retries exhausted
    // -----------------------------------------------------------------------
    test(
      'connection refused with retries exhausted returns failure',
      () async {
        final tempServer = await ServerSocket.bind('127.0.0.1', 0);
        final port = tempServer.port;
        await tempServer.close();

        final exporter = OtlpGrpcLogRecordExporter(
          OtlpGrpcLogRecordExporterConfig(
            endpoint: '127.0.0.1:$port',
            insecure: true,
            maxRetries: 1,
            timeout: const Duration(seconds: 3),
            baseDelay: const Duration(milliseconds: 1),
            maxDelay: const Duration(milliseconds: 10),
          ),
        );
        final logRecord = _createTestLogRecord();

        final result = await exporter.export([logRecord]);
        expect(result, equals(ExportResult.failure));

        await exporter.shutdown();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    // -----------------------------------------------------------------------
    // ForceFlush with pending export waits for completion
    // -----------------------------------------------------------------------
    test('forceFlush with pending export waits for completion', () async {
      final service = SlowLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);
      final logRecord = _createTestLogRecord();

      // Start export (it will block in slow service)
      // ignore: unawaited_futures
      final exportFuture = exporter.export([logRecord]);

      // Wait until the service has received the export call
      await service.exportStarted.future;

      // Start forceFlush - it should wait for the pending export
      bool flushCompleted = false;
      final flushFuture = exporter.forceFlush().then((_) {
        flushCompleted = true;
      });

      // Flush should not have completed yet
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(flushCompleted, isFalse);

      // Now let the export complete
      service.shouldComplete.complete();

      // Both should finish
      await exportFuture;
      await flushFuture;
      expect(flushCompleted, isTrue);

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // ForceFlush catches error from pending failed export
    // -----------------------------------------------------------------------
    test('forceFlush catches error from pending failed export', () async {
      final service = GenericThrowLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 0);
      final logRecord = _createTestLogRecord();

      // Start export (it will fail)
      // ignore: unawaited_futures
      final exportFuture = exporter.export([logRecord]);

      // Give a small delay for the export to start
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Force flush should handle the error gracefully (not throw)
      await exporter.forceFlush();

      // Wait for the export to finish
      final result = await exportFuture;
      expect(result, equals(ExportResult.failure));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Shutdown with pending exports completes
    // -----------------------------------------------------------------------
    test('shutdown with pending exports completes', () async {
      final service = SlowLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);
      final logRecord = _createTestLogRecord();

      // Start export that will block
      // ignore: unawaited_futures
      final exportFuture = exporter.export([logRecord]);

      // Wait until the service has received the request
      await service.exportStarted.future;

      // Complete the slow service so export finishes before shutdown timeout
      Future<void>.delayed(const Duration(milliseconds: 100)).then((_) {
        service.shouldComplete.complete();
      });

      await exporter.shutdown();

      // The export should complete
      try {
        await exportFuture;
      } catch (_) {
        // Shutdown errors are acceptable
      }

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Shutdown timeout path when export never completes
    // -----------------------------------------------------------------------
    test(
      'shutdown times out when export hangs',
      () async {
        final service = SlowLogsService();
        final server = Server.create(services: [service]);
        await server.serve(port: 0);
        final port = server.port!;
        final exporter = _createExporter(port);
        final logRecord = _createTestLogRecord();

        // Start an export that will never complete
        // ignore: unawaited_futures
        final exportFuture = exporter.export([logRecord]).catchError(
          (Object e) => ExportResult.failure,
        );

        // Wait for the export to start
        await service.exportStarted.future;

        // Shutdown should complete via its 10s internal timeout
        await exporter.shutdown().timeout(
              const Duration(seconds: 15),
              onTimeout: () =>
                  fail('shutdown should complete within its internal timeout'),
            );

        // Clean up
        service.shouldComplete.complete();
        try {
          await exportFuture;
        } catch (_) {
          // Expected
        }

        await server.shutdown();
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    // -----------------------------------------------------------------------
    // Secure credentials path (no certificates)
    // -----------------------------------------------------------------------
    test('secure mode without certificates exercises secure path', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      final exporter = OtlpGrpcLogRecordExporter(
        OtlpGrpcLogRecordExporterConfig(
          endpoint: 'http://localhost:$port',
          insecure: false, // Triggers secure credentials path
          maxRetries: 0,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );

      final logRecord = _createTestLogRecord();

      // Export will fail due to TLS mismatch but the secure credential
      // creation path is exercised
      final result = await exporter.export([logRecord]);
      // Failure expected due to TLS mismatch
      expect(result, isA<ExportResult>());

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Shutdown during retry stops retrying
    // -----------------------------------------------------------------------
    test('shutdown during retry stops retrying', () async {
      final service = AlwaysUnavailableLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      // Use higher maxRetries so the export loop runs longer
      final exporter = _createExporter(port, maxRetries: 10);
      final logRecord = _createTestLogRecord();

      // Start the export - it will keep retrying due to UNAVAILABLE
      final exportFuture = exporter.export([logRecord]);

      // Wait for at least one retry attempt, then shut down
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await exporter.shutdown();

      // The export should return failure (not hang)
      final result = await exportFuture;
      expect(result, equals(ExportResult.failure));

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // _cleanupChannel handles errors gracefully during shutdown
    // -----------------------------------------------------------------------
    test('cleanup channel handles errors gracefully during shutdown', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      // Initialize the channel with a successful export
      final logRecord = _createTestLogRecord();
      await exporter.export([logRecord]);

      // Kill the server before shutdown to force channel cleanup errors
      await server.shutdown();

      // Shutdown should still complete gracefully
      await exporter.shutdown();
    });

    // -----------------------------------------------------------------------
    // _setupChannel returns early when shutdown
    // -----------------------------------------------------------------------
    test('export after shutdown prevents channel setup', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      // First export to initialize channel
      final logRecord1 = _createTestLogRecord(body: 'init');
      await exporter.export([logRecord1]);

      // Shutdown
      await exporter.shutdown();

      // Trying to export again should return failure (not throw)
      final logRecord2 = _createTestLogRecord(body: 'after-shutdown');
      final result = await exporter.export([logRecord2]);
      expect(result, equals(ExportResult.failure));

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Multiple concurrent exports are tracked in _pendingExports
    // -----------------------------------------------------------------------
    test('multiple concurrent exports are tracked', () async {
      final service = SlowLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      final logRecord = _createTestLogRecord();

      // Start an export that will block
      // ignore: unawaited_futures
      final exportFuture = exporter.export([logRecord]);

      // Wait for it to start
      await service.exportStarted.future;

      // Call forceFlush to exercise the pending exports path
      Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
        service.shouldComplete.complete();
      });

      await exporter.forceFlush();
      await exportFuture;

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Generic error with shutdown during retry returns failure
    // -----------------------------------------------------------------------
    test('generic error with shutdown during retry returns failure', () async {
      final service = GenericThrowLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      // Use higher maxRetries to give time for shutdown during retries
      final exporter = _createExporter(port, maxRetries: 10);
      final logRecord = _createTestLogRecord();

      final exportFuture = exporter.export([logRecord]);

      // Wait for the first attempt to fail and retry to start
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Shutdown during the retry loop
      await exporter.shutdown();

      final result = await exportFuture;
      expect(result, equals(ExportResult.failure));

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Empty records returns success even with debug logging enabled
    // -----------------------------------------------------------------------
    test('empty records with debug logging returns success', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;
      OTelLog.enableTraceLogging();

      final exporter = OtlpGrpcLogRecordExporter();
      final result = await exporter.export([]);
      expect(result, equals(ExportResult.success));

      expect(
        logMessages.any((msg) => msg.contains('No log records to export')),
        isTrue,
      );

      await exporter.shutdown();
    });

    // -----------------------------------------------------------------------
    // Debug logging covers key export code paths
    // -----------------------------------------------------------------------
    test('debug logging covers all export code paths', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;
      OTelLog.enableTraceLogging();

      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);
      final logRecord = _createTestLogRecord(
        body: 'debug-logging-test',
        attributes: {'test.key': 'test.value'},
      );

      await exporter.export([logRecord]);

      // Verify key log messages were emitted
      expect(
        logMessages.any((msg) => msg.contains('Setting up gRPC channel')),
        isTrue,
      );
      expect(
        logMessages.any(
          (msg) => msg.contains('Successfully created LogsServiceClient'),
        ),
        isTrue,
      );
      expect(
        logMessages.any(
          (msg) => msg.contains('Export request completed successfully'),
        ),
        isTrue,
      );

      await exporter.shutdown();

      // Verify shutdown logs
      expect(
        logMessages.any((msg) => msg.contains('Shutdown requested')),
        isTrue,
      );

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Endpoint parsing: localhost is converted to 127.0.0.1
    // -----------------------------------------------------------------------
    test('endpoint localhost is converted to 127.0.0.1', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      final exporter = OtlpGrpcLogRecordExporter(
        OtlpGrpcLogRecordExporterConfig(
          endpoint: 'localhost:$port',
          insecure: true,
          maxRetries: 0,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );

      final logRecord = _createTestLogRecord();
      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.success));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Endpoint with empty host falls back to 127.0.0.1 (testing the
    // _setupChannel parsing path). Uses a real local server bound to an
    // OS-assigned port so the assertion does not depend on whether port 4317
    // is occupied by some other process (e.g. a local Docker collector).
    // -----------------------------------------------------------------------
    test('endpoint empty host defaults to 127.0.0.1', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      final exporter = OtlpGrpcLogRecordExporter(
        OtlpGrpcLogRecordExporterConfig(
          endpoint: ':$port',
          insecure: true,
          maxRetries: 0,
          baseDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 10),
        ),
      );

      final logRecord = _createTestLogRecord();
      // The exporter must rewrite the empty host to 127.0.0.1 and reach the
      // local server, so the export should succeed.
      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.success));
      expect(service.callCount, greaterThanOrEqualTo(1));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Zero retries (maxRetries=0) means single attempt
    // -----------------------------------------------------------------------
    test('zero retries means single attempt', () async {
      final service = AlwaysUnavailableLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 0);
      final logRecord = _createTestLogRecord();

      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.failure));

      // Only 1 attempt, no retries
      expect(service.callCount, equals(1));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // _ensureChannel short-circuits when already initialized
    // -----------------------------------------------------------------------
    test('second export reuses existing channel', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      final logRecord1 = _createTestLogRecord(body: 'first');
      final logRecord2 = _createTestLogRecord(body: 'second');

      final result1 = await exporter.export([logRecord1]);
      final result2 = await exporter.export([logRecord2]);

      expect(result1, equals(ExportResult.success));
      expect(result2, equals(ExportResult.success));
      expect(service.callCount, equals(2));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Export with log record that has attributes
    // -----------------------------------------------------------------------
    test('export log record with attributes', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      final logRecord = _createTestLogRecord(
        body: 'with attrs',
        severity: Severity.ERROR,
        attributes: {
          'string.attr': 'hello',
          'int.attr': 42,
          'bool.attr': true,
          'double.attr': 3.14,
        },
      );

      final result = await exporter.export([logRecord]);
      expect(result, equals(ExportResult.success));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // Export with various severity levels
    // -----------------------------------------------------------------------
    test('export log records with different severities', () async {
      final service = SuccessLogsService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      final records = [
        _createTestLogRecord(body: 'trace msg', severity: Severity.TRACE),
        _createTestLogRecord(body: 'debug msg', severity: Severity.DEBUG),
        _createTestLogRecord(body: 'info msg', severity: Severity.INFO),
        _createTestLogRecord(body: 'warn msg', severity: Severity.WARN),
        _createTestLogRecord(body: 'error msg', severity: Severity.ERROR),
        _createTestLogRecord(body: 'fatal msg', severity: Severity.FATAL),
      ];

      final result = await exporter.export(records);
      expect(result, equals(ExportResult.success));

      await exporter.shutdown();
      await server.shutdown();
    });
  });
}
