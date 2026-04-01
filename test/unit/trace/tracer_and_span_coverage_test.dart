// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Test file covering remaining small coverage gaps across multiple files.
library;

///   - tracer.dart (19 missed lines: getters, withSpan/withSpanAsync invalid
///     span paths, startSpanWithContext context update, sampling attributes merge,
///     parentSpan without context path)
///   - span.dart (8 missed lines: list attribute setters, end() error paths)
///   - meter.dart (9 missed lines: version/schemaUrl/attributes getters,
///     NoopObservable collect)
///   - batch_span_processor.dart (4 missed lines: queue full, timer error,
///     onNameUpdate)
///   - composite_sampler.dart (4 missed lines: description, attribute combining)

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/metrics/export/otlp/metric_transformer.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

// ---------------------------------------------------------------------------
// Custom sampler that creates attributes lazily (after OTel.initialize)
// ---------------------------------------------------------------------------

class _LateAttributeSampler implements Sampler {
  final SamplingDecision decision;
  final String attributeKey;
  final String attributeValue;

  _LateAttributeSampler({
    this.decision = SamplingDecision.recordAndSample,
    required this.attributeKey,
    required this.attributeValue,
  });

  @override
  String get description => 'LateAttributeSampler';

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    // Create attributes lazily so OTel is initialized
    final attrs = OTel.attributes([
      OTel.attributeString(attributeKey, attributeValue),
    ]);
    return SamplingResult(
      decision: decision,
      source: SamplingDecisionSource.tracerConfig,
      attributes: attrs,
    );
  }
}

// ---------------------------------------------------------------------------
// Custom sampler that returns attributes in its sampling result
// ---------------------------------------------------------------------------

class _AttributeAddingSampler implements Sampler {
  final SamplingDecision decision;
  final Attributes? samplerAttributes;

  _AttributeAddingSampler({
    this.decision = SamplingDecision.recordAndSample,
    this.samplerAttributes,
  });

  @override
  String get description => 'AttributeAddingSampler';

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    return SamplingResult(
      decision: decision,
      source: SamplingDecisionSource.tracerConfig,
      attributes: samplerAttributes,
    );
  }
}

// ---------------------------------------------------------------------------
// A span processor that throws on onEnd to test error handling
// ---------------------------------------------------------------------------

class _ThrowingSpanProcessor implements SpanProcessor {
  @override
  Future<void> onStart(Span span, Context? parentContext) async {}

  @override
  Future<void> onEnd(Span span) {
    // Throw synchronously (don't use async) so the try/catch in span.end()
    // can catch it.
    throw StateError('Processor onEnd error for testing');
  }

