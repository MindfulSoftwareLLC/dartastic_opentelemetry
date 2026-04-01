// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Tests that exercise code paths with debug logging ENABLED.
//
// The purpose of this file is to cover the hundreds of `if (OTelLog.isDebug())`
// guard lines in span.dart, tracer.dart, tracer_provider.dart, and
// simple_span_processor.dart that are otherwise uncovered when tests run at
// the default (info) log level.
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

void main() {
  late InMemorySpanExporter exporter;
  late SimpleSpanProcessor processor;
  final List<String> logOutput = [];

  setUp(() async {
    await OTel.reset();
    logOutput.clear();

    // Enable the most verbose log level so every isDebug() guard evaluates
    // to true, and capture all log output into the list for assertions.
    OTelLog.enableTraceLogging();
    OTelLog.logFunction = logOutput.add;

    exporter = InMemorySpanExporter();
    processor = SimpleSpanProcessor(exporter);
    await OTel.initialize(
      serviceName: 'debug-test',
      spanProcessor: processor,
      detectPlatformResources: false,
    );
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
    // Restore defaults so other test files are not affected.
    OTelLog.currentLevel = LogLevel.info;
    OTelLog.logFunction = print;
  });

  // ---------------------------------------------------------------------------
  // Span creation / end
  // ---------------------------------------------------------------------------

  test('span creation logs debug messages', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('creation-test');

    expect(span, isNotNull);
    expect(
      logOutput.any(
          (msg) => msg.contains('SDKSpan') && msg.contains('Created new span')),
      isTrue,
      reason: 'Expected a debug log about span creation',
    );
    span.end();
  });

  test('span end logs debug messages', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('end-test');
    logOutput.clear();
    span.end();

    expect(
      logOutput
          .any((msg) => msg.contains('SDKSpan') && msg.contains('end span')),
      isTrue,
      reason: 'Expected a debug log about ending the span',
    );
    expect(
      logOutput.any((msg) =>
          msg.contains('Notifying') && msg.contains('span processors')),
      isTrue,
      reason: 'Expected a debug log about notifying processors',
    );
    expect(
      logOutput.any((msg) =>
          msg.contains('onEnd') && msg.contains('SimpleSpanProcessor')),
      isTrue,
      reason: 'Expected a debug log about calling onEnd on the processor',
    );
  });

  // ---------------------------------------------------------------------------
  // SimpleSpanProcessor
  // ---------------------------------------------------------------------------

  test('SimpleSpanProcessor onStart logs', () {
    final tracer = OTel.tracer();
    logOutput.clear();
    tracer.startSpan('processor-onstart-test');

    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') && msg.contains('onStart')),
      isTrue,
      reason: 'Expected SimpleSpanProcessor onStart debug log',
    );
  });

  test('SimpleSpanProcessor onEnd logs export', () async {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('processor-onend-test');
    logOutput.clear();
    span.end();
    // Give the async export a moment to complete.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') &&
          msg.contains('Exporting span')),
      isTrue,
      reason: 'Expected SimpleSpanProcessor export debug log',
    );
    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') &&
          msg.contains('Successfully exported')),
      isTrue,
      reason: 'Expected SimpleSpanProcessor success debug log',
    );
  });

  test('SimpleSpanProcessor onNameUpdate logs', () async {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('name-update-test');
    logOutput.clear();
    await processor.onNameUpdate(span, 'new-name');

    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') &&
          msg.contains('Name updated') &&
          msg.contains('new-name')),
      isTrue,
      reason: 'Expected SimpleSpanProcessor name update debug log',
    );
    span.end();
  });

  test('SimpleSpanProcessor shutdown logs', () async {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('shutdown-test');
    span.end();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    logOutput.clear();

    // Create a fresh processor to test shutdown in isolation.
    final freshExporter = InMemorySpanExporter();
    final freshProcessor = SimpleSpanProcessor(freshExporter);
    await freshProcessor.shutdown();

    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') && msg.contains('Shutting down')),
      isTrue,
      reason: 'Expected SimpleSpanProcessor shutdown debug log',
    );
    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') &&
          msg.contains('Shutdown complete')),
      isTrue,
      reason: 'Expected SimpleSpanProcessor shutdown complete debug log',
    );
  });

  test('SimpleSpanProcessor shutdown when already shut down logs', () async {
    final freshExporter = InMemorySpanExporter();
    final freshProcessor = SimpleSpanProcessor(freshExporter);
    await freshProcessor.shutdown();
    logOutput.clear();

    // Second shutdown should hit the "Already shut down" branch.
    await freshProcessor.shutdown();

    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') &&
          msg.contains('Already shut down')),
      isTrue,
      reason: 'Expected "Already shut down" debug log',
    );
  });

  test('SimpleSpanProcessor forceFlush logs with no pending exports', () async {
    logOutput.clear();

    final freshExporter = InMemorySpanExporter();
    final freshProcessor = SimpleSpanProcessor(freshExporter);
    await freshProcessor.forceFlush();

    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') &&
          msg.contains('Force flushing')),
      isTrue,
      reason: 'Expected SimpleSpanProcessor forceFlush debug log',
    );
    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') &&
          msg.contains('No pending exports')),
      isTrue,
      reason: 'Expected "No pending exports" debug log',
    );
    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') &&
          msg.contains('Force flush complete')),
      isTrue,
      reason: 'Expected "Force flush complete" debug log',
    );
    await freshProcessor.shutdown();
  });

  test('SimpleSpanProcessor forceFlush when shut down logs', () async {
    final freshExporter = InMemorySpanExporter();
    final freshProcessor = SimpleSpanProcessor(freshExporter);
    await freshProcessor.shutdown();
    logOutput.clear();

    await freshProcessor.forceFlush();

    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') &&
          msg.contains('Cannot force flush')),
      isTrue,
      reason: 'Expected "Cannot force flush" debug log',
    );
  });

  // ---------------------------------------------------------------------------
  // Span setStatus
  // ---------------------------------------------------------------------------

  test('span setStatus logs debug', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('status-test');
    logOutput.clear();

    span.setStatus(SpanStatusCode.Ok);

    expect(
      logOutput
          .any((msg) => msg.contains('SDKSpan') && msg.contains('Set status')),
      isTrue,
      reason: 'Expected setStatus debug log',
    );
    span.end();
  });

  // ---------------------------------------------------------------------------
  // Span typed attribute setters (delegation methods)
  // ---------------------------------------------------------------------------

  test('span typed attribute setters are exercised', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('attr-test');

    // Exercise every typed setter so the delegation lines in span.dart
    // (lines ~153-195) are covered.
    span.setBoolAttribute('b', true);
    span.setBoolListAttribute('bl', [true, false]);
    span.setDoubleAttribute('d', 1.5);
    span.setDoubleListAttribute('dl', [1.0, 2.0]);
    span.setIntAttribute('i', 42);
    span.setIntListAttribute('il', [1, 2, 3]);
    span.setStringAttribute<String>('s', 'hello');
    span.setStringListAttribute<String>('sl', ['a', 'b']);
    span.setDateTimeAsStringAttribute('dt', DateTime.now());

    // Verify that the attributes were actually set on the span.
    final attrs = span.attributes;
    expect(attrs.getString('s'), equals('hello'));
    expect(attrs.getInt('i'), equals(42));
    expect(attrs.getDouble('d'), equals(1.5));
    expect(attrs.getBool('b'), isTrue);

    span.end();
  });

  // ---------------------------------------------------------------------------
  // Span addAttributes, addEvent, addEvents, addLink, addSpanLink
  // ---------------------------------------------------------------------------

  test('span addAttributes, addEvent, addEvents, addLink, addSpanLink', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('methods-test');

    // addAttributes
    final extraAttrs = OTel.attributesFromMap({'extra': 'value'});
    span.addAttributes(extraAttrs);
    expect(span.attributes.getString('extra'), equals('value'));

    // addEvent
    final event = OTel.spanEvent('test-event');
    span.addEvent(event);
    expect(span.spanEvents, isNotNull);
    expect(span.spanEvents!.any((e) => e.name == 'test-event'), isTrue);

    // addEventNow
    span.addEventNow('now-event');
    expect(span.spanEvents!.any((e) => e.name == 'now-event'), isTrue);

    // addEvents
    span.addEvents({'batch-event-1': null, 'batch-event-2': null});
    expect(span.spanEvents!.any((e) => e.name == 'batch-event-1'), isTrue);
    expect(span.spanEvents!.any((e) => e.name == 'batch-event-2'), isTrue);

    // addLink
    final otherSpan = tracer.startSpan('link-target');
    span.addLink(otherSpan.spanContext);
    expect(span.spanLinks, isNotNull);
    expect(span.spanLinks!.isNotEmpty, isTrue);

    // addSpanLink
    final linkSpan = tracer.startSpan('link-span');
    final spanLink = OTel.spanLink(linkSpan.spanContext);
    span.addSpanLink(spanLink);
    expect(span.spanLinks!.length, greaterThanOrEqualTo(2));

    // recordException
    span.recordException(Exception('test exception'),
        stackTrace: StackTrace.current);

    otherSpan.end();
    linkSpan.end();
    span.end();
  });

  // ---------------------------------------------------------------------------
  // Span properties
  // ---------------------------------------------------------------------------

  test(
      'span properties: kind, isRecording, isEnded, endTime, parentSpan, resource',
      () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('prop-test', kind: SpanKind.client);

    expect(span.kind, equals(SpanKind.client));
    expect(span.isRecording, isTrue);
    expect(span.isEnded, isFalse);
    expect(span.endTime, isNull);
    expect(span.startTime, isNotNull);
    expect(span.spanId, isNotNull);
    expect(span.spanContext, isNotNull);
    expect(span.status, equals(SpanStatusCode.Unset));
    expect(span.statusDescription, isNull);
    expect(span.instrumentationScope, isNotNull);
    // parentSpanContext may be null for a root span - just access it for coverage.
    // ignore: unnecessary_statements
    span.parentSpanContext;
    expect(span.isValid, isTrue);
    // parentSpan may be null for a root span - just access it for coverage.
    // ignore: unnecessary_statements
    span.parentSpan;
    // resource comes from the tracer
    expect(span.resource, isNotNull);

    span.end();
    expect(span.isEnded, isTrue);
    expect(span.endTime, isNotNull);
    expect(span.isRecording, isFalse);
  });

  test('span updateName notifies processors', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('original-name');
    logOutput.clear();

    span.updateName('renamed');
    expect(span.name, equals('renamed'));
    expect(
      logOutput.any((msg) =>
          msg.contains('SimpleSpanProcessor') &&
          msg.contains('Name updated') &&
          msg.contains('renamed')),
      isTrue,
      reason: 'Expected name update log from processor',
    );
    span.end();
  });

  test('span toString covers all branches', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('to-string-test');

    // With events and links
    span.addEventNow('ts-event');
    final otherSpan = tracer.startSpan('ts-link');
    span.addLink(otherSpan.spanContext);

    final str = span.toString();
    expect(str, contains('Span {'));
    expect(str, contains('to-string-test'));

    otherSpan.end();
    span.end();
  });

  // ---------------------------------------------------------------------------
  // Tracer withSpan / withSpanAsync / recordSpan
  // ---------------------------------------------------------------------------

  test('tracer withSpan logs debug', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('with-span-test');
    logOutput.clear();

    final result = tracer.withSpan<int>(span, () => 42);
    expect(result, equals(42));

    expect(
      logOutput.any(
          (msg) => msg.contains('Tracer') && msg.contains('withSpan called')),
      isTrue,
      reason: 'Expected Tracer withSpan debug log',
    );
    expect(
      logOutput.any((msg) =>
          msg.contains('Tracer') && msg.contains('withSpan completed')),
      isTrue,
      reason: 'Expected Tracer withSpan completed debug log',
    );
    span.end();
  });

  test('tracer withSpanAsync logs debug', () async {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('with-span-async-test');
    logOutput.clear();

    final result = await tracer.withSpanAsync<int>(span, () async => 99);
    expect(result, equals(99));

    expect(
      logOutput.any((msg) =>
          msg.contains('Tracer') && msg.contains('withSpanAsync called')),
      isTrue,
      reason: 'Expected Tracer withSpanAsync debug log',
    );
    expect(
      logOutput.any((msg) =>
          msg.contains('Tracer') && msg.contains('withSpanAsync completed')),
      isTrue,
      reason: 'Expected Tracer withSpanAsync completed debug log',
    );
    span.end();
  });

  test('tracer recordSpan with debug', () {
    final tracer = OTel.tracer();
    logOutput.clear();

    final result = tracer.recordSpan(
      name: 'record-span-test',
      fn: () => 'done',
    );
    expect(result, equals('done'));

    // recordSpan starts a span, runs fn, then ends the span. All with debug.
    expect(
      logOutput.any(
          (msg) => msg.contains('Tracer') && msg.contains('Starting span')),
      isTrue,
      reason: 'Expected Tracer startSpan debug log from recordSpan',
    );
  });

  test('tracer recordSpanAsync with debug', () async {
    final tracer = OTel.tracer();
    logOutput.clear();

    final result = await tracer.recordSpanAsync(
      name: 'record-span-async-test',
      fn: () async => 'async-done',
    );
    expect(result, equals('async-done'));

    expect(
      logOutput.any(
          (msg) => msg.contains('Tracer') && msg.contains('Starting span')),
      isTrue,
      reason: 'Expected Tracer startSpan debug log from recordSpanAsync',
    );
  });

  // ---------------------------------------------------------------------------
  // Tracer startSpan with parent context
  // ---------------------------------------------------------------------------

  test('tracer startSpan with parent context logs', () {
    final tracer = OTel.tracer();
    final parentSpan = tracer.startSpan('parent-span');
    logOutput.clear();

    final childSpan = tracer.startSpan(
      'child-span',
      parentSpan: parentSpan,
    );

    expect(
      logOutput.any((msg) =>
          msg.contains('Creating child span') ||
          (msg.contains('Tracer') && msg.contains('Starting span'))),
      isTrue,
      reason: 'Expected child span creation debug log',
    );

    childSpan.end();
    parentSpan.end();
  });

  test('tracer createSpan logs debug', () {
    final tracer = OTel.tracer();
    logOutput.clear();

    final span = tracer.createSpan(name: 'create-span-test');
    expect(span, isNotNull);

    expect(
      logOutput.any(
          (msg) => msg.contains('Tracer') && msg.contains('Creating span')),
      isTrue,
      reason: 'Expected Tracer createSpan debug log',
    );
    span.end();
  });

  test('tracer startSpanWithContext logs debug', () {
    final tracer = OTel.tracer();
    final ctx = OTel.context();
    logOutput.clear();

    final span = tracer.startSpanWithContext(
      name: 'ctx-span-test',
      context: ctx,
    );
    expect(span, isNotNull);

    expect(
      logOutput.any(
          (msg) => msg.contains('Tracer') && msg.contains('Starting span')),
      isTrue,
      reason: 'Expected Tracer startSpan debug log from startSpanWithContext',
    );
    span.end();
  });

  // ---------------------------------------------------------------------------
  // TracerProvider
  // ---------------------------------------------------------------------------

  test('TracerProvider getTracer logs debug', () {
    logOutput.clear();

    final tracer = OTel.tracerProvider().getTracer(
      'debug-tracer',
      version: '2.0.0',
      schemaUrl: 'https://example.com/schema',
    );

    expect(tracer, isNotNull);
    expect(
      logOutput.any((msg) =>
          msg.contains('TracerProvider') && msg.contains('Getting tracer')),
      isTrue,
      reason: 'Expected TracerProvider getTracer debug log',
    );
  });

  test('TracerProvider shutdown logs debug', () async {
    // Create a separate provider for this test.
    logOutput.clear();

    final tp = OTel.tracerProvider();
    await tp.shutdown();

    expect(
      logOutput.any((msg) =>
          msg.contains('TracerProvider') && msg.contains('Shutting down')),
      isTrue,
      reason: 'Expected TracerProvider shutdown debug log',
    );
    expect(
      logOutput.any((msg) =>
          msg.contains('TracerProvider') && msg.contains('Shutdown complete')),
      isTrue,
      reason: 'Expected TracerProvider shutdown complete debug log',
    );
  });

  test('TracerProvider shutdown when already shut down logs', () async {
    final tp = OTel.tracerProvider();
    await tp.shutdown();
    logOutput.clear();

    await tp.shutdown();

    expect(
      logOutput.any((msg) =>
          msg.contains('TracerProvider') && msg.contains('Already shut down')),
      isTrue,
      reason: 'Expected "Already shut down" debug log',
    );
  });

  test('TracerProvider forceFlush logs debug', () async {
    logOutput.clear();

    final tp = OTel.tracerProvider();
    await tp.forceFlush();

    expect(
      logOutput.any((msg) =>
          msg.contains('TracerProvider') && msg.contains('Force flushing')),
      isTrue,
      reason: 'Expected TracerProvider forceFlush debug log',
    );
    expect(
      logOutput.any((msg) =>
          msg.contains('TracerProvider') &&
          msg.contains('Force flush complete')),
      isTrue,
      reason: 'Expected TracerProvider force flush complete debug log',
    );
  });

  test('TracerProvider forceFlush when shut down logs', () async {
    final tp = OTel.tracerProvider();
    await tp.shutdown();
    logOutput.clear();

    await tp.forceFlush();

    expect(
      logOutput.any((msg) =>
          msg.contains('TracerProvider') && msg.contains('Cannot force flush')),
      isTrue,
      reason: 'Expected "Cannot force flush" debug log',
    );
  });

  test('TracerProvider addSpanProcessor logs debug', () {
    logOutput.clear();

    final freshExporter = InMemorySpanExporter();
    final freshProcessor = SimpleSpanProcessor(freshExporter);
    final tp = OTel.tracerProvider();
    tp.addSpanProcessor(freshProcessor);

    expect(
      logOutput.any((msg) =>
          msg.contains('SDKTracerProvider') &&
          msg.contains('Adding span processor')),
      isTrue,
      reason: 'Expected addSpanProcessor debug log',
    );
  });

  test('TracerProvider ensureResourceIsSet logs debug', () {
    // Access tracerProvider which will call ensureResourceIsSet internally
    // when creating a tracer.
    logOutput.clear();

    final tp = OTel.tracerProvider();
    tp.resource = null; // Force resource to be re-set from default.
    tp.ensureResourceIsSet();

    expect(
      logOutput.any((msg) =>
          msg.contains('TracerProvider') &&
          msg.contains('Setting resource from default')),
      isTrue,
      reason: 'Expected ensureResourceIsSet debug log',
    );
  });

  // ---------------------------------------------------------------------------
  // Multiple processors notification
  // ---------------------------------------------------------------------------

  test('multiple processors notification logs', () async {
    // Add a second processor to the provider.
    final secondExporter = InMemorySpanExporter();
    final secondProcessor = SimpleSpanProcessor(secondExporter);
    OTel.tracerProvider().addSpanProcessor(secondProcessor);

    final tracer = OTel.tracer();
    logOutput.clear();

    final span = tracer.startSpan('multi-processor-test');
    span.end();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Count the number of onEnd calls logged for SimpleSpanProcessor.
    final onEndLogs = logOutput
        .where((msg) =>
            msg.contains('SimpleSpanProcessor') && msg.contains('onEnd called'))
        .toList();

    // There should be at least 2 onEnd logs (one per processor).
    expect(onEndLogs.length, greaterThanOrEqualTo(2),
        reason: 'Expected onEnd logs from multiple processors');
  });

  // ---------------------------------------------------------------------------
  // Tracer withSpan error path with debug logging
  // ---------------------------------------------------------------------------

  test('tracer withSpan error path logs debug', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('error-path-test');
    logOutput.clear();

    expect(
      () => tracer.withSpan(span, () {
        throw Exception('test error for debug logging');
      }),
      throwsA(isA<Exception>()),
    );

    expect(
      logOutput.any((msg) =>
          msg.contains('Tracer') && msg.contains('withSpan completed')),
      isTrue,
      reason: 'Expected withSpan completed log even on error (from finally)',
    );
    span.end();
  });

  test('tracer withSpanAsync error path logs debug', () async {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('async-error-path-test');
    logOutput.clear();

    await expectLater(
      tracer.withSpanAsync(span, () async {
        throw Exception('async test error for debug logging');
      }),
      throwsA(isA<Exception>()),
    );

    expect(
      logOutput.any((msg) =>
          msg.contains('Tracer') && msg.contains('withSpanAsync completed')),
      isTrue,
      reason:
          'Expected withSpanAsync completed log even on error (from finally)',
    );
    span.end();
  });

  // ---------------------------------------------------------------------------
  // Tracer startActiveSpan / startActiveSpanAsync with debug
  // ---------------------------------------------------------------------------

  test('tracer startActiveSpan with debug', () {
    final tracer = OTel.tracer();
    logOutput.clear();

    final result = tracer.startActiveSpan(
      name: 'active-span-test',
      fn: (span) => 'active-result',
    );
    expect(result, equals('active-result'));

    expect(
      logOutput.any(
          (msg) => msg.contains('Tracer') && msg.contains('withSpan called')),
      isTrue,
      reason: 'Expected withSpan debug log from startActiveSpan',
    );
  });

  test('tracer startActiveSpanAsync with debug', () async {
    final tracer = OTel.tracer();
    logOutput.clear();

    final result = await tracer.startActiveSpanAsync(
      name: 'active-span-async-test',
      fn: (span) async => 'async-active-result',
    );
    expect(result, equals('async-active-result'));

    expect(
      logOutput.any((msg) =>
          msg.contains('Tracer') && msg.contains('withSpanAsync called')),
      isTrue,
      reason: 'Expected withSpanAsync debug log from startActiveSpanAsync',
    );
  });

  // ---------------------------------------------------------------------------
  // Span end with spanStatus parameter
  // ---------------------------------------------------------------------------

  test('span end with spanStatus parameter', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('end-status-test');
    logOutput.clear();

    span.end(spanStatus: SpanStatusCode.Error);

    expect(
      logOutput
          .any((msg) => msg.contains('SDKSpan') && msg.contains('Set status')),
      isTrue,
      reason:
          'Expected setStatus debug log when ending with a spanStatus parameter',
    );
  });

  // ---------------------------------------------------------------------------
  // Sampling decision debug log
  // ---------------------------------------------------------------------------

  test('sampling decision is logged', () {
    final tracer = OTel.tracer();
    logOutput.clear();

    final span = tracer.startSpan('sampling-test');

    expect(
      logOutput.any((msg) => msg.contains('Sampling decision')),
      isTrue,
      reason: 'Expected sampling decision debug log',
    );
    span.end();
  });

  // ---------------------------------------------------------------------------
  // Span isInstanceOf
  // ---------------------------------------------------------------------------

  test('span isInstanceOf checks', () {
    final tracer = OTel.tracer();
    final span = tracer.startSpan('instance-test');

    expect(span.isInstanceOf(APISpan), isTrue);
    expect(span.isInstanceOf(Span), isTrue);
    expect(span.isInstanceOf(String), isFalse);
    span.end();
  });
}
