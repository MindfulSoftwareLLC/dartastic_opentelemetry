// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

void main() {
  group('Span Lifecycle', () {
    late TracerProvider tracerProvider;
    late Tracer tracer;
    late InMemorySpanExporter exporter;
    late SimpleSpanProcessor processor;

    setUp(() async {
      // Reset OTel completely
      await OTel.reset();

      // Initialize with a clean setup
      await OTel.initialize(
        serviceName: 'test-lifecycle-service',
        serviceVersion: '1.0.0',
      );

      tracerProvider = OTel.tracerProvider();
      
      // Create in-memory exporter and processor
      exporter = InMemorySpanExporter();
      processor = SimpleSpanProcessor(exporter);
      
      // Add the processor to capture spans
      tracerProvider.addSpanProcessor(processor);
      
      tracer = tracerProvider.getTracer('test-lifecycle-tracer');
    });

    tearDown(() async {
      await processor.shutdown();
      await exporter.shutdown();
      await tracerProvider.shutdown();
      await OTel.reset();
    });

    test('span should support setting attributes', () async {
      // Clear any existing spans
      exporter.clear();

      // Create attributes using the Map extension
      final attributes = <String, Object>{
        'test.key': 'test.value',
        'test.number': 42,
        'test.boolean': true,
        'test.double': 3.14,
      }.toAttributes();

      final span = tracer.startSpan(
        'direct-test-span', 
        attributes: attributes,
      );

      span.end();

      // Force export
      await processor.forceFlush();

      // Verify span was captured
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('direct-test-span'), isTrue);
      
      final exportedSpan = exporter.findSpanByName('direct-test-span')!;
      
      // Verify attributes
      final spanAttrs = exportedSpan.attributes;
      expect(spanAttrs.getString('test.key'), equals('test.value'));
      expect(spanAttrs.getInt('test.number'), equals(42));
      expect(spanAttrs.getBool('test.boolean'), equals(true));
      expect(spanAttrs.getDouble('test.double'), equals(3.14));
    });

    test('span status should be properly set and retrieved', () async {
      exporter.clear();

      final statusCode = SpanStatusCode.Error;
      final statusDescription = 'Something went wrong';
      
      final span = tracer.startSpan('status-test-span');
      span.setStatus(statusCode, statusDescription);
      span.end();

      // Force export
      await processor.forceFlush();

      // Verify span was captured
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('status-test-span'), isTrue);
      
      final exportedSpan = exporter.findSpanByName('status-test-span')!;
      expect(exportedSpan.status, equals(SpanStatusCode.Error));
      expect(exportedSpan.statusDescription, equals(statusDescription));
    });

    test('span should record events', () async {
      exporter.clear();

      final span = tracer.startSpan('event-test-span');
      
      // Add events
      span.addEventNow('event1');
      span.addEventNow('event2', {'event.key': 'event.value'}.toAttributes());
      
      span.end();

      // Force export
      await processor.forceFlush();

      // Verify span was captured
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('event-test-span'), isTrue);
      
      final exportedSpan = exporter.findSpanByName('event-test-span')!;
      
      // Verify events
      final events = exportedSpan.spanEvents;
      expect(events, isNotNull);
      expect(events!.length, equals(2));
      expect(events[0].name, equals('event1'));
      expect(events[1].name, equals('event2'));
      expect(events[1].attributes!.getString('event.key'), equals('event.value'));
    });

    test('span should record exceptions', () async {
      exporter.clear();

      final span = tracer.startSpan('exception-test-span');
      
      try {
        throw Exception('Test exception');
      } catch (e, stackTrace) {
        span.recordException(e, stackTrace: stackTrace);
      }
      
      span.end();

      // Force export
      await processor.forceFlush();

      // Verify span was captured
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('exception-test-span'), isTrue);
      
      final exportedSpan = exporter.findSpanByName('exception-test-span')!;
      
      // Verify exception was recorded as an event
      final events = exportedSpan.spanEvents;
      expect(events, isNotNull);
      expect(events!.length, equals(1));
      expect(events[0].name, equals('exception'));
      expect(events[0].attributes!.getString('exception.type'), contains('Exception'));
      expect(events[0].attributes!.getString('exception.message'), contains('Test exception'));
    });

    test('span should support adding links', () async {
      exporter.clear();

      // Create a span context to link to
      final linkContext = OTel.spanContext(
        traceId: OTel.traceId(),
        spanId: OTel.spanId(),
      );

      final span = tracer.startSpan('link-test-span');
      span.addLink(linkContext, {'link.key': 'link.value'}.toAttributes());
      span.end();

      // Force export
      await processor.forceFlush();

      // Verify span was captured
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('link-test-span'), isTrue);
      
      final exportedSpan = exporter.findSpanByName('link-test-span')!;
      
      // Verify links
      final links = exportedSpan.spanLinks;
      expect(links, isNotNull);
      expect(links!.length, equals(1));
      expect(links[0].spanContext, equals(linkContext));
      expect(links[0].attributes.getString('link.key'), equals('link.value'));
    });

    test('span should track timing correctly', () async {
      exporter.clear();

      final startTime = DateTime.now();
      final span = tracer.startSpan('timing-test-span');
      
      // Add a small delay
      // ignore: inference_failure_on_instance_creation
      await Future.delayed(const Duration(milliseconds: 100));
      
      span.end();
      final endTime = DateTime.now();

      // Force export
      await processor.forceFlush();

      // Verify span was captured
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('timing-test-span'), isTrue);
      
      final exportedSpan = exporter.findSpanByName('timing-test-span')!;
      
      // Verify timing
      expect(exportedSpan.startTime, isNotNull);
      expect(exportedSpan.endTime, isNotNull);
      expect(exportedSpan.startTime.isAfter(startTime.subtract(const Duration(seconds: 1))), isTrue);
      expect(exportedSpan.endTime!.isBefore(endTime.add(const Duration(seconds: 1))), isTrue);
      expect(exportedSpan.endTime!.isAfter(exportedSpan.startTime), isTrue);
    });

    test('span should be properly ended', () async {
      exporter.clear();

      final span = tracer.startSpan('end-test-span');
      
      // Initially not ended
      expect(span.isEnded, isFalse);
      
      span.end();
      
      // Now should be ended
      expect(span.isEnded, isTrue);

      // Force export
      await processor.forceFlush();

      // Verify span was captured
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('end-test-span'), isTrue);
      
      final exportedSpan = exporter.findSpanByName('end-test-span')!;
      expect(exportedSpan.isEnded, isTrue);
    });

    test('span should support multiple attribute types', () async {
      exporter.clear();

      final span = tracer.startSpan('multi-attr-test-span');
      
      // Set different types of attributes
      span.setStringAttribute<String>('string.attr', 'string.value');
      span.setIntAttribute('int.attr', 123);
      span.setBoolAttribute('bool.attr', true);
      span.setDoubleAttribute('double.attr', 45.67);
      
      span.end();

      // Force export
      await processor.forceFlush();

      // Verify span was captured
      expect(exporter.spans, hasLength(1));
      expect(exporter.hasSpanWithName('multi-attr-test-span'), isTrue);
      
      final exportedSpan = exporter.findSpanByName('multi-attr-test-span')!;
      
      // Verify all attribute types
      final attrs = exportedSpan.attributes;
      expect(attrs.getString('string.attr'), equals('string.value'));
      expect(attrs.getInt('int.attr'), equals(123));
      expect(attrs.getBool('bool.attr'), equals(true));
      expect(attrs.getDouble('double.attr'), equals(45.67));
    });
  });
}
