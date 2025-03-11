// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/trace/v1/trace.pb.dart' as proto;
import 'package:test/test.dart';

import 'mock_collector.dart';

void main() {
  group('MockCollector', () {
    late MockCollector collector;
    late TracerProvider tracerProvider;
    late Tracer tracer;
    final testPort = 4319;

    setUp(() async {
      collector = MockCollector(port: testPort);
      await collector.start();

      await OTel.initialize(
        endpoint: 'localhost:$testPort',
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );

      tracerProvider = OTel.tracerProvider();

      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: 'localhost:$testPort',
          insecure: true,
          timeout: Duration(seconds: 30),
          maxRetries: 3,
        ),
      );

      final processor = SimpleSpanProcessor(exporter);
      tracerProvider.addSpanProcessor(processor);

      tracer = tracerProvider.getTracer('test-tracer');

      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      print('\nTearing down test...');
      await Future.delayed(Duration(milliseconds: 100));
      await tracerProvider.shutdown();
      print('TracerProvider shutdown complete');

      await Future.delayed(Duration(milliseconds: 100));
      await collector.stop();
      print('Collector stopped');

      collector.clear();
      print('Collector cleared');

      await Future.delayed(Duration(milliseconds: 100));
      await OTel.reset();
      print('OTel reset complete\n');
    });

    test('collects and validates simple spans', () async {
      print('\nStarting simple spans test...');
      final rootContext = OTel.context();

      print('Creating span-1...');
      final span1 = tracer.startSpan('span-1', context: rootContext);
      final context1 = rootContext.withSpanContext(span1.spanContext);

      print('Creating span-2...');
      final span2 = tracer.startSpan('span-2', context: context1);

      await Future.delayed(Duration(milliseconds: 50));

      print('Ending span-2...');
      span2.end();

      print('Ending span-1...');
      span1.end();

      print('Waiting for spans to be exported...');
      await collector.waitForSpans(2);

      print('Validating spans...');
      print('Current span count: ${collector.spanCount}');
      collector.assertSpanExists(name: 'span-1');
      collector.assertSpanExists(name: 'span-2');
      expect(collector.spanCount, equals(2));
      print('Test completed successfully\n');
    });

    test('validates span attributes', () async {
      final attributes = <String, Object>{
        'string.key': 'string-value',
        'int.key': 42,
        'bool.key': true,
      }.toAttributes();

      final span = tracer.startSpan(
        'attributed-span',
        attributes: attributes,
      );

      span.end();

      print('Waiting for attributed span...');
      await collector.waitForSpans(1);

      collector.assertSpanExists(
        name: 'attributed-span',
        attributes: {
          'string.key': 'string-value',
          'int.key': 42,
          'bool.key': true,
        },
      );
    });


    test('validates parent-child relationships', () async {
      final rootContext = Context.root;

      final parent = tracer.startSpan('parent', context: rootContext);
      final child = tracer.startSpan('child');

      child.end();
      parent.end();

      print('Waiting for parent-child spans...');
      await collector.waitForSpans(2);

      collector.assertSpanExists(
        name: 'child',
        parentSpanId: parent.spanContext.spanId.toString(),
      );
    });


    // TODO - this failes, make it test for a throw, add the throw first
    // test('validates parent-child relationships', () async {
    //   final rootContext = Context.root;
    //
    //   final parent = tracer.startSpan('parent', context: rootContext);
    //   final parentContext = rootContext.withSpanContext(parent.spanContext);
    //   final child = tracer.startSpan('child', context: parentContext);
    //
    //   child.end();
    //   parent.end();
    //
    //   print('Waiting for parent-child spans...');
    //   await collector.waitForSpans(2);
    //
    //   collector.assertSpanExists(
    //     name: 'child',
    //     parentSpanId: parent.spanContext.spanId.toString(),
    //   );
    // });

    test('validates span status', () async {
      tracer.startSpan('error-span')
        ..setStatus(SpanStatusCode.Error, 'Something went wrong')
        ..end();

      print('Waiting for error span...');
      await collector.waitForSpans(1);

      collector.assertSpanExists(
        name: 'error-span',
        status: proto.Status_StatusCode.STATUS_CODE_ERROR,
        statusMessage: 'Something went wrong',
      );
    });
  });
}