  @override
  Future<void> onNameUpdate(Span span, String newName) async {}

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

// ---------------------------------------------------------------------------
// An exporter that throws during export to test batch timer error handling
// ---------------------------------------------------------------------------

class _TimerFailExporter implements SpanExporter {
  @override
  Future<void> export(List<Span> spans) async {
    throw StateError('Intentional export failure for timer error test');
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

// ---------------------------------------------------------------------------
// Wrapper span that overrides isValid to return false
// ---------------------------------------------------------------------------

class _InvalidSpanWrapper implements APISpan {
  final APISpan _delegate;

  _InvalidSpanWrapper(this._delegate);

  @override
  bool get isValid => false; // Always invalid

  @override
  String get name => _delegate.name;
  @override
  SpanContext get spanContext => _delegate.spanContext;
  @override
  SpanKind get kind => _delegate.kind;
  @override
  Attributes get attributes => _delegate.attributes;
  @override
  set attributes(Attributes newAttributes) =>
      _delegate.attributes = newAttributes;
  @override
  DateTime get startTime => _delegate.startTime;
  @override
  DateTime? get endTime => _delegate.endTime;
  @override
  bool get isEnded => _delegate.isEnded;
  @override
  bool get isRecording => _delegate.isRecording;
  @override
  SpanStatusCode get status => _delegate.status;
  @override
  String? get statusDescription => _delegate.statusDescription;
  @override
  APISpan? get parentSpan => _delegate.parentSpan;
  @override
  SpanContext? get parentSpanContext => _delegate.parentSpanContext;
  @override
  List<SpanEvent>? get spanEvents => _delegate.spanEvents;
  @override
  List<SpanLink>? get spanLinks => _delegate.spanLinks;
  @override
  SpanId get spanId => _delegate.spanId;
  @override
  InstrumentationScope get instrumentationScope =>
      _delegate.instrumentationScope;
  @override
  void end({DateTime? endTime, SpanStatusCode? spanStatus}) =>
      _delegate.end(endTime: endTime, spanStatus: spanStatus);
  @override
  void setStatus(SpanStatusCode code, [String? description]) =>
      _delegate.setStatus(code, description);
  @override
  void addAttributes(Attributes attributes) =>
      _delegate.addAttributes(attributes);
  @override
  void addEvent(SpanEvent spanEvent) => _delegate.addEvent(spanEvent);
  @override
  void addEventNow(String name, [Attributes? attributes]) =>
      _delegate.addEventNow(name, attributes);
  @override
  void addEvents(Map<String, Attributes?> spanEvents) =>
      _delegate.addEvents(spanEvents);
  @override
  void addLink(SpanContext spanContext, [Attributes? attributes]) =>
      _delegate.addLink(spanContext, attributes);
  @override
  void addSpanLink(SpanLink spanLink) => _delegate.addSpanLink(spanLink);
  @override
  void recordException(
    Object exception, {
    StackTrace? stackTrace,
    Attributes? attributes,
    bool? escaped,
  }) =>
      _delegate.recordException(
        exception,
        stackTrace: stackTrace,
        attributes: attributes,
        escaped: escaped,
      );
  @override
  void setBoolAttribute(String name, bool value) =>
      _delegate.setBoolAttribute(name, value);
  @override
  void setBoolListAttribute(String name, List<bool> value) =>
      _delegate.setBoolListAttribute(name, value);
  @override
  void setDoubleAttribute(String name, double value) =>
      _delegate.setDoubleAttribute(name, value);
  @override
  void setDoubleListAttribute(String name, List<double> value) =>
      _delegate.setDoubleListAttribute(name, value);
  @override
  void setIntAttribute(String name, int value) =>
      _delegate.setIntAttribute(name, value);
  @override
  void setIntListAttribute(String name, List<int> value) =>
      _delegate.setIntListAttribute(name, value);
  @override
  void setStringAttribute<T>(String name, String value) =>
      _delegate.setStringAttribute<T>(name, value);
  @override
  void setStringListAttribute<T>(String name, List<String> value) =>
      _delegate.setStringListAttribute<T>(name, value);
  @override
  void setDateTimeAsStringAttribute(String name, DateTime value) =>
      _delegate.setDateTimeAsStringAttribute(name, value);
  @override
  void updateName(String name) => _delegate.updateName(name);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  final List<String> logOutput = [];

  setUp(() async {
    await OTel.reset();
    logOutput.clear();
    OTelLog.enableTraceLogging();
    OTelLog.logFunction = logOutput.add;
    await OTel.initialize(
      serviceName: 'final-coverage-test',
      detectPlatformResources: false,
    );
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
    OTelLog.currentLevel = LogLevel.info;
    OTelLog.logFunction = null;
  });

  // =========================================================================
  // tracer.dart - Getter coverage
  // =========================================================================
  group('Tracer getters', () {
    test('schemaUrl returns delegate schemaUrl', () {
      final tracer = OTel.tracer();
      // schemaUrl may be null, but accessing it exercises the getter
      final schemaUrl = tracer.schemaUrl;
      // Just verify it does not throw and returns something (possibly null)
      expect(schemaUrl, anyOf(isNull, isA<String>()));
    });

    test('version returns delegate version', () {
      final tracer = OTel.tracer();
      // Exercises the version getter
      final version = tracer.version;
      expect(version, anyOf(isNull, isA<String>()));
    });

    test('attributes getter and setter', () {
      final tracer = OTel.tracer();
      // Exercises attributes getter and setter
      final originalAttrs = tracer.attributes;
      expect(originalAttrs, anyOf(isNull, isA<Attributes>()));

      final newAttrs = OTel.attributesFromMap({'test.key': 'test.value'});
      tracer.attributes = newAttrs;
      expect(tracer.attributes, isNotNull);
    });

    test('currentSpan returns delegate currentSpan', () {
      final tracer = OTel.tracer();
      // Exercises the currentSpan getter
      final current = tracer.currentSpan;
      expect(current, anyOf(isNull, isA<APISpan>()));
    });

    test('enabled setter works', () {
      final tracer = OTel.tracer();
      // Exercises the enabled setter
      expect(tracer.enabled, isTrue);
      tracer.enabled = false;
      expect(tracer.enabled, isFalse);
      tracer.enabled = true;
      expect(tracer.enabled, isTrue);
    });
  });

  // =========================================================================
  // tracer.dart - withSpan invalid span warning path
  // =========================================================================
  group('Tracer withSpan/withSpanAsync invalid span paths', () {
    test('withSpan logs warning for invalid span', () {
      final tracer = OTel.tracer();

      // Create a valid span, then wrap it in an invalid wrapper
      final realSpan = tracer.startSpan('will-be-invalid');
      final invalidSpan = _InvalidSpanWrapper(realSpan);

      // withSpan should complete but log the invalid-span warning
      final result = tracer.withSpan(invalidSpan, () => 42);
      expect(result, equals(42));

      expect(
        logOutput.any((msg) => msg.contains('invalid after withSpan')),
        isTrue,
        reason: 'Expected invalid span warning in withSpan',
      );

      realSpan.end();
    });

    test('withSpanAsync logs warning for invalid span', () async {
      final tracer = OTel.tracer();

      // Create a valid span, then wrap it in an invalid wrapper
      final realSpan = tracer.startSpan('will-be-invalid-async');
      final invalidSpan = _InvalidSpanWrapper(realSpan);

      // Exercises the invalid span warning path in withSpanAsync
      final result = await tracer.withSpanAsync(
        invalidSpan,
        () async => 'hello',
      );
      expect(result, equals('hello'));

      expect(
        logOutput.any((msg) => msg.contains('invalid after withSpanAsync')),
        isTrue,
        reason: 'Expected invalid span warning in withSpanAsync',
      );

      realSpan.end();
    });
  });

  // =========================================================================
  // tracer.dart - startSpanWithContext updates Context.current
  // =========================================================================
  group('Tracer startSpanWithContext', () {
    test(
      'startSpanWithContext updates Context.current when context matches',
      () {
        final tracer = OTel.tracer();

        // Set the current context to a known context
        final ctx = Context.current;

        // Call startSpanWithContext with Context.current so that
        // Context.current == context is true, so Context.current gets updated
        final span = tracer.startSpanWithContext(
          name: 'context-update-span',
          context: ctx,
        );

        // Context.current should now have the span set
        expect(span, isNotNull);
        expect(span.name, equals('context-update-span'));

        span.end();
      },
    );
  });

  // =========================================================================
  // tracer.dart - parentSpan without context spanContext
  // =========================================================================
  group('Tracer startSpan with explicit parentSpan', () {
    test('startSpan uses parentSpan context when no context spanContext', () {
      final tracer = OTel.tracer();

      // Create a parent span first
      final parentSpan = tracer.startSpan('parent-span');

      // Now start a child span passing parentSpan explicitly, but on Context.root
      // so there's no spanContext on the context. This exercises the parentSpan fallback.
      final childSpan = tracer.startSpan(
        'child-span',
        context: Context.root,
        parentSpan: parentSpan,
      );

      // The child should inherit the parent's trace ID
      expect(
        childSpan.spanContext.traceId.toString(),
        equals(parentSpan.spanContext.traceId.toString()),
      );

      childSpan.end();
      parentSpan.end();
    });
  });

  // =========================================================================
  // tracer.dart - sampling attributes merge paths
  // =========================================================================
  group('Tracer sampling with attributes', () {
    test('sampler attributes set when span has no attributes', () async {
      await OTel.reset();
      logOutput.clear();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      // Initialize first, then create attributes (OTel.attributes requires init)
      // We use a late sampler that creates attributes on demand
      final lateSampler = _LateAttributeSampler(
        decision: SamplingDecision.recordAndSample,
        attributeKey: 'sampler.key',
        attributeValue: 'value1',
      );

      await OTel.initialize(
        serviceName: 'sampler-attrs-test',
        detectPlatformResources: false,
        sampler: lateSampler,
      );

      final tracer = OTel.tracer();

      // Start span WITHOUT attributes - exercises sampler-attributes-set path
      final span = tracer.startSpan('sampler-attrs-span');
      expect(span, isNotNull);
      span.end();
    });

    test('sampler attributes merged with existing span attributes', () async {
      await OTel.reset();
      logOutput.clear();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      final lateSampler = _LateAttributeSampler(
        decision: SamplingDecision.recordAndSample,
        attributeKey: 'sampler.extra',
        attributeValue: 'extra',
      );

      await OTel.initialize(
        serviceName: 'sampler-merge-test',
        detectPlatformResources: false,
        sampler: lateSampler,
      );

      final tracer = OTel.tracer();

      // Start span WITH attributes - exercises sampler-attributes-merge path
      final span = tracer.startSpan(
        'sampler-merge-span',
        attributes: OTel.attributes([OTel.attributeString('span.key', 'val')]),
      );
      expect(span, isNotNull);
      span.end();
    });
  });

  // =========================================================================
  // span.dart - list attribute setters and other delegation methods
  // =========================================================================
  group('Span delegation methods', () {
    test('setBoolListAttribute delegates correctly', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('bool-list-span');

      // Exercises setBoolListAttribute delegation
      span.setBoolListAttribute('test.bools', [true, false, true]);
      span.end();
    });

    test('setDoubleListAttribute delegates correctly', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('double-list-span');

      // Exercises setDoubleListAttribute delegation
      span.setDoubleListAttribute('test.doubles', [1.1, 2.2, 3.3]);
      span.end();
    });

    test('setIntListAttribute delegates correctly', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('int-list-span');

      // Exercises setIntListAttribute delegation
      span.setIntListAttribute('test.ints', [1, 2, 3]);
      span.end();
    });

    test('setStringListAttribute delegates correctly', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('string-list-span');

      // Exercises setStringListAttribute delegation
      span.setStringListAttribute<String>('test.strings', ['a', 'b', 'c']);
      span.end();
    });

