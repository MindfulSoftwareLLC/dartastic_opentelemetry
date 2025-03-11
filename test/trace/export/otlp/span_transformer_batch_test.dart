// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

// Helper function to create a test span using OTel factory methods
Span createTestSpan({
  required String name,
  String? traceId,
  String? spanId,
  Map<String, Object>? attributes,
  DateTime? startTime,
  DateTime? endTime,
  Map<String, String>? resourceAttributes,
}) {
  final combinedResAttrs = <String, String>{
    'service.name': 'test-service',
  };
  if (resourceAttributes != null) {
    combinedResAttrs.addAll(resourceAttributes);
  }

  final spanContext = OTel.spanContext(
    traceId: OTel.traceIdFrom(traceId ?? '00112233445566778899aabbccddeeff'),
    spanId: OTel.spanIdFrom(spanId ?? '0011223344556677'),
  );

  final tracer = OTel.tracerProvider().getTracer(
    resourceAttributes?['instrumentation.name'] ?? 'test-tracer',
    version: resourceAttributes?['instrumentation.version'] ?? '1.0.0',
  );

  final span = tracer.createSpan(
    name: name,
    spanContext: spanContext,
    kind: SpanKind.internal,
    attributes: attributes != null ? OTel.attributesFromMap(attributes) : null,
    startTime: startTime,
  );

  if (endTime != null) {
    span.end(endTime: endTime);
  }

  return span;
}

