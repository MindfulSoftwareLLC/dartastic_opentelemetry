// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/span_transformer.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';
import 'package:dartastic_opentelemetry/src/trace/tracer.dart';
import 'package:dartastic_opentelemetry/src/trace/tracer_provider.dart';
import 'package:test/test.dart';

void main() {
  TracerProvider? tracerProvider;
  Tracer? tracer;
  Tracer? httpTracer;
  Tracer? dbTracer;

  setUp(() async {
    await OTel.initialize();
    tracerProvider = OTel.tracerProvider();
    tracer = tracerProvider!.getTracer('test');
    // The default tracer is set up with an instrumentation scope, for example "http".
    httpTracer = tracerProvider!.getTracer('http');
    // To simulate a different instrumentation scope, we create a separate tracer.
    dbTracer = tracerProvider!.getTracer('database',
        version: '1.0.0',
        attributes: OTel.attributesFromMap(
          {'db_type': 'postgres'},
        ));
  });

  tearDown(() async {
    await OTel.reset();
  });

  group('OtlpSpanTransformer Performance', () {
    test('measures transformation performance for large batches', () {
      final spans = List<Span>.generate(
        10000,
        (i) => tracer!.startSpan(
          'span-$i',
          attributes: OTel.attributesFromMap({
            'attr1': 'value1',
            'attr2': i,
            'attr3': i % 2 == 0,
            'attr4': List.generate(5, (j) => 'value$j'),
          }),
        ),
      );

      final stopwatch = Stopwatch()..start();
      final request = OtlpSpanTransformer.transformSpans(spans);
      stopwatch.stop();

      print(
          'Transformation time for 10000 spans: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      expect(request.resourceSpans.first.scopeSpans.first.spans.length,
          equals(10000));
    });

    test('measures parallel transformation performance', () async {
      final numBatches = 5;
      final batchSize = 2000;
      final futures = List.generate(numBatches, (batchIndex) {
        return Future(() {
          final spans = List<Span>.generate(
            batchSize,
            (i) => tracer!.startSpan(
              'span-$batchIndex-$i',
              attributes: OTel.attributesFromMap({
                'batchId': batchIndex,
                'spanId': i,
                'data': List.generate(10, (j) => 'value$j'),
              }),
            ),
          );

          final stopwatch = Stopwatch()..start();
          final result = OtlpSpanTransformer.transformSpans(spans);
          stopwatch.stop();

          return {
            'batchIndex': batchIndex,
            'time': stopwatch.elapsedMilliseconds,
            'spans': result.resourceSpans.first.scopeSpans.first.spans.length,
          };
        });
      });

      final results = await Future.wait(futures);
      for (final result in results) {
        print('Batch ${result['batchIndex']}: ${result['time']}ms');
        expect(result['time'], lessThan(2000));
        expect(result['spans'], equals(batchSize));
      }
    });

    test('handles multiple instrumentation scopes', () {
      // Create one span from the default (http) tracer and one from the (database) tracer.
      final spanHttp = httpTracer!.startSpan('http-span');
      final spanDb = dbTracer!.startSpan('db-span');

      final spans = [spanHttp, spanDb];

      final request = OtlpSpanTransformer.transformSpans(spans);
      expect(request.resourceSpans.first.scopeSpans.length, equals(2));

      final scopeNames = request.resourceSpans.first.scopeSpans
          .map((s) => s.scope.name)
          .toList();
      expect(scopeNames, containsAll(['http', 'database']));
    });

    test('handles complex event transformation performance', () {
      final events = List.generate(
        1000,
        (i) => OTel.spanEvent(
          'event-$i',
          OTel.attributesFromMap({
            'attr1': 'value1',
            'attr2': i,
            'attr3': List.generate(5, (j) => j),
          }),
          DateTime.now().add(Duration(milliseconds: i)),
        ),
      );

      final span = tracer!.startSpan(
        'event-test',
      );

      for (final event in events) {
        span.addEvent(event);
      }

      final stopwatch = Stopwatch()..start();
      final request = OtlpSpanTransformer.transformSpans([span]);
      stopwatch.stop();

      print(
          'Complex event transformation time: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      final transformedSpan =
          request.resourceSpans.first.scopeSpans.first.spans.first;
      expect(transformedSpan.events.length, equals(1000));
    });
  });
}