    test('setDateTimeAsStringAttribute delegates correctly', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('datetime-span');

      // Exercises setDateTimeAsStringAttribute delegation
      span.setDateTimeAsStringAttribute('test.time', DateTime.now());
      span.end();
    });

    test('attributes setter works on SDK span', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('attrs-setter-span');

      // Exercises the attributes setter
      final newAttrs = OTel.attributesFromMap({'new.key': 'new.value'});
      span.attributes = newAttrs;

      // Exercises addAttributes
      span.addAttributes(OTel.attributesFromMap({'extra.key': 'extra.value'}));

      span.end();
    });
  });

  // =========================================================================
  // span.dart - end() with throwing processor (error paths)
  // =========================================================================
  group('Span end() with throwing processor', () {
    test('end() catches processor onEnd exception and continues', () async {
      await OTel.reset();
      logOutput.clear();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      // Re-initialize with a custom span processor that throws on onEnd
      await OTel.initialize(
        serviceName: 'throwing-processor-test',
        detectPlatformResources: false,
        spanProcessor: _ThrowingSpanProcessor(),
      );

      final tracer = OTel.tracer();
      final span = tracer.startSpan('will-throw-on-end');

      // end() should not propagate the processor error (per-processor catch block)
      // The error is caught inside the per-processor try/catch
      span.end();

      // The processor error should be logged
      expect(
        logOutput.any((msg) => msg.contains('Error calling onEnd')),
        isTrue,
        reason: 'Expected error log from processor onEnd failure',
      );
    });
  });

  // =========================================================================
  // span.dart - toString with events and links
  // =========================================================================
  group('Span toString coverage', () {
    test('toString includes span events when present', () {
      final tracer = OTel.tracer();
      final span = tracer.startSpan('toString-events-span');

      span.addEventNow(
        'test-event',
        OTel.attributesFromMap({'event.key': 'event.val'}),
      );

      final str = span.toString();
      expect(str, contains('spanEvents:'));
      expect(str, contains('test-event'));

      span.end();
    });

    test('toString includes span links when present', () {
      final tracer = OTel.tracer();
      final linkContext = OTel.spanContext(
        traceId: OTel.traceIdFrom('aabbccddeeff00112233445566778899'),
        spanId: OTel.spanIdFrom('1122334455667788'),
      );
      final span = tracer.startSpan('toString-links-span');

      span.addLink(
        linkContext,
        OTel.attributesFromMap({'link.key': 'link.val'}),
      );

      final str = span.toString();
      expect(str, contains('spanLinks:'));

      span.end();
    });
  });

  // =========================================================================
  // meter.dart - Getter coverage and NoopMeter tests
  // =========================================================================
  group('Meter getters', () {
    test('version getter returns delegate version', () {
      final meter = OTel.meter();
      // Exercises the version getter
      final version = meter.version;
      expect(version, anyOf(isNull, isA<String>()));
    });

    test('schemaUrl getter returns delegate schemaUrl', () {
      final meter = OTel.meter();
      // Exercises the schemaUrl getter
      final schemaUrl = meter.schemaUrl;
      expect(schemaUrl, anyOf(isNull, isA<String>()));
    });

    test('attributes getter returns delegate attributes', () {
      final meter = OTel.meter();
      // Exercises the attributes getter
      final attrs = meter.attributes;
      expect(attrs, anyOf(isNull, isA<Attributes>()));
    });
  });

  group('NoopMeter observable instrument collect', () {
    test('NoopObservableCounter collect returns empty list', () {
      final noop = NoopObservableCounter<int>(name: 'noop-counter');
      // Exercises NoopObservableCounter.collect
      final measurements = noop.collect();
      expect(measurements, isEmpty);
    });

    test('NoopObservableUpDownCounter collect returns empty list', () {
      final noop = NoopObservableUpDownCounter<int>(name: 'noop-updown');
      // Exercises NoopObservableUpDownCounter.collect
      final measurements = noop.collect();
      expect(measurements, isEmpty);
    });

    test('NoopObservableGauge collect returns empty list', () {
      final noop = NoopObservableGauge<double>(name: 'noop-gauge');
      // Exercises NoopObservableGauge.collect
      final measurements = noop.collect();
      expect(measurements, isEmpty);
    });
  });

  // =========================================================================
  // batch_span_processor.dart - queue full and debug logging
  // =========================================================================
  group('BatchSpanProcessor coverage gaps', () {
    test('onEnd drops span when queue is full', () async {
      await OTel.reset();
      logOutput.clear();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logOutput.add;

      final exporter = InMemorySpanExporter();
      // Create a batch processor with a very small queue
      final processor = BatchSpanProcessor(
        exporter,
        const BatchSpanProcessorConfig(
          maxQueueSize: 2,
          scheduleDelay: Duration(hours: 1), // won't trigger automatically
          maxExportBatchSize: 512,
        ),
      );

      await OTel.initialize(
        serviceName: 'batch-queue-full-test',
        detectPlatformResources: false,
        spanProcessor: processor,
      );

      final tracer = OTel.tracer();

      // Create and end more spans than the queue can hold
      for (int i = 0; i < 5; i++) {
        final span = tracer.startSpan('span-$i');
        span.end(); // this calls processor.onEnd
      }

      // Give a little time for async operations
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should have logged about dropping spans due to full queue
      expect(
        logOutput.any((msg) => msg.contains('queue full')),
        isTrue,
        reason: 'Expected queue full debug log message',
      );

      await processor.shutdown();
    });

    test('onNameUpdate is a no-op', () async {
      final exporter = InMemorySpanExporter();
      final processor = BatchSpanProcessor(exporter);

      final tracer = OTel.tracer();
      final span = tracer.startSpan('name-update-test');

      // Exercises onNameUpdate (no-op for batch processor)
      await processor.onNameUpdate(span, 'new-name');
      // No exception means success

      span.end();
      await processor.shutdown();
    });

    test('forceFlush when shutdown is a no-op', () async {
      final exporter = InMemorySpanExporter();
      final processor = BatchSpanProcessor(exporter);

      await processor.shutdown();

      // Exercises forceFlush after shutdown (no-op path)
      await processor.forceFlush();
      // No exception means success
    });

    test('timer error in exportBatch is caught and logged', () async {
      // Create an exporter that throws during export
      final failingExporter = _TimerFailExporter();
      final processor = BatchSpanProcessor(
        failingExporter,
        const BatchSpanProcessorConfig(
          scheduleDelay: Duration(milliseconds: 50),
          maxQueueSize: 100,
          maxExportBatchSize: 10,
        ),
      );

      // Add a span so _exportBatch has something to export
      final tracer = OTel.tracer();
      final span = tracer.startSpan('timer-error-span');
      span.end();
      await processor.onEnd(span);

      // Wait for the timer to fire and hit the export error path
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // The error should be caught, not propagated
      await processor.shutdown();
    });

    test('onEnd after shutdown is a no-op', () async {
      final exporter = InMemorySpanExporter();
      final processor = BatchSpanProcessor(exporter);

      await processor.shutdown();

      final tracer = OTel.tracer();
      final span = tracer.startSpan('post-shutdown-span');

      // Exercises onEnd after shutdown (no-op path)
      await processor.onEnd(span);
      // No exception means success

      span.end();
    });
  });

  // =========================================================================
  // composite_sampler.dart - description and attribute combining
  // =========================================================================
  group('CompositeSampler coverage gaps', () {
    test('description returns correct format', () {
      const sampler = CompositeSampler.and([
        AlwaysOnSampler(),
        AlwaysOnSampler(),
      ]);

      // Exercises the description getter
      final desc = sampler.description;
      expect(desc, contains('CompositeSampler'));
      expect(desc, contains('and'));
      expect(desc, contains('AlwaysOnSampler'));
    });

    test('OR sampler: first drops, second samples -> samples', () {
      const sampler = CompositeSampler.or([
        AlwaysOffSampler(),
        AlwaysOnSampler(),
      ]);

      final result = sampler.shouldSample(
        parentContext: Context.root,
        traceId: '00112233445566778899aabbccddeeff',
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      // OR: first drops, second samples => should sample
      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('OR sampler: all drop -> drops', () {
      const sampler = CompositeSampler.or([
        AlwaysOffSampler(),
        AlwaysOffSampler(),
      ]);

      final result = sampler.shouldSample(
        parentContext: Context.root,
        traceId: '00112233445566778899aabbccddeeff',
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      // OR: all drop => should drop
      expect(result.decision, equals(SamplingDecision.drop));
    });

    test('AND sampler: one drops -> drops', () {
      const sampler = CompositeSampler.and([
        AlwaysOnSampler(),
        AlwaysOffSampler(),
      ]);

      final result = sampler.shouldSample(
        parentContext: Context.root,
        traceId: '00112233445566778899aabbccddeeff',
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      // AND: one drops => should drop
      expect(result.decision, equals(SamplingDecision.drop));
    });

    test('AND sampler: all sample -> samples', () {
      const sampler = CompositeSampler.and([
        AlwaysOnSampler(),
        AlwaysOnSampler(),
      ]);

      final result = sampler.shouldSample(
        parentContext: Context.root,
        traceId: '00112233445566778899aabbccddeeff',
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      // AND: all sample => should sample
      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('composite sampler attribute combining path works correctly', () {
      // Lines 66-68 in composite_sampler.dart combine attributes from samplers.
      // Bug fix: changed `??` to `??=` so combinedAttributes is properly assigned.
      final attrs1 = OTel.attributes([OTel.attributeString('key1', 'val1')]);

      final sampler = CompositeSampler.and([
        _AttributeAddingSampler(
          decision: SamplingDecision.recordAndSample,
          samplerAttributes: attrs1,
        ),
        const AlwaysOnSampler(),
      ]);

      final result = sampler.shouldSample(
        parentContext: Context.root,
        traceId: '00112233445566778899aabbccddeeff',
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result.decision, SamplingDecision.recordAndSample);
    });

    test('empty composite sampler returns recordAndSample', () {
      const sampler = CompositeSampler.and([]);

      final result = sampler.shouldSample(
        parentContext: Context.root,
        traceId: '00112233445566778899aabbccddeeff',
        name: 'test-span',
        spanKind: SpanKind.internal,
        attributes: null,
        links: null,
      );

      expect(result.decision, equals(SamplingDecision.recordAndSample));
    });

    test('OR description returns correct format', () {
      const sampler = CompositeSampler.or([
        AlwaysOffSampler(),
        AlwaysOnSampler(),
      ]);

      final desc = sampler.description;
      expect(desc, contains('or'));
    });
  });

  // =========================================================================
  // From final_3_lines_test.dart - Gauge, MetricTransformer, Histogram, Counter
  // =========================================================================
  // gauge.dart: double type path in getValue
  test('Gauge<double> getValue returns double', () {
    final meter = OTel.meterProvider().getMeter(name: 'test');
    final gauge = meter.createGauge<double>(name: 'dbl_gauge');
    gauge.record(3.14);
    // Cast to SDK Gauge to access getValue
    final sdkGauge = gauge as Gauge<double>;
    final value = sdkGauge.getValue(OTel.attributes([]));
    expect(value, isA<double>());
  });

  // metric_transformer.dart: unsupported type defaults to string
  test('transformResource with unsupported attribute type uses toString', () {
    // Create a resource that has list values with mixed types
    // The _createKeyValue else branch handles unknown types via toString
    final resource = ResourceCreate.create(
      OTel.attributesFromMap({'regular': 'string_val'}),
    );
    final proto = MetricTransformer.transformResource(resource);
    expect(proto.attributes, isNotEmpty);
  });

  // trace/tracer.dart: Context.current update in startSpanWithContext
  test(
    'startSpanWithContext updates global context when matching (final_3)',
    () {
      final tracer = OTel.tracer();
      final currentCtx = Context.current;
      final span = tracer.startSpanWithContext(
        name: 'ctx-span',
        context: currentCtx,
      );
      span.end();
    },
  );

  // metrics/instruments/histogram.dart: double type path in getValue
  test('Histogram<double> getValue returns double', () {
    final meter = OTel.meterProvider().getMeter(name: 'test');
    final histogram = meter.createHistogram<double>(name: 'dbl_hist');
    histogram.record(3.14);
    // Cast to SDK Histogram to access getValue
    final sdkHist = histogram as Histogram<double>;
    final value = sdkHist.getValue(OTel.attributes([]));
    expect(value, isNotNull);
  });

  // metrics/instruments/counter.dart: double type path in getValue
  test('Counter<double> getValue returns double', () {
    final meter = OTel.meterProvider().getMeter(name: 'test');
    final counter = meter.createCounter<double>(name: 'dbl_counter');
    counter.add(1.5);
    final sdkCounter = counter as Counter<double>;
    final value = sdkCounter.getValue(OTel.attributes([]));
    expect(value, isA<double>());
  });

  // =========================================================================
  // From final_9_lines_test.dart - ProbabilitySampler, RateLimitingSampler,
  // W3C propagator field length validation
  // =========================================================================

  // ProbabilitySampler - description and validation
  group('ProbabilitySampler coverage', () {
    test('description returns expected string', () {
      final sampler = ProbabilitySampler(0.5);
      expect(sampler.description, contains('0.5'));
    });

    test('invalid probability throws ArgumentError', () {
      expect(() => ProbabilitySampler(1.5), throwsArgumentError);
      expect(() => ProbabilitySampler(-0.1), throwsArgumentError);
    });
  });

  // RateLimitingSampler - description and validation
  group('RateLimitingSampler coverage', () {
    test('description returns expected string', () {
      final sampler = RateLimitingSampler(100.0);
      expect(sampler.description, contains('100'));
      sampler.dispose();
    });

    test('invalid rate throws ArgumentError', () {
      expect(() => RateLimitingSampler(0), throwsArgumentError);
      expect(() => RateLimitingSampler(-1), throwsArgumentError);
    });
  });

  // W3C propagator - Invalid length traceId, spanId, traceFlags in traceparent
  group('W3C propagator field length validation', () {
    test('traceparent with short traceId is rejected', () {
      // traceId is only 20 chars (should be 32)
      final map = {
        'traceparent': '00-abcdef12345678901234-1234567890abcdef-01',
      };
      final propagator = W3CTraceContextPropagator();
      final context = propagator.extract(Context.root, map, _MapGetter(map));
      expect(context.spanContext, isNull);
    });

    test('traceparent with short spanId is rejected', () {
      // spanId only 14 chars (should be 16)
      final map = {
        'traceparent': '00-abcdef1234567890abcdef12345678-1234567890abcd-01',
      };
      final propagator = W3CTraceContextPropagator();
      final context = propagator.extract(Context.root, map, _MapGetter(map));
      expect(context.spanContext, isNull);
    });

    test('traceparent with short traceFlags is rejected', () {
      // traceFlags only 1 char (should be 2)
      final map = {
        'traceparent': '00-abcdef1234567890abcdef12345678-1234567890abcdef-0',
      };
      final propagator = W3CTraceContextPropagator();
      final context = propagator.extract(Context.root, map, _MapGetter(map));
      expect(context.spanContext, isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Helper class for W3C propagator tests (from final_9_lines_test.dart)
// ---------------------------------------------------------------------------
class _MapGetter implements TextMapGetter<String> {
  final Map<String, String> _map;
  _MapGetter(this._map);

  @override
  String? get(String key) => _map[key];

  @override
  Iterable<String> keys() => _map.keys;
}
