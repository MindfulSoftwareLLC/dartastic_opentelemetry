// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/collector/trace/v1/trace_service.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Mock gRPC services
// ---------------------------------------------------------------------------

/// A mock TraceService that records all requests and can optionally fail.
class MockTraceService extends TraceServiceBase {
  int exportCount = 0;
  List<ExportTraceServiceRequest> requests = [];
  int? errorCode;

  @override
  Future<ExportTraceServiceResponse> export(
      ServiceCall call, ExportTraceServiceRequest request) async {
    exportCount++;
    requests.add(request);
    if (errorCode != null) {
      throw GrpcError.custom(errorCode!, 'Mock error');
    }
    return ExportTraceServiceResponse();
  }
}

/// A mock TraceService that fails a configurable number of times then succeeds.
class RetryMockTraceService extends TraceServiceBase {
  int exportCount = 0;
  int failCount;
  int failCode;

  RetryMockTraceService({
    this.failCount = 0,
    this.failCode = StatusCode.unavailable,
  });

  @override
  Future<ExportTraceServiceResponse> export(
      ServiceCall call, ExportTraceServiceRequest request) async {
    exportCount++;
    if (exportCount <= failCount) {
      throw GrpcError.custom(failCode, 'Mock error');
    }
    return ExportTraceServiceResponse();
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
// Helper to create a test span
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

// ---------------------------------------------------------------------------
// Helper to create exporter pointed at a local gRPC server
// ---------------------------------------------------------------------------

OtlpGrpcSpanExporter _createExporter(int port) {
  return OtlpGrpcSpanExporter(OtlpGrpcExporterConfig(
    endpoint: 'http://localhost:$port',
    insecure: true,
    maxRetries: 2,
    baseDelay: const Duration(milliseconds: 1),
    maxDelay: const Duration(milliseconds: 10),
  ));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OtlpGrpcSpanExporter full gRPC integration', () {
    late Server grpcServer;
    late int port;
    late MockTraceService mockService;

    setUp(() async {
      await OTel.reset();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = (_) {};

      mockService = MockTraceService();
      grpcServer = Server.create(services: [mockService]);
      await grpcServer.serve(port: 0); // random available port
      port = grpcServer.port!;

      await OTel.initialize(
        serviceName: 'test',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await grpcServer.shutdown();
      await OTel.shutdown();
      await OTel.reset();
      OTelLog.logFunction = null;
    });

    // 1
    test('export sends spans to gRPC endpoint', () async {
      final exporter = _createExporter(port);
      final span = _createTestSpan(name: 'grpc-test-span');

      await exporter.export([span]);

      expect(mockService.exportCount, equals(1));

      await exporter.shutdown();
    });

    // 2
    test('export sends correct number of resource spans', () async {
      final exporter = _createExporter(port);
      final span = _createTestSpan(name: 'resource-span-check');

      await exporter.export([span]);

      expect(mockService.requests, hasLength(1));
      final request = mockService.requests.first;
      expect(request.resourceSpans, isNotEmpty);
      expect(request.resourceSpans.first.scopeSpans, isNotEmpty);
      expect(request.resourceSpans.first.scopeSpans.first.spans, isNotEmpty);
      expect(
        request.resourceSpans.first.scopeSpans.first.spans.first.name,
        equals('resource-span-check'),
      );

      await exporter.shutdown();
    });

    // 3
    test('export with empty spans returns without error', () async {
      final exporter = _createExporter(port);

      // Exporting an empty list should return immediately without calling the
      // server at all.
      await exporter.export([]);

      expect(mockService.exportCount, equals(0));

      await exporter.shutdown();
    });

    // 4
    test('export after shutdown throws StateError', () async {
      final exporter = _createExporter(port);
      await exporter.shutdown();

      final span = _createTestSpan(name: 'after-shutdown-span');

      expect(
        () => exporter.export([span]),
        throwsA(isA<StateError>()),
      );
    });

    // 5
    test('shutdown completes gracefully', () async {
      final exporter = _createExporter(port);
      final span = _createTestSpan(name: 'before-shutdown');

      await exporter.export([span]);
      // Shutdown should not throw.
      await exporter.shutdown();
    });

    // 6
    test('shutdown is idempotent', () async {
      final exporter = _createExporter(port);
      await exporter.shutdown();
      await exporter.shutdown();
      await exporter.shutdown();
      // No exception means success.
    });

    // 7
    test('forceFlush after shutdown returns', () async {
      final exporter = _createExporter(port);
      await exporter.shutdown();
      // Should complete without error even though exporter is shut down.
      await exporter.forceFlush();
    });

    // 8
    test('forceFlush before any export returns', () async {
      final exporter = _createExporter(port);
      // No exports have been made, forceFlush should return immediately.
      await exporter.forceFlush();
      await exporter.shutdown();
    });

    // 9
    test('_ensureChannel creates channel on first export', () async {
      final exporter = _createExporter(port);
      final span = _createTestSpan(name: 'channel-creation-span');

      await exporter.export([span]);

      // The mock service received the span, which means the channel was created
      // and connected successfully.
      expect(mockService.exportCount, equals(1));

      await exporter.shutdown();
    });

    // 10
    test('export with debug logging exercises all paths', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;
      OTelLog.enableTraceLogging();

      final exporter = _createExporter(port);
      final span = _createTestSpan(
        name: 'debug-logging-span',
        attributes: {'debug.key': 'debug.value'},
      );

      await exporter.export([span]);

      // Verify that debug log messages were emitted during export.
      expect(logMessages, isNotEmpty);
      expect(
        logMessages.any((msg) => msg.contains('OtlpGrpcSpanExporter')),
        isTrue,
        reason: 'Expected OtlpGrpcSpanExporter debug log messages',
      );

      await exporter.shutdown();
    });

    // 15
    test('channel cleanup on shutdown', () async {
      final exporter = _createExporter(port);
      final span = _createTestSpan(name: 'cleanup-span');

      await exporter.export([span]);
      expect(mockService.exportCount, equals(1));

      await exporter.shutdown();

      // After shutdown, exporting again should throw.
      expect(
        () => exporter.export([_createTestSpan(name: 'post-shutdown')]),
        throwsA(isA<StateError>()),
      );
    });

    // 16
    test('_setupChannel with debug logging', () async {
      final logMessages = <String>[];
      OTelLog.logFunction = logMessages.add;
      OTelLog.enableTraceLogging();

      final exporter = _createExporter(port);
      final span = _createTestSpan(name: 'setup-channel-log-span');

      await exporter.export([span]);

      // Verify setup-related log messages.
      expect(
        logMessages.any((msg) => msg.contains('Setting up gRPC channel')),
        isTrue,
        reason: 'Expected channel setup debug log messages',
      );

      await exporter.shutdown();
    });

    // 17
    test('multiple exports reuse channel', () async {
      final exporter = _createExporter(port);

      final span1 = _createTestSpan(name: 'reuse-channel-1');
      final span2 = _createTestSpan(
        name: 'reuse-channel-2',
        spanId: '1122334455667788',
      );

      await exporter.export([span1]);
      await exporter.export([span2]);

      expect(mockService.exportCount, equals(2));
      expect(mockService.requests, hasLength(2));
      expect(
        mockService
            .requests[0].resourceSpans.first.scopeSpans.first.spans.first.name,
        equals('reuse-channel-1'),
      );
      expect(
        mockService
            .requests[1].resourceSpans.first.scopeSpans.first.spans.first.name,
        equals('reuse-channel-2'),
      );

      await exporter.shutdown();
    });
  });

