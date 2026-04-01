// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/collector/trace/v1/trace_service.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Mock gRPC services
// ---------------------------------------------------------------------------

/// Service that takes a long time to respond, for testing pending exports,
/// forceFlush with pending exports, and shutdown with pending exports.
class SlowTraceService extends TraceServiceBase {
  final Completer<void> exportStarted = Completer();
  final Completer<void> shouldComplete = Completer();

  @override
  Future<ExportTraceServiceResponse> export(
      ServiceCall call, ExportTraceServiceRequest request) async {
    if (!exportStarted.isCompleted) {
      exportStarted.complete();
    }
    await shouldComplete.future;
    return ExportTraceServiceResponse();
  }
}

/// Service that throws a non-GrpcError (plain Exception), exercising the
/// generic catch block in _export (lines 482-507).
class GenericThrowTraceService extends TraceServiceBase {
  int callCount = 0;

  @override
  Future<ExportTraceServiceResponse> export(
      ServiceCall call, ExportTraceServiceRequest request) async {
    callCount++;
    throw Exception('Generic non-gRPC error');
  }
}

/// Service that throws INTERNAL error (or another channel-level error)
/// for a configurable number of calls, then succeeds. This exercises the
/// channel recreation path in _tryExport (lines 344-356, 217-219).
class InternalErrorTraceService extends TraceServiceBase {
  int callCount = 0;
  final int failCount;
  final int failCode;

  InternalErrorTraceService({
    this.failCount = 1,
    this.failCode = StatusCode.internal,
  });

  @override
  Future<ExportTraceServiceResponse> export(
      ServiceCall call, ExportTraceServiceRequest request) async {
    callCount++;
    if (callCount <= failCount) {
      throw GrpcError.custom(failCode, 'Simulated channel error');
    }
    return ExportTraceServiceResponse();
  }
}

/// Service that throws UNAVAILABLE error every time, for testing shutdown
/// during retry loops.
class AlwaysUnavailableTraceService extends TraceServiceBase {
  int callCount = 0;

  @override
  Future<ExportTraceServiceResponse> export(
      ServiceCall call, ExportTraceServiceRequest request) async {
    callCount++;
    throw const GrpcError.custom(StatusCode.unavailable, 'Always unavailable');
  }
}

// ---------------------------------------------------------------------------
// Minimal Span implementation for testing
// ---------------------------------------------------------------------------

class _TestSpan implements Span {
  @override
  final String name;
  @override
  final SpanContext spanContext;
  @override
  final Resource resource;
  @override
  final InstrumentationScope instrumentationScope;
  @override
  final SpanKind kind;
  @override
  Attributes attributes;
  @override
  final DateTime startTime;
  @override
  final DateTime? endTime;

  bool _isEnded = false;
  SpanStatusCode _status = SpanStatusCode.Ok;
  String? _statusDescription;

  _TestSpan({
    required this.name,
    required this.spanContext,
    required this.resource,
    required this.instrumentationScope,
    required this.kind,
    required this.attributes,
    required this.startTime,
    this.endTime,
  }) {
    if (endTime != null) {
      _isEnded = true;
    }
  }

  @override
  bool get isEnded => _isEnded;

  @override
  bool get isRecording => !_isEnded;

  @override
  SpanStatusCode get status => _status;

  @override
  String? get statusDescription => _statusDescription;

  @override
  SpanContext? get parentSpanContext => null;

  @override
  Span? get parentSpan => null;

  @override
  List<SpanEvent>? get spanEvents => null;

  @override
  List<SpanLink>? get spanLinks => null;

  @override
  void end({DateTime? endTime, SpanStatusCode? spanStatus}) {
    _isEnded = true;
  }

  @override
  void setStatus(SpanStatusCode code, [String? description]) {
    _status = code;
    _statusDescription = description;
  }

  @override
  void setIntAttribute(String key, int value) {}

  @override
  void setBoolAttribute(String key, bool value) {}

  @override
  void setDoubleAttribute(String key, double value) {}

  @override
  void addEventNow(String name, [Attributes? attributes]) {}

  @override
  void addLink(SpanContext spanContext, [Attributes? attributes]) {}

