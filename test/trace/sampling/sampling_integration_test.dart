// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Sampling Integration', () {
    setUp(() async {
      //await OTel.initialize();
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('sampling configuration is inherited through the hierarchy', () async {
      // Initialize with default sampler
      await OTel.initialize(
        endpoint: 'http://localhost:4317',
        serviceName: 'test-service',
        sampler: const AlwaysOnSampler(),
      );

      // Get default tracer provider
      final defaultProvider = OTel.tracerProvider();
      expect(defaultProvider, isA<TracerProvider>());

      // Create a named tracer provider with a different sampler
      final customProvider = OTel.addTracerProvider(
        'custom',
        sampler: const AlwaysOffSampler(),
      );

      // Create tracers
      final defaultTracer = defaultProvider.getTracer('default');
      final customTracer = customProvider.getTracer('custom');

      // Verify default tracer inherits AlwaysOnSampler
      final defaultSpan = defaultTracer.startSpan('test-default');
      expect(defaultSpan.spanContext.traceFlags.isSampled, isTrue);

      // Verify custom tracer uses AlwaysOffSampler
      final customSpan = customTracer.startSpan('test-custom');
      expect(customSpan.spanContext.traceFlags.isSampled, isFalse);
    });

    test('tracer can override provider sampler', () async {
      await OTel.initialize(
        endpoint: 'http://localhost:4317',
        serviceName: 'test-service',
        sampler: const AlwaysOnSampler(),
      );

      final provider = OTel.tracerProvider();

      // Create tracer with custom sampler
      final tracer = provider.getTracer(
        'test',
        sampler: const AlwaysOffSampler(),
      );

      final span = tracer.startSpan('test');
      expect(span.spanContext.traceFlags.isSampled, isFalse);
    });

    test('parent sampling decision is respected', () async {
      await OTel.initialize(
        endpoint: 'http://localhost:4317',
        serviceName: 'test-service',
        sampler: ParentBasedSampler(const AlwaysOnSampler()),
      );

      final tracer = OTel.tracerProvider().getTracer('test');

      // Create parent span with AlwaysOnSampler
      final parent = tracer.startSpan('parent');
      expect(parent.spanContext.traceFlags.isSampled, isTrue);

      final parentContext = OTel.context().withSpan(parent);

      // Create child span - should inherit sampling decision
      final child = tracer.startSpan(
        'child',
        context: parentContext,
      );
      expect(child.spanContext.traceFlags.isSampled, isTrue);
    });
  });
}
