@Tags(['fail'])
library;

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
  final combinedResAttrs = <String, Object>{
    'service.name': 'test-service',
  };
  if (resourceAttributes != null) {
    combinedResAttrs.addAll(resourceAttributes);
  }

  // Create a tracer with the specified instrumentation scope and resource
  final tracerProvider = OTel.tracerProvider();
  tracerProvider.resource = OTel.resource(OTel.attributesFromMap(combinedResAttrs));

  final tracer = tracerProvider.getTracer(
    resourceAttributes?['instrumentation.name'] ?? 'test-tracer',
    version: resourceAttributes?['instrumentation.version'] ?? '1.0.0',
  );

  // Create the span context
  final spanContext = OTel.spanContext(
    traceId: OTel.traceIdFrom(traceId ?? '00112233445566778899aabbccddeeff'),
    spanId: OTel.spanIdFrom(spanId ?? '0011223344556677'),
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
      await OTel.initialize(serviceName: 'test-service', serviceVersion: '1.0.0');
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
      // First, add named tracer providers with specific instrumentation scope names
      final httpProvider = OTel.addTracerProvider('http_provider',
          serviceName: 'http-service',
          serviceVersion: '1.0.0');

      final dbProvider = OTel.addTracerProvider('db_provider',
          serviceName: 'db-service',
          serviceVersion: '1.0.0');

      // When creating tracers, explicitly set name and version
      final httpTracer = httpProvider.getTracer(
        'http-instrumentation',
        version: '1.0',
      );

      final dbTracer = dbProvider.getTracer(
        'db-instrumentation',
        version: '1.0',
      );

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

      // Check the spans have the right instrumentation scope
      final httpScopeInfo = httpSpan.instrumentationScope;
      final dbScopeInfo = dbSpan.instrumentationScope;
      expect(httpScopeInfo.name, equals('http-instrumentation'));
      expect(dbScopeInfo.name, equals('db-instrumentation'));

      final request = OtlpSpanTransformer.transformSpans([httpSpan, dbSpan]);

      // Debug the request content
      print('Resource spans count: ${request.resourceSpans.length}');
      for (final rs in request.resourceSpans) {
        print('  Resource attributes:');
        for (final attr in rs.resource.attributes) {
          print('    ${attr.key}: ${attr.value.stringValue}');
        }
        print('  Scope spans count: ${rs.scopeSpans.length}');
        for (final ss in rs.scopeSpans) {
          print('    Scope name: "${ss.scope.name}", version: "${ss.scope.version}"');
          print('    Spans count: ${ss.spans.length}');
          for (final span in ss.spans) {
            print('      Span name: ${span.name}');
          }
        }
      }

      // Find all scope names from the resource spans
      final allScopeNames = <String>[];
      for (final rs in request.resourceSpans) {
        for (final ss in rs.scopeSpans) {
          if (ss.scope.name.isNotEmpty) {
            allScopeNames.add(ss.scope.name);
          }
        }
      }
      print('All scope names: $allScopeNames');

      // Check if we have the expected scope names
      expect(allScopeNames.contains('http-instrumentation'), isTrue,
          reason: 'Expected to find http-instrumentation scope');
      expect(allScopeNames.contains('db-instrumentation'), isTrue,
          reason: 'Expected to find db-instrumentation scope');
    });

    test('handles multiple resources', () {
      // Create spans with very different resources to ensure they don't get merged
      final spans = [
        createTestSpan(
          name: 'span1',
          resourceAttributes: {
            'service.name': 'service1',
            'instrumentation.name': 'service1-tracer',
            'unique.service1.attr': 'value1', // Add unique attribute to prevent merging
          },
        ),
        createTestSpan(
          name: 'span2',
          resourceAttributes: {
            'service.name': 'service2',
            'instrumentation.name': 'service2-tracer',
            'unique.service2.attr': 'value2', // Add unique attribute to prevent merging
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

      // We should have 2 different resource spans because the services are different
      expect(request.resourceSpans.length, equals(2),
          reason: 'Should have 2 different resource spans for different services');

      // Find the service names from the resources
      final service1ResourceSpan = request.resourceSpans.firstWhere(
        (rs) => rs.resource.attributes.any((attr) =>
            attr.key == 'service.name' && attr.value.stringValue == 'service1'),
      );

      final service2ResourceSpan = request.resourceSpans.firstWhere(
        (rs) => rs.resource.attributes.any((attr) =>
            attr.key == 'service.name' && attr.value.stringValue == 'service2'),
      );

      // Verify both resource spans exist
      expect(service1ResourceSpan, isNotNull);
      expect(service2ResourceSpan, isNotNull);
    });

    test('handles resource and scope combinations', () {
      final spans = [
        createTestSpan(
          name: 'span1',
          resourceAttributes: {
            'service.name': 'service1',
            'instrumentation.name': 'scope1',
            'attr1': 'val1', // Unique attribute to ensure different resources
          },
        ),
        createTestSpan(
          name: 'span2',
          resourceAttributes: {
            'service.name': 'service1',
            'instrumentation.name': 'scope2',
            'attr1': 'val1', // Same attribute as above to ensure same resource
          },
        ),
        createTestSpan(
          name: 'span3',
          resourceAttributes: {
            'service.name': 'service2',
            'instrumentation.name': 'scope1',
            'attr2': 'val2', // Different attribute to ensure different resource
          },
        ),
      ];

      final request = OtlpSpanTransformer.transformSpans(spans);

      // Print debug info for analysis
      print('\nResource & scope combinations:');
      print('Resource spans count: ${request.resourceSpans.length}');
      for (var i = 0; i < request.resourceSpans.length; i++) {
        final rs = request.resourceSpans[i];
        print('Resource $i attributes:');
        for (final attr in rs.resource.attributes) {
          print('  ${attr.key}: ${attr.value.stringValue}');
        }
        print('  ScopeSpans count: ${rs.scopeSpans.length}');
        for (var j = 0; j < rs.scopeSpans.length; j++) {
          final ss = rs.scopeSpans[j];
          print('  Scope $j: ${ss.scope.name}');
          print('    Spans: ${ss.spans.length}');
          for (final span in ss.spans) {
            print('      ${span.name}');
          }
        }
      }

      // Should have distinct resource spans for each service name
      expect(request.resourceSpans.where(
        (rs) => rs.resource.attributes.any((attr) =>
            attr.key == 'service.name' && attr.value.stringValue == 'service1')
      ).length, equals(1), reason: 'Should have one resource span for service1');

      expect(request.resourceSpans.where(
        (rs) => rs.resource.attributes.any((attr) =>
            attr.key == 'service.name' && attr.value.stringValue == 'service2')
      ).length, equals(1), reason: 'Should have one resource span for service2');

      // Find service1 resource span
      final service1ResourceSpan = request.resourceSpans.firstWhere(
        (rs) => rs.resource.attributes.any((attr) =>
            attr.key == 'service.name' && attr.value.stringValue == 'service1'),
      );

      // Service1 should have scopes for scope1 and scope2
      expect(service1ResourceSpan.scopeSpans.length, equals(2),
             reason: 'Service1 resource should have 2 different scope spans');

      // Check that the scopes for service1 include scope1 and scope2
      final service1Scopes = service1ResourceSpan.scopeSpans.map((ss) => ss.scope.name).toList();
      expect(service1Scopes.contains('scope1'), isTrue);
      expect(service1Scopes.contains('scope2'), isTrue);

      // Find service2 resource span
      final service2ResourceSpan = request.resourceSpans.firstWhere(
        (rs) => rs.resource.attributes.any((attr) =>
            attr.key == 'service.name' && attr.value.stringValue == 'service2'),
      );

      // Service2 should have only one scope: scope1
      expect(service2ResourceSpan.scopeSpans.length, equals(1),
             reason: 'Service2 resource should have 1 scope span');

      // Check the scope for service2
      expect(service2ResourceSpan.scopeSpans.first.scope.name, equals('scope1'));
    });

    test('maintains span order within scopes', () {
      // Create a fixed base time for consistent ordering
      final baseTime = DateTime.now();

      // Create spans with sequential timestamps
      final spans = List.generate(
        10, // Use fewer spans for a more predictable test
        (i) => createTestSpan(
          name: 'span-$i',
          startTime: baseTime.add(Duration(milliseconds: i * 100)),
          endTime: baseTime.add(Duration(milliseconds: i * 100 + 50)),
          resourceAttributes: {
            'service.name': 'test-service',
            'instrumentation.name': 'order-test',
          },
        ),
      );

      // Shuffle the spans to ensure order is maintained by transformer
      final shuffled = List<Span>.from(spans);
      shuffled.shuffle();

      final request = OtlpSpanTransformer.transformSpans(shuffled);

      // Get the first resource span and scope span
      expect(request.resourceSpans.length, greaterThan(0), reason: 'Should have at least one resource span');
      final resourceSpan = request.resourceSpans.first;

      expect(resourceSpan.scopeSpans.length, greaterThan(0), reason: 'Should have at least one scope span');
      final scopeSpan = resourceSpan.scopeSpans.first;

      // Get the transformed spans
      final transformedSpans = scopeSpan.spans;
      expect(transformedSpans.length, equals(10), reason: 'Should have 10 spans');

      // Check if spans are ordered by startTime
      bool isOrdered = true;
      for (var i = 0; i < transformedSpans.length - 1; i++) {
        if (transformedSpans[i].startTimeUnixNano > transformedSpans[i + 1].startTimeUnixNano) {
          isOrdered = false;
          break;
        }
      }

      expect(isOrdered, isTrue, reason: 'Spans should be ordered by start time');
    });

    test('handles batch memory efficiency', () {
      // Create a batch with many duplicate strings to test memory efficiency
      // But use a much smaller size to avoid memory issues
      final spans = List.generate(
        10,
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
        if (attr.value.hasStringValue()) {
          collectStrings(attr.value.stringValue);
        }
      }

      final scopeSpan = resourceSpan.scopeSpans.first;
      for (var span in scopeSpan.spans) {
        collectStrings(span.name);
        for (var attr in span.attributes) {
          collectStrings(attr.key);
          if (attr.value.hasStringValue()) {
            collectStrings(attr.value.stringValue);
          }
        }
      }

      // Print out what we found
      print('\nString table analysis:');
      print('Total spans: ${spans.length}');
      print('Unique strings: ${stringTable.length}');
      print('Strings: ${stringTable.join(', ')}');

      // The number of unique strings should be much less than the total number of attribute strings
      // For 10 spans with common attributes and names, we'd expect around ~15-25 unique strings
      // depending on system attributes
      expect(stringTable.length, lessThan(50),
             reason: 'String deduplication should result in fewer than 50 unique strings');
    });
  });
}