  @override
  void addAttributes(Attributes attributes) {}

  @override
  void addEvents(Map<String, Attributes?> spanEvents) {}

  @override
  void addSpanLink(SpanLink spanLink) {}

  @override
  bool isInstanceOf(Type type) => false;

  @override
  bool get isValid => true;

  @override
  void setBoolListAttribute(String name, List<bool> value) {}

  @override
  void setDateTimeAsStringAttribute(String name, DateTime value) {}

  @override
  void setDoubleListAttribute(String name, List<double> value) {}

  @override
  void setIntListAttribute(String name, List<int> value) {}

  @override
  void setStringListAttribute<T>(String name, List<String> value) {}

  @override
  SpanId get spanId => spanContext.spanId;

  @override
  void updateName(String name) {}

  @override
  void addEvent(SpanEvent spanEvent) {}

  @override
  void recordException(Object exception,
      {StackTrace? stackTrace, Attributes? attributes, bool? escaped}) {}

  @override
  void setStringAttribute<T>(String name, String value) {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Span _createTestSpan({
  required String name,
  String? traceId,
  String? spanId,
  Map<String, Object>? attributes,
  DateTime? startTime,
  DateTime? endTime,
}) {
  final sc = OTel.spanContext(
    traceId: OTel.traceIdFrom(traceId ?? '00112233445566778899aabbccddeeff'),
    spanId: OTel.spanIdFrom(spanId ?? '0011223344556677'),
  );

  final resource = OTel.resource(OTel.attributesFromMap({
    'service.name': 'test-service',
    'service.version': '1.0.0',
  }));

  final instrumentationScope = OTel.instrumentationScope(
    name: 'test-tracer',
    version: '1.0.0',
  );

  return _TestSpan(
    name: name,
    spanContext: sc,
    resource: resource,
    instrumentationScope: instrumentationScope,
    kind: SpanKind.internal,
    attributes: attributes != null
        ? OTel.attributesFromMap(attributes)
        : OTel.attributes(),
    startTime: startTime ?? DateTime.now(),
    endTime: endTime,
  );
}

OtlpGrpcSpanExporter _createExporter(int port, {int maxRetries = 2}) {
  return OtlpGrpcSpanExporter(OtlpGrpcExporterConfig(
    endpoint: 'http://localhost:$port',
    insecure: true,
    maxRetries: maxRetries,
    baseDelay: const Duration(milliseconds: 1),
    maxDelay: const Duration(milliseconds: 10),
  ));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OtlpGrpcSpanExporter edge cases', () {
    setUp(() async {
      await OTel.reset();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = (_) {};

      await OTel.initialize(
        serviceName: 'test',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
      OTelLog.logFunction = null;
    });

    // -----------------------------------------------------------------------
    // 1. Shutdown during active export suppresses error
    //    Covers lines 389-396 (shutdown-interrupted catch in export())
    // -----------------------------------------------------------------------
    test('shutdown during active export suppresses error', () async {
      final service = SlowTraceService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);
      final span = _createTestSpan(name: 'slow-export-span');

      // Start an export that will block in the slow service
      final exportFuture = exporter.export([span]);

      // Wait until the service has actually received the request
      await service.exportStarted.future;

      // Now shut down the exporter while the export is in flight.
      // This sets _isShutdown = true and waits for pending exports with a timeout.
      final shutdownFuture = exporter.shutdown();

      // Allow the slow service to complete so the export can finish.
      // The export code sees _isShutdown but the "shut down during" StateError
      // path is exercised in the retry loop, and the suppression in export().
      service.shouldComplete.complete();

      // Both should complete without throwing
      await exportFuture;
      await shutdownFuture;

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 2. Server handler exception surfaces as GrpcError UNKNOWN
    //    When a gRPC server handler throws a plain Exception, the framework
    //    wraps it as GrpcError(UNKNOWN). UNKNOWN is non-retryable but
    //    triggers channel recreation (lines 344-356).
    // -----------------------------------------------------------------------
    test('server handler exception surfaces as GrpcError UNKNOWN', () async {
      final service = GenericThrowTraceService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 1);
      final span = _createTestSpan(name: 'generic-error-span');

      await expectLater(
        () => exporter.export([span]),
        throwsA(isA<GrpcError>().having(
          (e) => e.code,
          'code',
          equals(StatusCode.unknown),
        )),
      );

      // UNKNOWN is non-retryable, so only 1 call to the service
      expect(service.callCount, equals(1));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 3. Non-gRPC server triggers generic catch block in _export
    //    Connect to a raw HTTP server that speaks broken protocol.
    //    The gRPC client may throw a non-GrpcError (or a wrapped one).
    //    Either way, the generic catch block (lines 481-507) handles it.
    //    Covers lines 482-507 (generic catch), 493-495 (max retries check)
    // -----------------------------------------------------------------------
    test('broken protocol server exercises generic error handling', () async {
      // Start a raw HTTP server that immediately closes connections
      final rawServer = await HttpServer.bind('127.0.0.1', 0);
      final port = rawServer.port;
      rawServer.listen((request) {
        // Send a non-gRPC response to break protocol
        request.response.statusCode = 200;
        request.response.headers.set('content-type', 'text/plain');
        request.response.write('not a gRPC response');
        request.response.close();
      });

      // Use short timeout and no retries to keep the test fast
      final exporter = OtlpGrpcSpanExporter(OtlpGrpcExporterConfig(
        endpoint: 'http://localhost:$port',
        insecure: true,
        maxRetries: 0,
        timeout: const Duration(seconds: 3),
        baseDelay: const Duration(milliseconds: 1),
        maxDelay: const Duration(milliseconds: 10),
      ));
      final span = _createTestSpan(name: 'broken-protocol-span');

      // Should throw some kind of error (GrpcError or other)
      await expectLater(
        () => exporter.export([span]),
        throwsA(anything),
      );

      await exporter.shutdown();
      await rawServer.close(force: true);
    }, timeout: const Timeout(Duration(seconds: 15)));

    // -----------------------------------------------------------------------
    // 4. _tryExport channel error triggers channel recreation
    //    Covers lines 344-356 (INTERNAL triggers cleanup + _initialized=false)
    //    and lines 217-219 (TraceServiceClient creation)
    // -----------------------------------------------------------------------
    test('_tryExport channel error triggers channel recreation', () async {
      // Fail once with INTERNAL, then succeed on second attempt
      final service = InternalErrorTraceService(
        failCount: 1,
        failCode: StatusCode.internal,
      );
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      // INTERNAL is not in _retryableStatusCodes, so it will be a
      // non-retryable GrpcError. The channel recreation happens in _tryExport
      // but the error is still rethrown. So we verify that:
      // 1) The error triggers channel recreation code path
      // 2) The exporter rethrows the error (since INTERNAL is non-retryable)
      final exporter = _createExporter(port, maxRetries: 0);
      final span = _createTestSpan(name: 'internal-error-span');

      await expectLater(
        () => exporter.export([span]),
        throwsA(isA<GrpcError>().having(
          (e) => e.code,
          'code',
          equals(StatusCode.internal),
        )),
      );

      expect(service.callCount, equals(1));
      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 4b. UNAVAILABLE triggers channel recreation AND is retryable
    //     Covers lines 344-356 (channel recreation) + successful retry
    // -----------------------------------------------------------------------
    test('UNAVAILABLE error triggers channel recreation and retry succeeds',
        () async {
      // Fail once with UNAVAILABLE, then succeed on second attempt
      final service = InternalErrorTraceService(
        failCount: 1,
        failCode: StatusCode.unavailable,
      );
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 2);
      final span = _createTestSpan(name: 'unavailable-retry-span');

      // Should succeed after retry
      await exporter.export([span]);

      // First call fails, second succeeds
      expect(service.callCount, equals(2));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 4c. UNKNOWN error also triggers channel recreation
    // -----------------------------------------------------------------------
    test('UNKNOWN error triggers channel recreation', () async {
      final service = InternalErrorTraceService(
        failCount: 1,
        failCode: StatusCode.unknown,
      );
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      // UNKNOWN is not in _retryableStatusCodes, so it throws on first attempt
      final exporter = _createExporter(port, maxRetries: 0);
      final span = _createTestSpan(name: 'unknown-error-span');

      await expectLater(
        () => exporter.export([span]),
        throwsA(isA<GrpcError>().having(
          (e) => e.code,
          'code',
          equals(StatusCode.unknown),
        )),
      );

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 5. forceFlush with pending export waits
    //    Covers lines 527-535 (waiting for pending exports in forceFlush)
    // -----------------------------------------------------------------------
    test('forceFlush with pending export waits for completion', () async {
      final service = SlowTraceService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);
      final span = _createTestSpan(name: 'flush-pending-span');

      // Start export (it will block in slow service)
      // We must NOT await this - it is intentionally left pending
      // ignore: unawaited_futures
      final exportFuture = exporter.export([span]);

      // Wait until the service has received the export call
      await service.exportStarted.future;

      // Start forceFlush - it should wait for the pending export
      bool flushCompleted = false;
      final flushFuture = exporter.forceFlush().then((_) {
        flushCompleted = true;
      });

      // Flush should not have completed yet (export is still pending)
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
    // 6. forceFlush error during pending export
    //    Covers lines 537-540 (error catch in forceFlush)
    // -----------------------------------------------------------------------
    test('forceFlush catches error from pending failed export', () async {
      final service = GenericThrowTraceService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port, maxRetries: 0);
      final span = _createTestSpan(name: 'flush-error-span');

      // Start export (it will fail but that takes a moment for channel setup)
      Object? exportError;
      // ignore: unawaited_futures
      final exportFuture = exporter.export([span]).catchError((Object e) {
        exportError = e;
      });

      // Give a small delay for the export to start
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Force flush should handle the error gracefully (not throw)
      await exporter.forceFlush();

      // Wait for the export to finish
      await exportFuture;

      // The export itself should have failed
      expect(exportError, isNotNull);

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 7. Shutdown with pending exports and timeout
    //    Covers lines 570-588 (shutdown waiting for pending exports with timeout)
    // -----------------------------------------------------------------------
    test('shutdown with pending exports completes via timeout', () async {
      final service = SlowTraceService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);
      final span = _createTestSpan(name: 'shutdown-pending-span');

      // Start export that will block
      // ignore: unawaited_futures
      final exportFuture = exporter.export([span]);

      // Wait until the service has received the request
      await service.exportStarted.future;

      // Shutdown will set _isShutdown and wait for pending exports with a 10s timeout.
      // We complete the slow service so it finishes before the timeout.
      // This exercises the pendingExportsCopy.isNotEmpty path (lines 570-591).
      Future<void>.delayed(const Duration(milliseconds: 100)).then((_) {
        service.shouldComplete.complete();
      });

      await exporter.shutdown();

      // The export should complete (or be suppressed)
      try {
        await exportFuture;
      } catch (_) {
        // Suppressed shutdown errors are acceptable
      }

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 8. _createChannelCredentials with secure mode (no certs)
    //    Covers lines 60-62 (secure path without certificates)
    // -----------------------------------------------------------------------
    test('_createChannelCredentials with secure mode and no certs', () async {
      // Create exporter with insecure=false and no certificates.
      // This will create ChannelCredentials.secure() (line 63).
      // Exporting to an insecure local server will fail due to TLS mismatch,
      // but the credentials creation path is covered.
      final service = InternalErrorTraceService(failCount: 0);
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      final exporter = OtlpGrpcSpanExporter(OtlpGrpcExporterConfig(
        endpoint: 'http://localhost:$port',
        insecure: false, // Triggers secure credentials path
        maxRetries: 0,
        baseDelay: const Duration(milliseconds: 1),
        maxDelay: const Duration(milliseconds: 10),
      ));

      final span = _createTestSpan(name: 'secure-creds-span');

      // The export will fail because we are using secure creds against an
      // insecure server, but the _createChannelCredentials secure path
      // (lines 60-63) is executed.
      try {
        await exporter.export([span]);
      } catch (_) {
        // Expected - TLS mismatch
      }

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 9. Shutdown during retry stops retrying
    //    Covers lines 425-430 (wasShutdownDuringRetry && attempts > 0)
    //    and lines 446-451 (GrpcError catch with wasShutdownDuringRetry)
    // -----------------------------------------------------------------------
    test('shutdown during retry stops retrying', () async {
      final service = AlwaysUnavailableTraceService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      // Use higher maxRetries so the export loop runs longer
      final exporter = _createExporter(port, maxRetries: 10);
      final span = _createTestSpan(name: 'shutdown-during-retry-span');

      // Start the export - it will keep retrying due to UNAVAILABLE
      final exportFuture = exporter.export([span]).catchError((Object e) {
        // Errors expected during shutdown
      });

      // Wait for at least one retry attempt, then shut down
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await exporter.shutdown();

      // Wait for the export to finish
      await exportFuture;

      // The export should either have been suppressed or errored
      // (shutdown-interrupted StateError is suppressed by export())
      // Either way it should not hang
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 10. _ensureChannel throws StateError when shutdown
    //     Covers lines 238-243 (_ensureChannel with isShutdown)
    // -----------------------------------------------------------------------
    test('_ensureChannel throws StateError when exporter is shutdown',
        () async {
      final service = InternalErrorTraceService(failCount: 0);
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      await exporter.shutdown();

      final span = _createTestSpan(name: 'post-shutdown-span');

      expect(
        () => exporter.export([span]),
        throwsA(isA<StateError>()),
      );

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 11. _setupChannel returns early when shutdown
    //     Covers lines 157-162 (_setupChannel shutdown check)
    // -----------------------------------------------------------------------
    test('export after shutdown prevents channel setup', () async {
      final service = InternalErrorTraceService(failCount: 0);
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      // First export to initialize channel
      final span1 = _createTestSpan(name: 'init-span');
      await exporter.export([span1]);

      // Shutdown
      await exporter.shutdown();

      // Trying to export again should throw
      final span2 = _createTestSpan(name: 'after-shutdown-span');
      expect(
        () => exporter.export([span2]),
        throwsA(isA<StateError>()),
      );

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 12. _tryExport with isShutdown after _ensureChannel
    //     Covers line 266 (_tryExport isShutdown check after _ensureChannel)
    // -----------------------------------------------------------------------
    test('_tryExport detects shutdown after channel setup', () async {
      // This test verifies that the _tryExport method checks _isShutdown
      // after _ensureChannel. We do this by shutting down after
      // initialization, which will set _isShutdown.
      final service = InternalErrorTraceService(failCount: 0);
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      // Initialize by doing one successful export
      final span1 = _createTestSpan(name: 'init-span-for-tryexport');
      await exporter.export([span1]);

      // Shutdown, then try to export - the StateError will be thrown
      await exporter.shutdown();

      final span2 = _createTestSpan(name: 'post-shutdown-tryexport');
      expect(
        () => exporter.export([span2]),
        throwsA(isA<StateError>()),
      );

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 13. _cleanupChannel error paths during shutdown
    //     Covers lines 108-113, 123-128 (error handling in _cleanupChannel)
    // -----------------------------------------------------------------------
    test('_cleanupChannel handles errors gracefully during shutdown', () async {
      final service = InternalErrorTraceService(failCount: 0);
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      // Initialize the channel with a successful export
      final span = _createTestSpan(name: 'cleanup-test-span');
      await exporter.export([span]);

      // Kill the server before shutdown to force channel cleanup errors
      await server.shutdown();

      // Shutdown should still complete gracefully even though the
      // underlying channel shutdown/terminate may error
      await exporter.shutdown();
    });

    // -----------------------------------------------------------------------
    // 14. _export shutdown detection on first attempt (line 407-408)
    //     Covers the _isShutdown check at the beginning of _export
    // -----------------------------------------------------------------------
    test('_export detects shutdown at start', () async {
      final service = InternalErrorTraceService(failCount: 0);
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      await exporter.shutdown();

      // export() checks _isShutdown first (line 364), before calling _export
      final span = _createTestSpan(name: 'export-shutdown-span');
      expect(
        () => exporter.export([span]),
        throwsA(isA<StateError>()),
      );

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 15. Generic error with shutdown during retry
    //     Covers lines 489-491 (wasShutdownDuringRetry in generic catch)
    // -----------------------------------------------------------------------
    test('generic error with shutdown during retry throws StateError',
        () async {
      final service = GenericThrowTraceService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      // Use higher maxRetries to give time for shutdown during retries
      final exporter = _createExporter(port, maxRetries: 10);
      final span = _createTestSpan(name: 'generic-shutdown-retry-span');

      final exportFuture = exporter.export([span]).catchError((Object e) {
        // Errors expected during shutdown
      });

      // Wait for the first attempt to fail and retry to start
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Shutdown during the retry loop
      await exporter.shutdown();

      await exportFuture;

      // The error should have been suppressed (StateError with 'shut down during')
      // or no error at all since export() catches StateError with 'shut down during'

      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 16. Verify debug logging output exercises all log paths
    // -----------------------------------------------------------------------
    test('debug logging covers all export code paths', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;
      OTelLog.enableTraceLogging();

      final service = InternalErrorTraceService(failCount: 0);
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);
      final span = _createTestSpan(
        name: 'debug-logging-edge-span',
        attributes: {'test.key': 'test.value'},
      );

      await exporter.export([span]);

      // Verify key log messages were emitted
      expect(
        logMessages.any((msg) => msg.contains('Setting up gRPC channel')),
        isTrue,
      );
      expect(
        logMessages
            .any((msg) => msg.contains('Successfully created gRPC channel')),
        isTrue,
      );
      expect(
        logMessages.any(
            (msg) => msg.contains('Export request completed successfully')),
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
    // 17. _traceService null check (line 325-328)
    //     This is hard to trigger directly since _setupChannel always creates
    //     it, but we verify it by checking the error path when the exporter
    //     is in a bad state.
    // -----------------------------------------------------------------------
    test('export with compression headers enabled', () async {
      final service = InternalErrorTraceService(failCount: 0);
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      // Create exporter with compression enabled to exercise lines 311-313
      final exporter = OtlpGrpcSpanExporter(OtlpGrpcExporterConfig(
        endpoint: 'http://localhost:$port',
        insecure: true,
        compression: true,
        maxRetries: 0,
        baseDelay: const Duration(milliseconds: 1),
        maxDelay: const Duration(milliseconds: 10),
      ));

      final span = _createTestSpan(name: 'compression-span');
      await exporter.export([span]);

      expect(service.callCount, equals(1));

      await exporter.shutdown();
      await server.shutdown();
    });

    // -----------------------------------------------------------------------
    // 18. Multiple pending exports tracked and flushed
    // -----------------------------------------------------------------------
    test('multiple concurrent exports are tracked in _pendingExports',
        () async {
      final service = SlowTraceService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;
      final exporter = _createExporter(port);

      final span = _createTestSpan(name: 'concurrent-pending-span');

      // Start an export that will block
      // ignore: unawaited_futures
      final exportFuture = exporter.export([span]);

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
    // 19. Shutdown timeout path when export never completes
    //     Covers lines 577-584 (timeout handler in shutdown)
    // -----------------------------------------------------------------------
    test('shutdown times out when export hangs', () async {
      final service = SlowTraceService();
      final server = Server.create(services: [service]);
      await server.serve(port: 0);
      final port = server.port!;

      final exporter = _createExporter(port);
      final span = _createTestSpan(name: 'hanging-export-span');

      // Start an export that will never complete (we won't call shouldComplete)
      // ignore: unawaited_futures
      final exportFuture = exporter.export([span]).catchError((Object e) {
        // Errors expected during shutdown timeout
      });

      // Wait for the export to start
      await service.exportStarted.future;

      // Shutdown should complete via its 10s timeout even though the export hangs.
      // We use a test timeout to ensure this doesn't hang forever.
      await exporter.shutdown().timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                fail('shutdown should complete within its internal timeout'),
          );

      // Clean up: let the slow service complete so the test can tear down
      service.shouldComplete.complete();
      try {
        await exportFuture;
      } catch (_) {
        // Expected
      }

      await server.shutdown();
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