  // -----------------------------------------------------------------------
  // Retry tests -- each uses its own server with RetryMockTraceService
  // -----------------------------------------------------------------------
  group('OtlpGrpcSpanExporter retry behaviour', () {
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

    // 11
    test('retries on UNAVAILABLE (503)', () async {
      final retryService = RetryMockTraceService(
        failCount: 1,
        failCode: StatusCode.unavailable,
      );
      final retryServer = Server.create(services: [retryService]);
      await retryServer.serve(port: 0);
      final retryPort = retryServer.port!;

      final retryExporter = _createExporter(retryPort);
      final span = _createTestSpan(name: 'retry-unavailable-span');

      await retryExporter.export([span]);

      // First call fails, second succeeds => exportCount == 2
      expect(retryService.exportCount, equals(2));

      await retryExporter.shutdown();
      await retryServer.shutdown();
    });

    // 12
    test('retries on RESOURCE_EXHAUSTED (429)', () async {
      final retryService = RetryMockTraceService(
        failCount: 1,
        failCode: StatusCode.resourceExhausted,
      );
      final retryServer = Server.create(services: [retryService]);
      await retryServer.serve(port: 0);
      final retryPort = retryServer.port!;

      final retryExporter = _createExporter(retryPort);
      final span = _createTestSpan(name: 'retry-resource-exhausted-span');

      await retryExporter.export([span]);

      // First call fails, second succeeds => exportCount == 2
      expect(retryService.exportCount, equals(2));

      await retryExporter.shutdown();
      await retryServer.shutdown();
    });

    // 13
    test('does not retry on INVALID_ARGUMENT', () async {
      final retryService = RetryMockTraceService(
        failCount: 100, // always fails
        failCode: StatusCode.invalidArgument,
      );
      final retryServer = Server.create(services: [retryService]);
      await retryServer.serve(port: 0);
      final retryPort = retryServer.port!;

      final retryExporter = _createExporter(retryPort);
      final span = _createTestSpan(name: 'no-retry-invalid-arg-span');

      await expectLater(
        () => retryExporter.export([span]),
        throwsA(isA<GrpcError>().having(
          (e) => e.code,
          'code',
          equals(StatusCode.invalidArgument),
        )),
      );

      // Should have been called exactly once (no retries for non-retryable codes).
      expect(retryService.exportCount, equals(1));

      await retryExporter.shutdown();
      await retryServer.shutdown();
    });

    // 14
    test('gives up after max retries', () async {
      // The exporter is configured with maxRetries: 2, so total attempts = 3.
      // We make the service always fail.
      final retryService = RetryMockTraceService(
        failCount: 100,
        failCode: StatusCode.unavailable,
      );
      final retryServer = Server.create(services: [retryService]);
      await retryServer.serve(port: 0);
      final retryPort = retryServer.port!;

      final retryExporter = _createExporter(retryPort);
      final span = _createTestSpan(name: 'max-retry-span');

      await expectLater(
        () => retryExporter.export([span]),
        throwsA(isA<GrpcError>().having(
          (e) => e.code,
          'code',
          equals(StatusCode.unavailable),
        )),
      );

      // maxRetries=2 means initial attempt + 2 retries = 3 total attempts.
      expect(retryService.exportCount, equals(3));

      await retryExporter.shutdown();
      await retryServer.shutdown();
    });
  });
}
