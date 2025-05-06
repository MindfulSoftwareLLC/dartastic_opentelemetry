// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/proto/opentelemetry_proto_dart.dart' as proto;
import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/span_transformer.dart';
import 'package:dartastic_opentelemetry/src/trace/tracer.dart';
import 'package:dartastic_opentelemetry/src/trace/tracer_provider.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

String bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
}

void main() {
  TracerProvider? tracerProvider;
  Tracer? tracer;

  setUp(() async {
    await OTel.reset();
    await OTel.initialize(serviceName: 'test-service', serviceVersion: '1.0.0');
    tracerProvider = OTel.tracerProvider();
    tracer = tracerProvider!.getTracer('test');
  });

  group('OtlpSpanTransformer Advanced Features', () {
    test('transforms complex attributes', () {
      final span = tracer!.startSpan(
        'complex-attributes',
        attributes: OTel.attributesFromMap({
          'string_attr': 'value',
          'int_attr': 42,
          'double_attr': 3.14,
          'bool_attr': true,
          'string_array': ['value1', 'value2'],
          'int_array': [1, 2, 3],
          'double_array': [1.1, 2.2],
          'bool_array': [true, false],
        }),
      );

      final request = OtlpSpanTransformer.transformSpans([span]);
      final attrs =
          request.resourceSpans.first.scopeSpans.first.spans.first.attributes;
      final attributeMap =
          Map.fromEntries(attrs.map((a) => MapEntry(a.key, a.value)));

      expect(attributeMap['string_attr']?.stringValue, equals('value'));
      expect(attributeMap['int_attr']?.intValue, equals(Int64(42)));
      expect(attributeMap['double_attr']?.doubleValue, equals(3.14));
      expect(attributeMap['bool_attr']?.boolValue, equals(true));
      expect(attributeMap['string_array']?.arrayValue.values.length, equals(2));
      expect(attributeMap['int_array']?.arrayValue.values.length, equals(3));
      expect(attributeMap['double_array']?.arrayValue.values.length, equals(2));
      expect(attributeMap['bool_array']?.arrayValue.values.length, equals(2));
    });

    test('transforms span links with attributes', () {
      final linkedContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
        traceFlags: OTel.traceFlags(TraceFlags.SAMPLED_FLAG),
        traceState: OTel.traceState({}),
      );

      final span = tracer!.startSpan(
        'link-test',
        links: [
          OTel.spanLink(
            linkedContext,
            attributes: OTel.attributesFromMap({
              'link_attr': 'value',
              'array_attr': [1, 2, 3],
              'droppedAttributesCount': 2,
            }),
          ),
        ],
      );

      final request = OtlpSpanTransformer.transformSpans([span]);
      final links =
          request.resourceSpans.first.scopeSpans.first.spans.first.links;

      expect(links.length, equals(1));

      final link = links[0];
      expect(bytesToHex(link.spanId), equals(linkedContext.spanId.toString()));
      expect(bytesToHex(link.traceId), equals(linkedContext.traceId.toString()));

      final linkAttrs = Map.fromEntries(
        links[0].attributes.map((a) => MapEntry(a.key, a.value)),
      );
      expect(linkAttrs['link_attr']?.stringValue, equals('value'));

      // Verify array attribute
      final arrayAttr = linkAttrs['array_attr']?.arrayValue;
      expect(arrayAttr?.values.length, equals(3));
      expect(arrayAttr?.values[0].intValue, equals(Int64(1)));
      expect(arrayAttr?.values[1].intValue, equals(Int64(2)));
      expect(arrayAttr?.values[2].intValue, equals(Int64(3)));

    });

    test('handles span kind mapping', () {
      final kindMap = {
        SpanKind.internal: proto.Span_SpanKind.SPAN_KIND_INTERNAL,
        SpanKind.server: proto.Span_SpanKind.SPAN_KIND_SERVER,
        SpanKind.client: proto.Span_SpanKind.SPAN_KIND_CLIENT,
        SpanKind.producer: proto.Span_SpanKind.SPAN_KIND_PRODUCER,
        SpanKind.consumer: proto.Span_SpanKind.SPAN_KIND_CONSUMER,
      };

      for (final entry in kindMap.entries) {
        final span = tracer!.startSpan(
          'kind-test',
          kind: entry.key,
        );

        final request = OtlpSpanTransformer.transformSpans([span]);
        final protoSpan =
            request.resourceSpans.first.scopeSpans.first.spans.first;

        expect(protoSpan.kind, equals(entry.value));
      }
    });
  });
}
