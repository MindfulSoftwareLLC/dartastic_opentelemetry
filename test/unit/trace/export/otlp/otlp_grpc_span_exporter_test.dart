// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

// Mock span for testing OTLP transformation
class MockSpan implements Span {
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
  final Attributes attributes;
  
  @override
  final DateTime startTime;
  
  @override
  final DateTime? endTime;
  
  final Span? _parentSpan;
  bool _isEnded = false;
  SpanStatusCode _status = SpanStatusCode.Ok;
  String? _statusDescription;
  
  MockSpan({
    required this.name,
    required this.spanContext,
    required this.resource,
    required this.instrumentationScope,
    required this.kind,
    required this.attributes,
    required this.startTime,
    this.endTime,
    Span? parentSpan,
  }) : _parentSpan = parentSpan {
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
  SpanContext? get parentSpanContext => _parentSpan?.spanContext;

  @override
  Span? get parentSpan => _parentSpan;

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
  void addAttributes(Attributes attributes) {
    // TODO: implement addAttributes
  }

  @override
  void addEvents(Map<String, Attributes?> spanEvents) {
    // TODO: implement addEvents
  }

  @override
  void addSpanLink(SpanLink spanLink) {
    // TODO: implement addSpanLink
  }

  @override
  set attributes(Attributes newAttributes) {
    // TODO: implement attributes
  }

  @override
  bool isInstanceOf(Type type) {
    // TODO: implement isInstanceOf
    throw UnimplementedError();
  }

  @override
  // TODO: implement isValid
  bool get isValid => throw UnimplementedError();

  @override
  void setBoolListAttribute(String name, List<bool> value) {
    // TODO: implement setBoolListAttribute
  }

  @override
  void setDateTimeAsStringAttribute(String name, DateTime value) {
    // TODO: implement setDateTimeAsStringAttribute
  }

  @override
  void setDoubleListAttribute(String name, List<double> value) {
    // TODO: implement setDoubleListAttribute
  }

  @override
  void setIntListAttribute(String name, List<int> value) {
    // TODO: implement setIntListAttribute
  }

  @override
  void setStringListAttribute<T>(String name, List<String> value) {
    // TODO: implement setStringListAttribute
  }

  @override
  // TODO: implement spanId
  SpanId get spanId => throw UnimplementedError();

  @override
  void updateName(String name) {
    // TODO: implement updateName
  }

  @override
  void addEvent(SpanEvent spanEvent) {
    // TODO: implement addEvent
  }

  @override
  void recordException(Object exception, {StackTrace? stackTrace, Attributes? attributes, bool? escaped}) {
    // TODO: implement recordException
  }

  @override
  void setStringAttribute<T>(String name, String value) {
    // TODO: implement setStringAttribute
  }

  @override
  void addAttributeBool(String key, bool value) {
    // TODO: implement addAttributeBool
  }

  @override
  void addAttributeBoolList(String key, List<bool> value) {
    // TODO: implement addAttributeBoolList
  }

  @override
  void addAttributeDouble(String key, double value) {
    // TODO: implement addAttributeDouble
  }

  @override
  void addAttributeDoubleList(String key, List<double> value) {
    // TODO: implement addAttributeDoubleList
  }

  @override
  void addAttributeInt(String key, int value) {
    // TODO: implement addAttributeInt
  }

  @override
  void addAttributeIntList(String key, List<int> value) {
    // TODO: implement addAttributeIntList
  }

  @override
  void addAttributeString(String key, String value) {
    // TODO: implement addAttributeString
  }

  @override
  void addAttributeStringList(String key, List<String> value) {
    // TODO: implement addAttributeStringList
  }
}

// Helper function to create a test span
Span createTestSpan({
  required String name,
  String? traceId,
  String? spanId,
  Map<String, Object>? attributes,
  DateTime? startTime,
  DateTime? endTime,
  Span? parentSpan,
}) {
  final spanContext = OTel.spanContext(
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

  return MockSpan(
    name: name,
    spanContext: spanContext,
    resource: resource,
    instrumentationScope: instrumentationScope,
    kind: SpanKind.internal,
    attributes: attributes != null ? OTel.attributesFromMap(attributes) : OTel.attributes(),
    startTime: startTime ?? DateTime.now(),
    endTime: endTime,
    parentSpan: parentSpan,
  );
}

void main() {
  group('OtlpGrpcSpanExporter (Unit Tests)', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('creates proper OTLP export request from spans', () {
      final testSpan = createTestSpan(
        name: 'test-span',
        attributes: {
          'test.key': 'test.value',
          'test.number': 42,
        },
        traceId: '00112233445566778899aabbccddeeff',
        spanId: '0011223344556677',
      );

      // Test the span transformer directly (this is what the exporter uses internally)
      final request = OtlpSpanTransformer.transformSpans([testSpan]);

      // Verify the structure
      expect(request.resourceSpans, hasLength(1));
      
      final resourceSpan = request.resourceSpans.first;
      expect(resourceSpan.scopeSpans, hasLength(1));
      
      final scopeSpan = resourceSpan.scopeSpans.first;
      expect(scopeSpan.spans, hasLength(1));
      
      final protoSpan = scopeSpan.spans.first;
      expect(protoSpan.name, equals('test-span'));
      
      // Verify attributes
      final testKeyAttr = protoSpan.attributes.firstWhere((a) => a.key == 'test.key');
      expect(testKeyAttr.value.stringValue, equals('test.value'));
      
      final testNumberAttr = protoSpan.attributes.firstWhere((a) => a.key == 'test.number');
      expect(testNumberAttr.value.intValue.toInt(), equals(42));
    });

    test('handles empty span list', () {
      final request = OtlpSpanTransformer.transformSpans([]);
      expect(request.resourceSpans, isEmpty);
    });

    test('transforms multiple spans correctly', () {
      final spans = List.generate(
        3,
        (i) => createTestSpan(
          name: 'span-$i',
          attributes: {'index': i},
          traceId: '00112233445566778899aabbccddeeff',
          spanId: '00112233445566${i.toString().padLeft(2, '0')}',
        ),
      );

      final request = OtlpSpanTransformer.transformSpans(spans);

      expect(request.resourceSpans, hasLength(1));
      final resourceSpan = request.resourceSpans.first;
      expect(resourceSpan.scopeSpans, hasLength(1));
      final scopeSpan = resourceSpan.scopeSpans.first;
      expect(scopeSpan.spans, hasLength(3));

      // Verify each span
      for (var i = 0; i < 3; i++) {
        final protoSpan = scopeSpan.spans[i];
        expect(protoSpan.name, equals('span-$i'));
        
        final indexAttr = protoSpan.attributes.firstWhere((a) => a.key == 'index');
        expect(indexAttr.value.intValue.toInt(), equals(i));
      }
    });

    test('preserves span context information', () {
      const traceId = '00112233445566778899aabbccddeeff';
      const spanId = '0011223344556677';
      
      final testSpan = createTestSpan(
        name: 'context-test-span',
        traceId: traceId,
        spanId: spanId,
      );

      final request = OtlpSpanTransformer.transformSpans([testSpan]);
      final protoSpan = request.resourceSpans.first.scopeSpans.first.spans.first;

      // Verify trace and span IDs are preserved
      expect(protoSpan.traceId, isNotNull);
      expect(protoSpan.spanId, isNotNull);
      expect(protoSpan.traceId.length, equals(16)); // 16 bytes
      expect(protoSpan.spanId.length, equals(8));   // 8 bytes
    });

    test('includes resource information', () {
      final testSpan = createTestSpan(name: 'resource-test-span');
      final request = OtlpSpanTransformer.transformSpans([testSpan]);

      final resource = request.resourceSpans.first.resource;
      expect(resource.attributes, isNotEmpty);

      // Should have at least service.name
      final serviceNameAttr = resource.attributes.firstWhere(
        (a) => a.key == 'service.name',
        orElse: () => throw StateError('service.name attribute not found'),
      );
      expect(serviceNameAttr.value.stringValue, equals('test-service'));
    });

    test('includes instrumentation scope information', () {
      final testSpan = createTestSpan(name: 'scope-test-span');
      final request = OtlpSpanTransformer.transformSpans([testSpan]);

      final scope = request.resourceSpans.first.scopeSpans.first.scope;
      expect(scope.name, equals('test-tracer'));
      expect(scope.version, equals('1.0.0'));
    });

    test('handles spans with different attributes types', () {
      final testSpan = createTestSpan(
        name: 'multi-attr-span',
        attributes: {
          'string.attr': 'string.value',
          'int.attr': 123,
          'bool.attr': true,
          'double.attr': 45.67,
        },
      );

      final request = OtlpSpanTransformer.transformSpans([testSpan]);
      final protoSpan = request.resourceSpans.first.scopeSpans.first.spans.first;

      // Verify each attribute type
      final stringAttr = protoSpan.attributes.firstWhere((a) => a.key == 'string.attr');
      expect(stringAttr.value.stringValue, equals('string.value'));

      final intAttr = protoSpan.attributes.firstWhere((a) => a.key == 'int.attr');
      expect(intAttr.value.intValue.toInt(), equals(123));

      final boolAttr = protoSpan.attributes.firstWhere((a) => a.key == 'bool.attr');
      expect(boolAttr.value.boolValue, equals(true));

      final doubleAttr = protoSpan.attributes.firstWhere((a) => a.key == 'double.attr');
      expect(doubleAttr.value.doubleValue, equals(45.67));
    });

    test('handles span timing information', () {
      final startTime = DateTime.now();
      final endTime = startTime.add(const Duration(milliseconds: 100));
      
      final testSpan = createTestSpan(
        name: 'timing-test-span',
        startTime: startTime,
        endTime: endTime,
      );

      final request = OtlpSpanTransformer.transformSpans([testSpan]);
      final protoSpan = request.resourceSpans.first.scopeSpans.first.spans.first;

      expect(protoSpan.startTimeUnixNano.toInt(), greaterThan(0));
      expect(protoSpan.endTimeUnixNano.toInt(), greaterThan(protoSpan.startTimeUnixNano.toInt()));
    });

    test('groups spans by resource correctly', () {
      // Create spans with different resources
      final service1Resource = OTel.resource(OTel.attributesFromMap({
        'service.name': 'service1',
      }));

      final service2Resource = OTel.resource(OTel.attributesFromMap({
        'service.name': 'service2',
      }));

      final instrumentationScope = OTel.instrumentationScope(
        name: 'test-tracer',
        version: '1.0.0',
      );

      final spans = [
        MockSpan(
          name: 'span1',
          spanContext: OTel.spanContext(),
          resource: service1Resource,
          instrumentationScope: instrumentationScope,
          kind: SpanKind.internal,
          attributes: OTel.attributes(),
          startTime: DateTime.now(),
        ),
        MockSpan(
          name: 'span2',
          spanContext: OTel.spanContext(),
          resource: service2Resource,
          instrumentationScope: instrumentationScope,
          kind: SpanKind.internal,
          attributes: OTel.attributes(),
          startTime: DateTime.now(),
        ),
      ];

      final request = OtlpSpanTransformer.transformSpans(spans);

      // Should have 2 resource spans (one for each service)
      expect(request.resourceSpans, hasLength(2));

      // Verify each resource has its respective span
      final service1ResourceSpan = request.resourceSpans.firstWhere(
        (rs) => rs.resource.attributes.any(
          (attr) => attr.key == 'service.name' && attr.value.stringValue == 'service1',
        ),
      );

      final service2ResourceSpan = request.resourceSpans.firstWhere(
        (rs) => rs.resource.attributes.any(
          (attr) => attr.key == 'service.name' && attr.value.stringValue == 'service2',
        ),
      );

      expect(service1ResourceSpan.scopeSpans.first.spans.first.name, equals('span1'));
      expect(service2ResourceSpan.scopeSpans.first.spans.first.name, equals('span2'));
    });

    test('handles parent-child span relationships', () {
      // Create parent span
      final parentSpan = createTestSpan(
        name: 'parent-span',
        traceId: '00112233445566778899aabbccddeeff',
        spanId: '0011223344556677',
      );

      // Create child span with parent
      final childSpan = createTestSpan(
        name: 'child-span',
        traceId: '00112233445566778899aabbccddeeff', // Same trace
        spanId: '1122334455667788', // Different span ID
        parentSpan: parentSpan,
      );

      final request = OtlpSpanTransformer.transformSpans([parentSpan, childSpan]);
      final protoSpans = request.resourceSpans.first.scopeSpans.first.spans;

      // Find parent and child spans
      final parentProtoSpan = protoSpans.firstWhere((s) => s.name == 'parent-span');
      final childProtoSpan = protoSpans.firstWhere((s) => s.name == 'child-span');

      // Parent should not have parentSpanId
      expect(parentProtoSpan.hasParentSpanId(), isFalse);

      // Child should have parentSpanId set to parent's spanId
      expect(childProtoSpan.hasParentSpanId(), isTrue);
      expect(childProtoSpan.parentSpanId, equals(parentProtoSpan.spanId));

      // Both should have the same trace ID
      expect(childProtoSpan.traceId, equals(parentProtoSpan.traceId));
    });
  });
}
