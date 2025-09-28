// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/proto/opentelemetry_proto_dart.dart'
    as proto;
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/span_transformer.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

/// Convert bytes to hex string for easier comparison
String bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
}

// Helper function to create a test span using OTel factory methods
Span createTestSpan({
  required String name,
  String? traceId,
  String? spanId,
  Map<String, Object>? attributes,
  DateTime? startTime,
  DateTime? endTime,
  Map<String, String>? resourceAttributes,
  SpanStatusCode? statusCode,
  String? statusMessage,
  List<SpanEvent>? events,
  List<SpanLink>? links,
}) {
  final context = OTel.spanContext(
    traceId: OTel.traceIdFrom(traceId ?? '00112233445566778899aabbccddeeff'),
    spanId: OTel.spanIdFrom(spanId ?? '0011223344556677'),
  );

  final tracer = OTel.tracerProvider().getTracer(
    resourceAttributes?['instrumentation.name'] ?? 'test-tracer',
    version: resourceAttributes?['instrumentation.version'] ?? '1.0.0',
  );

  final span = tracer.createSpan(
    name: name,
    startTime: startTime ?? DateTime.now(),
    kind: SpanKind.internal,
    attributes: attributes != null ? OTel.attributesFromMap(attributes) : null,
    spanContext: context,
  );

  if (statusCode != null) {
    span.setStatus(statusCode, statusMessage);
  }

  if (events != null) {
    for (var event in events) {
      span.addEvent(event);
    }
  }

  if (links != null) {
    for (var link in links) {
      span.addSpanLink(link);
    }
  }

  if (endTime != null) {
    span.end(endTime: endTime);
  } else if (startTime != null) {
    // If we have a start time but no end time, use start + 1s
    span.end(endTime: startTime.add(const Duration(seconds: 1)));
  }

  return span;
}

void main() {
  setUp(() async {
    await OTel.reset();
    await OTel.initialize(serviceName: 'test-service', serviceVersion: '1.0.0');
  });

  group('OtlpSpanTransformer', () {
    test('transforms basic span correctly', () {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
          1640995200000); // 2022-01-01 00:00:00 UTC
      final span = createTestSpan(
        name: 'test-span',
        startTime: timestamp,
        endTime: timestamp.add(const Duration(seconds: 1)),
        attributes: {
          'key': 'value',
        },
        traceId: '00112233445566778899aabbccddeeff',
        spanId: '0011223344556677',
      );

      final request = OtlpSpanTransformer.transformSpans([span]);
      final protoSpan =
          request.resourceSpans.first.scopeSpans.first.spans.first;

      expect(protoSpan.name, equals('test-span'));
      expect(
        protoSpan.startTimeUnixNano.toInt(),
        equals(timestamp.microsecondsSinceEpoch * 1000),
      );
      expect(
        protoSpan.endTimeUnixNano.toInt(),
        equals(
            timestamp.add(const Duration(seconds: 1)).microsecondsSinceEpoch *
                1000),
      );

      final attribute = protoSpan.attributes.first;
      expect(attribute.key, equals('key'));
      expect(attribute.value.stringValue, equals('value'));
    });

    test('transforms status correctly', () {
      final span = createTestSpan(
        name: 'status-test',
        statusCode: SpanStatusCode.Error,
        statusMessage: 'Error message',
        traceId: '00112233445566778899aabbccddeeff',
        spanId: '0011223344556677',
      );

      final request = OtlpSpanTransformer.transformSpans([span]);
      final status =
          request.resourceSpans.first.scopeSpans.first.spans.first.status;

      expect(status.code, equals(proto.Status_StatusCode.STATUS_CODE_ERROR));
      expect(status.message, equals('Error message'));
    });

    test('handles empty span list', () {
      final request = OtlpSpanTransformer.transformSpans([]);
      expect(request.resourceSpans, isEmpty);
    });

    test('transforms span events correctly', () {
      final startTime = DateTime.fromMillisecondsSinceEpoch(
          1640995200000); // 2022-01-01 00:00:00 UTC
      final eventTime = startTime.add(const Duration(milliseconds: 100));

      final span = createTestSpan(
        name: 'event-test',
        startTime: startTime,
        events: [
          OTel.spanEvent(
            'test-event',
            OTel.attributesFromMap({'event_key': 'event_value'}),
            eventTime,
          ),
        ],
        traceId: '00112233445566778899aabbccddeeff',
        spanId: '0011223344556677',
      );

      final request = OtlpSpanTransformer.transformSpans([span]);
      final events =
          request.resourceSpans.first.scopeSpans.first.spans.first.events;

      expect(events, hasLength(1));
      final event = events.first;
      expect(event.name, equals('test-event'));
      expect(event.timeUnixNano.toInt(),
          equals(eventTime.microsecondsSinceEpoch * 1000));
      expect(event.attributes.first.key, equals('event_key'));
      expect(event.attributes.first.value.stringValue, equals('event_value'));
    });

    test('transforms span links correctly', () {
      final linkedContext = OTel.spanContext(
        traceId: OTel.traceIdFrom('ea2a896d85d8fd9373e092ece8cff414'),
        spanId: OTel.spanIdFrom(
            '85d8fd937373e092'), // Must be 16 hex characters (8 bytes)
      );

      final span = createTestSpan(
        name: 'link-test',
        links: [
          OTel.spanLink(linkedContext,
              attributes: OTel.attributesFromMap({'link.key': 'link.value'})),
        ],
        traceId: '00112233445566778899aabbccddeeff',
        spanId: '0011223344556677',
      );

      final request = OtlpSpanTransformer.transformSpans([span]);
      final links =
          request.resourceSpans.first.scopeSpans.first.spans.first.links;

      expect(links, hasLength(1));
      final link = links.first;
      expect(
          bytesToHex(link.traceId), equals('ea2a896d85d8fd9373e092ece8cff414'));
      expect(bytesToHex(link.spanId), equals('85d8fd937373e092'));
      expect(link.attributes, hasLength(1));
      expect(link.attributes.first.key, equals('link.key'));
      expect(link.attributes.first.value.stringValue, equals('link.value'));
    });
  });
}