void main() {
  group('OtlpSpanTransformer Batch Processing', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize();
    });

    test('handles large batch of simple spans', () {
      // Verify we're creating SDK spans with resources
      final testSpan = createTestSpan(name: 'test-span');
      expect(testSpan, isA<Span>());
      expect(testSpan.resource, isNotNull);
      final spans = List.generate(
        1000,
        (i) => createTestSpan(
          name: 'span-$i',
          attributes: {
            'index': '$i',
          },
        ),
      );

      final request = OtlpSpanTransformer.transformSpans(spans);
      final protoSpans = request.resourceSpans.first.scopeSpans.first.spans;

      expect(protoSpans.length, equals(1000));
      for (var i = 0; i < 1000; i++) {
        final span = protoSpans[i];
        expect(span.name, equals('span-$i'));
        expect(
          span.attributes.firstWhere((a) => a.key == 'index').value.stringValue,
          equals('$i'),
        );
      }
    });

    test('optimizes resource sharing in batch', () {
      final sharedResourceAttrs = {
        'service.name': 'test-service',
        'service.version': '1.0.0',
        'deployment.environment': 'test',
      };

      final spans = List.generate(
        100,
        (i) => createTestSpan(
          name: 'span-$i',
          resourceAttributes: sharedResourceAttrs,
        ),
      );

      final request = OtlpSpanTransformer.transformSpans(spans);

      // Should only have one ResourceSpans since all spans share the same resource
      expect(request.resourceSpans.length, equals(1));
      final resource = request.resourceSpans.first.resource;

      // Verify resource attributes are correctly shared
      final resourceAttrs = Map.fromEntries(
        resource.attributes.map((a) => MapEntry(a.key, a.value.stringValue)),
      );
      expect(resourceAttrs['service.name'], equals('test-service'));
      expect(resourceAttrs['service.version'], equals('1.0.0'));
      expect(resourceAttrs['deployment.environment'], equals('test'));
    });

    test('handles multiple instrumentation scopes', () {
      // First, add named tracer providers with specific instrumentation scopes
      final httpProvider = OTel.addTracerProvider('http_provider',
          serviceName: 'http',
          serviceVersion: '1.0.0');

      final dbProvider = OTel.addTracerProvider('db_provider',
          serviceName: 'database',
          serviceVersion: '1.0.0');

      final httpTracer = httpProvider.getTracer('http');
      final dbTracer = dbProvider.getTracer('database');

      // Create spans in a parent-child relationship
      final httpSpan = httpTracer.startSpan(
        'http-span',
        kind: SpanKind.server,
      );

      final dbSpan = dbTracer.startSpan(
        'db-span',
        kind: SpanKind.client,
        context: OTel.context().withSpanContext(httpSpan.spanContext),
      );

      // End spans in reverse order
      dbSpan.end();
      httpSpan.end();

      final request = OtlpSpanTransformer.transformSpans([httpSpan, dbSpan]);

      // Should have one ResourceSpans with multiple ScopeSpans
      expect(request.resourceSpans.length, equals(1));
      final scopeSpans = request.resourceSpans.first.scopeSpans;
      expect(scopeSpans.length, equals(2));

      final scopeNames = scopeSpans.map((s) => s.scope.name).toList();
      print('Found scope names: $scopeNames');
      expect(scopeNames, containsAll(['http', 'database']));
    });

    test('handles multiple resources', () {
      final spans = [
        createTestSpan(
          name: 'span1',
          resourceAttributes: {
            'service.name': 'service1',
            'instrumentation.name': 'service1-tracer',
          },
        ),
        createTestSpan(
          name: 'span2',
          resourceAttributes: {
            'service.name': 'service2',
            'instrumentation.name': 'service2-tracer',
          },
        ),
      ];

      final request = OtlpSpanTransformer.transformSpans(spans);

      // Debug output
      print('Found ${request.resourceSpans.length} resource spans');
      for (final rs in request.resourceSpans) {
        print('Resource attributes:');
        for (final attr in rs.resource.attributes) {
          print('  ${attr.key}: ${attr.value.stringValue}');
        }
      }

      expect(request.resourceSpans.length, equals(2));

      final serviceNames = request.resourceSpans
          .map((rs) => rs.resource.attributes.first.value.stringValue)
          .toList();
      expect(serviceNames, containsAll(['service1', 'service2']));
    });

    test('handles resource and scope combinations', () {
      final spans = [
        createTestSpan(
          name: 'span1',
          resourceAttributes: {
            'service.name': 'service1',
            'instrumentation.name': 'scope1'
          },
        ),
        createTestSpan(
          name: 'span2',
          resourceAttributes: {
            'service.name': 'service1',
            'instrumentation.name': 'scope2'
          },
        ),
        createTestSpan(
          name: 'span3',
          resourceAttributes: {
            'service.name': 'service2',
            'instrumentation.name': 'scope1'
          },
        ),
      ];

      final request = OtlpSpanTransformer.transformSpans(spans);

      // Should have 2 ResourceSpans (one per service)
      expect(request.resourceSpans.length, equals(2));

      // Service1 should have 2 ScopeSpans
      final service1ResourceSpans = request.resourceSpans.firstWhere(
        (rs) => rs.resource.attributes.first.value.stringValue == 'service1',
      );
      expect(service1ResourceSpans.scopeSpans.length, equals(2));

      // Service2 should have 1 ScopeSpans
      final service2ResourceSpans = request.resourceSpans.firstWhere(
        (rs) => rs.resource.attributes.first.value.stringValue == 'service2',
      );
      expect(service2ResourceSpans.scopeSpans.length, equals(1));
    });

    test('maintains span order within scopes', () {
      final spans = List.generate(
        100,
        (i) => createTestSpan(
          name: 'span-$i',
          startTime: DateTime.now().add(Duration(milliseconds: i)),
        ),
      );

      // Shuffle the spans to ensure order is maintained by transformer
      spans.shuffle();

      final request = OtlpSpanTransformer.transformSpans(spans);
      final transformedSpans =
          request.resourceSpans.first.scopeSpans.first.spans;

      for (var i = 0; i < transformedSpans.length - 1; i++) {
        expect(
          transformedSpans[i].startTimeUnixNano <=
              transformedSpans[i + 1].startTimeUnixNano,
          isTrue,
          reason: 'Spans should be ordered by start time',
        );
      }
    });

    test('handles batch memory efficiency', () {
      // Create a batch with many duplicate strings to test memory efficiency
      final spans = List.generate(
        1000,
        (i) => createTestSpan(
          name: 'common-span-name',
          attributes: {
            'common-key': 'common-value',
            'index': '$i',
          },
          resourceAttributes: {
            'service.name': 'test-service',
            'common.attribute': 'shared-value',
          },
        ),
      );

      final request = OtlpSpanTransformer.transformSpans(spans);

      // Check that common strings are shared in the protobuf output
      final stringTable = <String>{};

      void collectStrings(String str) {
        stringTable.add(str);
      }

      // Collect all strings from the transformed request
      final resourceSpan = request.resourceSpans.first;
      for (var attr in resourceSpan.resource.attributes) {
        collectStrings(attr.key);
        collectStrings(attr.value.stringValue);
      }

      final scopeSpan = resourceSpan.scopeSpans.first;
      for (var span in scopeSpan.spans) {
        collectStrings(span.name);
        for (var attr in span.attributes) {
          collectStrings(attr.key);
          collectStrings(attr.value.stringValue);
        }
      }

      // The number of unique strings should be much less than the total number of strings
      expect(stringTable.length, lessThan(100));
    });
  });
}
