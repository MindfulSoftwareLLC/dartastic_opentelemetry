// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Example demonstrating W3C Trace Context Propagator usage
///
/// This example shows how to use the W3CTraceContextPropagator and
/// W3CBaggagePropagator to propagate trace context across service boundaries.
///
/// Run this example:
/// ```
/// dart run example/propagator_example.dart
/// ```
library;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

void main() async {
  await OTel.initialize(
    serviceName: 'propagator-example',
    endpoint: 'http://localhost:4317',
  );

  print('=== W3C Trace Context Propagator Example ===\n');

  // Create a composite propagator that handles both trace context and baggage
  final propagator = CompositePropagator<Map<String, String>, String>([
    W3CTraceContextPropagator(),
    W3CBaggagePropagator(),
  ]);

  print('1. Creating a span with trace context...');
  // Per the OTel spec, tracer.startSpan() does NOT activate the span.
  // Build the Context to inject directly from the span's SpanContext.
  // To make the span active for downstream code, wrap that code in
  // tracer.withSpan / withSpanAsync.
  final span = OTel.tracer().startSpan('parent-operation');
  try {
    final baggage =
        OTel.baggage({UserSemantics.userId.key: OTel.baggageEntry('user123')});
    final contextWithBaggage =
        OTel.context(spanContext: span.spanContext).withBaggage(baggage);

    print('   TraceId: ${span.spanContext.traceId.hexString}');
    print('   SpanId: ${span.spanContext.spanId.hexString}');
    print(
        '   Baggage: user.id=${baggage.getValue(UserSemantics.userId.key)}\n');

    // === INJECT: Outgoing Request ===
    print('2. Injecting trace context into HTTP headers (simulated)...');
    final carrier = <String, String>{};
    final setter = MapTextMapSetter(carrier);

    propagator.inject(contextWithBaggage, carrier, setter);

    print('   Injected headers:');
    carrier.forEach((key, value) {
      print('     $key: $value');
    });

    // === EXTRACT: Incoming Request ===
    print('3. Extracting trace context from HTTP headers (simulated)...');
    final getter = MapTextMapGetter(carrier);
    final extractedContext =
        propagator.extract(OTel.context(), carrier, getter);

    final extractedSpanContext = extractedContext.spanContext;
    final extractedBaggage = extractedContext.baggage;

    print('   Extracted:');
    print('     TraceId: ${extractedSpanContext?.traceId.hexString}');
    print('     SpanId: ${extractedSpanContext?.spanId.hexString}');
    print('     IsRemote: ${extractedSpanContext?.isRemote}');
    print('     Sampled: ${extractedSpanContext?.traceFlags.isSampled}');
    print(
        '     Baggage: user.id=${extractedBaggage?.getValue(UserSemantics.userId.key)}\n');

    // === Verify Round-Trip ===
    print('4. Verifying round-trip...');
    final sameTraceId = span.spanContext.traceId.hexString ==
        extractedSpanContext?.traceId.hexString;
    final sameSpanId = span.spanContext.spanId.hexString ==
        extractedSpanContext?.spanId.hexString;
    final sameBaggage = baggage.getValue(UserSemantics.userId.key) ==
        extractedBaggage?.getValue(UserSemantics.userId.key);

    print('   ✓ TraceId preserved: $sameTraceId');
    print('   ✓ SpanId preserved: $sameSpanId');
    print('   ✓ Baggage preserved: $sameBaggage');
    print(
      '   ✓ IsRemote set correctly: ${extractedSpanContext?.isRemote == true}\n',
    );

    // === Create Child Span in Extracted Context ===
    print('5. Creating child span in extracted context...');
    await extractedContext.run(() async {
      // run() activates extractedContext via Zone, so the new span is
      // parented to the extracted SpanContext.
      final childSpan = OTel.tracer().startSpan('child-operation');
      try {
        print(
            '   Child TraceId:        ${childSpan.spanContext.traceId.hexString}');
        print(
            '   Child SpanId:         ${childSpan.spanContext.spanId.hexString}');
        print(
          '   Child parentSpanId:   ${childSpan.spanContext.parentSpanId?.hexString}',
        );
        print(
          '   Child Baggage:        ${UserSemantics.userId.key}=${Context.current.baggage?.getValue(UserSemantics.userId.key)}',
        );
        print(
          '   → Same TraceId as parent: ${childSpan.spanContext.traceId.hexString == extractedSpanContext?.traceId.hexString}',
        );
        print(
          '   → ParentSpanId matches:   ${childSpan.spanContext.parentSpanId?.hexString == extractedSpanContext?.spanId.hexString}\n',
        );
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

    // === Show Fields ===
    print('6. Propagator fields:');
    propagator.fields().forEach((field) {
      print('   - $field');
    });

    print('\n=== Example Complete ===');
    print('This demonstrates how trace context flows between services!');
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    span.recordException(e, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.Error, e.toString());
  } finally {
    span.end();
    await OTel.shutdown();
  }
}

/// Helper class for setting values in a Map carrier
class MapTextMapSetter implements TextMapSetter<String> {
  final Map<String, String> _map;

  MapTextMapSetter(this._map);

  @override
  void set(String key, String value) {
    _map[key] = value;
  }
}

/// Helper class for getting values from a Map carrier
class MapTextMapGetter implements TextMapGetter<String> {
  final Map<String, String> _map;

  MapTextMapGetter(this._map);

  @override
  String? get(String key) => _map[key];

  @override
  Iterable<String> keys() => _map.keys;
}
