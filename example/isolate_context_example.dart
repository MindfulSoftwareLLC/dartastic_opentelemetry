// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

Future<void> main() async {
  await OTel.initialize();
  final tracerProvider = OTel.tracerProvider();
  final tracer = tracerProvider.getTracer('isolate-context-example');
  // Create a span in the main isolate
  final mainSpan = tracer.startSpan('main-operation');

  try {
    // Run a computation in a new isolate while preserving context
    final result = await Context.current.runIsolate( () async {
      // The context is automatically restored in the new isolate
      final isolateSpan = tracer.startSpan(
        'isolate-operation',
        // The parent span context is preserved across the isolate boundary
      );

      try {
        // Do some work
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return 'Success';
      } finally {
        isolateSpan.end();
      }
    });

    print('Isolate returned: $result');
  } finally {
    mainSpan.end();
  }
}

/// Example async function demonstrating zone-based context propagation
Future<void> zoneExample() async {
  final tracerProvider = OTel.tracerProvider();
  final tracer = tracerProvider.getTracer('isolate-context-example');

  final parentSpan = tracer.startSpan('parent-operation');

  try {
    // The context is automatically propagated through the async chain
    await Context.current.run(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Child span automatically gets the parent from the zone
      final childSpan = tracer.startSpan('child-operation');
      try {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      } finally {
        childSpan.end();
      }
    });
  } finally {
    parentSpan.end();
  }
}

/// Example showing sync context propagation
Future<void> syncExample() async {
  final tracerProvider = OTel.tracerProvider();
  final tracer = tracerProvider.getTracer('isolate-context-example');
  final parentSpan = tracer.startSpan('parent-operation');

  try {
    // Run synchronous code with context
    await Context.current.run(() async {
      // Child span gets parent from context
      final childSpan = tracer.startSpan('child-operation');
      try {
        // Do some work
      } finally {
        childSpan.end();
      }
    });
  } finally {
    parentSpan.end();
  }
}
