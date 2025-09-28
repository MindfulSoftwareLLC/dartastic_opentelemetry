// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

void main() {
  group('Context Propagation', () {
    late TracerProvider tracerProvider;
    late Tracer tracer;
    late InMemorySpanExporter exporter;
    late SimpleSpanProcessor processor;

    setUp(() async {
      // Reset OTel completely
      await OTel.reset();

      // Initialize with a clean setup
      await OTel.initialize(
        serviceName: 'test-context-service',
        serviceVersion: '1.0.0',
      );

      tracerProvider = OTel.tracerProvider();

      // Create in-memory exporter and processor
      exporter = InMemorySpanExporter();
      processor = SimpleSpanProcessor(exporter);

      // Add the processor to capture spans
      tracerProvider.addSpanProcessor(processor);

      tracer = tracerProvider.getTracer('test-context-tracer');
    });

    tearDown(() async {
      await processor.shutdown();
      await exporter.shutdown();
      await tracerProvider.shutdown();
      await OTel.reset();
    });

    test('handles attributes across context boundaries', () async {
      // Clear any existing spans
      exporter.clear();

      final attributes = <String, Object>{
        'test.key': 'test-value',
        'test.number': 42,
        'test.boolean': true,
      }.toAttributes();

      final span = tracer.startSpan(
        'attributed-span-test',
        attributes: attributes,
      );

      // End the span to trigger export
      span.end();

      // Force export
      await processor.forceFlush();

      // Verify span was captured
      expect(exporter.spans, hasLength(1));

      final exportedSpan = exporter.spans.first;
      expect(exportedSpan.name, equals('attributed-span-test'));

      // Verify attributes
      final spanAttrs = exportedSpan.attributes;
      expect(spanAttrs.getString('test.key'), equals('test-value'));
      expect(spanAttrs.getInt('test.number'), equals(42));
      expect(spanAttrs.getBool('test.boolean'), equals(true));
    });

    test('propagates context between spans correctly using withSpan', () async {
      exporter.clear();

      final parentSpan = tracer.startSpan('parent-span-test');
      final parentContext = OTel.context().withSpan(parentSpan);

      final childSpan = tracer.startSpan(
        'child-span-test',
        context: parentContext,
      );

      // End spans in correct order
      childSpan.end();
      parentSpan.end();

      // Force export
      await processor.forceFlush();

      // Verify both spans were captured
      expect(exporter.spans, hasLength(2));
      expect(exporter.hasSpanWithName('parent-span-test'), isTrue);
      expect(exporter.hasSpanWithName('child-span-test'), isTrue);

      final parentExportedSpan = exporter.findSpanByName('parent-span-test')!;
      final childExportedSpan = exporter.findSpanByName('child-span-test')!;

      // Verify parent-child relationship
      expect(childExportedSpan.parentSpanContext, isNotNull);
      expect(
        childExportedSpan.parentSpanContext!.spanId,
        equals(parentExportedSpan.spanContext.spanId),
      );

      // Verify trace IDs match
      expect(
        childExportedSpan.spanContext.traceId,
        equals(parentExportedSpan.spanContext.traceId),
      );
    });

    test('withSpanContext prevents trace ID changes', () async {
      // Create first span with its own trace
      final span1 = tracer.startSpan('span1-test');
      final context1 = OTel.context().withSpan(span1);

      final newContext = OTel.context();
      final span2 = tracer.startSpan('span2-test', context: newContext);

      // This should throw because we're trying to change trace ID
      expect(
        () => context1.withSpanContext(span2.spanContext),
        throwsArgumentError,
        reason: 'Should not allow changing trace ID via withSpanContext',
      );

      // Clean up
      span1.end();
      span2.end();
    });

    test('allows withSpanContext for cross-process propagation', () async {
      // Create a span context with isRemote=true to simulate cross-process propagation
      final remoteTraceId = OTelAPI.traceId();
      final remoteSpanId = OTelAPI.spanId();
      final remoteContext = OTelAPI.spanContext(
        traceId: remoteTraceId,
        spanId: remoteSpanId,
        isRemote: true,
      );

      // This should work fine because we're starting a new trace
      final context = OTel.context().withSpanContext(remoteContext);

      // Create a child span
      final childSpan = tracer.startSpan(
        'remote-child-test',
        context: context,
      );

      // Verify the child inherited the remote trace ID
      expect(
        childSpan.spanContext.traceId,
        equals(remoteTraceId),
        reason: 'Child span should inherit remote trace ID',
      );

      childSpan.end();
    });

    test('context propagation with nested spans', () async {
      exporter.clear();

      // Create a root span
      final rootSpan = tracer.startSpan('root-span');
      final rootContext = OTel.context().withSpan(rootSpan);

      // Create a child span
      final childSpan = tracer.startSpan(
        'child-span',
        context: rootContext,
      );
      final childContext = OTel.context().withSpan(childSpan);

      // Create a grandchild span
      final grandchildSpan = tracer.startSpan(
        'grandchild-span',
        context: childContext,
      );

      // End all spans
      grandchildSpan.end();
      childSpan.end();
      rootSpan.end();

      await processor.forceFlush();

      // Verify all spans were captured
      expect(exporter.spans, hasLength(3));
      expect(exporter.spanNames,
          containsAll(['root-span', 'child-span', 'grandchild-span']));

      final rootExported = exporter.findSpanByName('root-span')!;
      final childExported = exporter.findSpanByName('child-span')!;
      final grandchildExported = exporter.findSpanByName('grandchild-span')!;

      // Verify trace IDs are all the same
      final traceId = rootExported.spanContext.traceId;
      expect(childExported.spanContext.traceId, equals(traceId));
      expect(grandchildExported.spanContext.traceId, equals(traceId));

      // Verify parent relationships
      expect(rootExported.parentSpanContext, isNull);
      expect(childExported.parentSpanContext!.spanId,
          equals(rootExported.spanContext.spanId));
      expect(grandchildExported.parentSpanContext!.spanId,
          equals(childExported.spanContext.spanId));
    });

    test('context attributes inheritance', () async {
      exporter.clear();

      // Create parent span with attributes
      final parentSpan = tracer.startSpan(
        'parent-with-attrs',
        attributes: {'parent.key': 'parent.value'}.toAttributes(),
      );
      final parentContext = OTel.context().withSpan(parentSpan);

      // Create child span with its own attributes
      final childSpan = tracer.startSpan(
        'child-with-attrs',
        context: parentContext,
        attributes: {'child.key': 'child.value'}.toAttributes(),
      );

      childSpan.end();
      parentSpan.end();

      await processor.forceFlush();

      expect(exporter.spans, hasLength(2));

      final parentExported = exporter.findSpanByName('parent-with-attrs')!;
      final childExported = exporter.findSpanByName('child-with-attrs')!;

      // Verify each span has its own attributes
      expect(parentExported.attributes.getString('parent.key'),
          equals('parent.value'));
      expect(childExported.attributes.getString('child.key'),
          equals('child.value'));

      // Verify child doesn't inherit parent's attributes (this is correct behavior)
      expect(childExported.attributes.getString('parent.key'), isNull);
    });

    test('context propagation across async boundaries', () async {
      exporter.clear();

      final parentSpan = tracer.startSpan('async-parent');
      final parentContext = OTel.context().withSpan(parentSpan);

      // Simulate async operation
      // ignore: inference_failure_on_instance_creation
      await Future.delayed(const Duration(milliseconds: 10));

      final childSpan = tracer.startSpan(
        'async-child',
        context: parentContext,
      );

      // End spans
      childSpan.end();
      parentSpan.end();

      await processor.forceFlush();

      expect(exporter.spans, hasLength(2));

      final parentExported = exporter.findSpanByName('async-parent')!;
      final childExported = exporter.findSpanByName('async-child')!;

      // Verify relationship maintained across async boundary
      expect(childExported.parentSpanContext!.spanId,
          equals(parentExported.spanContext.spanId));
      expect(childExported.spanContext.traceId,
          equals(parentExported.spanContext.traceId));
    });
  });
}
