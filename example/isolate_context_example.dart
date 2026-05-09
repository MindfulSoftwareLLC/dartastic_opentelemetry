// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

Future<void> main() async {
  await OTel.initialize();
  final tracer = OTel.tracerProvider().getTracer('isolate-context-example');
  final mainSpan = tracer.startSpan('main-operation');
  final parentTraceId = mainSpan.spanContext.traceId.hexString;
  final parentSpanId = mainSpan.spanContext.spanId.hexString;

  try {
    // Activate mainSpan for the scope so its SpanContext is in Context.current
    // and gets serialized into the new isolate (built-in span keys always
    // transfer across isolate boundaries).
    await tracer.withSpanAsync(mainSpan, () async {
      final isolateChild = await Context.current.runIsolate(() async {
        // The closure runs in a fresh isolate. Do NOT capture non-sendable
        // objects from the parent isolate (tracers, processors, etc.) —
        // re-acquire them here. The parent's SpanContext arrives via
        // Context.current and is marked isRemote=true on the receiving
        // side, so tracer.startSpan parents the new span to it.
        final isolateTracer =
            OTel.tracerProvider().getTracer('isolate-context-example');
        final isolateSpan = isolateTracer.startSpan('isolate-operation');
        try {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return {
            'traceId': isolateSpan.spanContext.traceId.hexString,
            'spanId': isolateSpan.spanContext.spanId.hexString,
            'parentSpanId': isolateSpan.spanContext.parentSpanId?.hexString,
          };
        } catch (e, stackTrace) {
          isolateSpan.recordException(e, stackTrace: stackTrace);
          isolateSpan.setStatus(SpanStatusCode.Error, e.toString());
          rethrow;
        } finally {
          isolateSpan.end();
        }
      });

      print('Parent  traceId:        $parentTraceId');
      print('Isolate traceId:        ${isolateChild['traceId']}');
      print('Parent  spanId:         $parentSpanId');
      print('Isolate parentSpanId:   ${isolateChild['parentSpanId']}');
      print('Isolate spanId:         ${isolateChild['spanId']}');
      print('Same trace:    ${isolateChild['traceId'] == parentTraceId}');
      print('Child of main: ${isolateChild['parentSpanId'] == parentSpanId}');
    });
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    mainSpan.recordException(e, stackTrace: stackTrace);
    mainSpan.setStatus(SpanStatusCode.Error, e.toString());
  } finally {
    mainSpan.end();
    await OTel.shutdown();
  }
}

/// Demonstrates Zone-based context propagation across async boundaries.
Future<void> zoneExample() async {
  final tracerProvider = OTel.tracerProvider();
  final tracer = tracerProvider.getTracer('isolate-context-example');

  final parentSpan = tracer.startSpan('parent-operation');
  try {
    // withSpanAsync attaches parentSpan via Zone for the entire async chain.
    await tracer.withSpanAsync(parentSpan, () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Child span automatically gets parentSpan via Context.current.
      final childSpan = tracer.startSpan('child-operation');
      try {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      } catch (e, stackTrace) {
        // The span has a status of SpanStatus.Ok on creation, set it to
        // Error when an error occurs in the span.
        childSpan.recordException(e, stackTrace: stackTrace);
        childSpan.setStatus(SpanStatusCode.Error, e.toString());
        rethrow;
      } finally {
        childSpan.end();
      }
    });
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    parentSpan.recordException(e, stackTrace: stackTrace);
    parentSpan.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    parentSpan.end();
  }
}

/// Demonstrates synchronous context propagation via withSpan.
void syncExample() {
  final tracerProvider = OTel.tracerProvider();
  final tracer = tracerProvider.getTracer('isolate-context-example');
  final parentSpan = tracer.startSpan('parent-operation');
  try {
    tracer.withSpan(parentSpan, () {
      final childSpan = tracer.startSpan('child-operation');
      try {
        // Do some work.
      } catch (e, stackTrace) {
        // The span has a status of SpanStatus.Ok on creation, set it to
        // Error when an error occurs in the span.
        childSpan.recordException(e, stackTrace: stackTrace);
        childSpan.setStatus(SpanStatusCode.Error, e.toString());
        rethrow;
      } finally {
        childSpan.end();
      }
    });
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    parentSpan.recordException(e, stackTrace: stackTrace);
    parentSpan.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    parentSpan.end();
  }
}
