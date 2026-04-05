// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpGrpcSpanExporter State Management', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    group('constructor', () {
      test('constructor with default config creates exporter', () {
        final exporter = OtlpGrpcSpanExporter();
        expect(exporter, isNotNull);
      });

      test('constructor with custom config (insecure=true)', () {
        final config = OtlpGrpcExporterConfig(insecure: true);
        final exporter = OtlpGrpcSpanExporter(config);
        expect(exporter, isNotNull);
      });

      test('constructor with custom config (insecure=false)', () {
        final config = OtlpGrpcExporterConfig(insecure: false);
        final exporter = OtlpGrpcSpanExporter(config);
        expect(exporter, isNotNull);
      });

      test('constructor with custom endpoint and headers', () {
        final config = OtlpGrpcExporterConfig(
          endpoint: 'collector.example.com:4317',
          headers: {'authorization': 'Bearer token'},
          insecure: true,
        );
        final exporter = OtlpGrpcSpanExporter(config);
        expect(exporter, isNotNull);
      });
    });

    group('shutdown', () {
      test('shutdown completes without error', () async {
        final exporter = OtlpGrpcSpanExporter(
          OtlpGrpcExporterConfig(insecure: true),
        );
        // Should complete without throwing
        await exporter.shutdown();
      });

      test('shutdown is idempotent - calling twice does not throw', () async {
        final exporter = OtlpGrpcSpanExporter(
          OtlpGrpcExporterConfig(insecure: true),
        );
        await exporter.shutdown();
        // Second call should return immediately without error
        await exporter.shutdown();
      });

      test('shutdown can be called multiple times safely', () async {
        final exporter = OtlpGrpcSpanExporter(
          OtlpGrpcExporterConfig(insecure: true),
        );
        await exporter.shutdown();
        await exporter.shutdown();
        await exporter.shutdown();
        // Should not throw on any call
      });
    });

    group('forceFlush', () {
      test('forceFlush after shutdown completes without error', () async {
        final exporter = OtlpGrpcSpanExporter(
          OtlpGrpcExporterConfig(insecure: true),
        );
        await exporter.shutdown();
        // forceFlush on a shutdown exporter should return immediately
        await exporter.forceFlush();
      });

      test('forceFlush before shutdown completes without error', () async {
        final exporter = OtlpGrpcSpanExporter(
          OtlpGrpcExporterConfig(insecure: true),
        );
        // forceFlush with no pending exports should complete
        await exporter.forceFlush();
        await exporter.shutdown();
      });
    });

    group('export', () {
      test('export after shutdown throws StateError', () async {
        final exporter = OtlpGrpcSpanExporter(
          OtlpGrpcExporterConfig(insecure: true),
        );
        await exporter.shutdown();

        // Create a test span
        final spanContext = OTel.spanContext(
          traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
          spanId: OTel.spanIdFrom('0011223344556677'),
        );
        final resource = OTel.resource(
          OTel.attributesFromMap({'service.name': 'test-service'}),
        );
        final instrumentationScope = OTel.instrumentationScope(
          name: 'test-tracer',
          version: '1.0.0',
        );
        final span = _TestSpan(
          name: 'test-span',
          spanContext: spanContext,
          resource: resource,
          instrumentationScope: instrumentationScope,
          kind: SpanKind.internal,
          attributes: OTel.attributes(),
          startTime: DateTime.now(),
        );

        expect(() => exporter.export([span]), throwsA(isA<StateError>()));
      });

      test('export with empty span list handles gracefully', () async {
        final exporter = OtlpGrpcSpanExporter(
          OtlpGrpcExporterConfig(insecure: true),
        );

        // Empty span list should return immediately without error
        await exporter.export([]);

        await exporter.shutdown();
      });
    });
  });
}

/// Minimal test span implementation for state management tests.
/// Only needs to satisfy the Span interface - no real span behavior required.
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
  final DateTime? endTime = null;

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
  });

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
  void recordException(
    Object exception, {
    StackTrace? stackTrace,
    Attributes? attributes,
    bool? escaped,
  }) {}

  @override
  void setStringAttribute<T>(String name, String value) {}
}
