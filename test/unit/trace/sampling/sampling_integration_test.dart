// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('Sampling Integration', () {
    // Setup before all tests in the group
    setUpAll(() async {
      await OTel.reset();
    });
    
    setUp(() async {
      // This will create a fresh OTel instance before each test
      await OTel.reset();
    });

    // Ensure cleanup after each test
    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
      // Add a small delay to allow for proper cleanup
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    
    // Ensure final cleanup
    tearDownAll(() async {
      await OTel.reset();
      // Add a delay to ensure everything is cleaned up
      await Future<void>.delayed(const Duration(seconds: 1));
    });

    test('sampling configuration is inherited through the hierarchy', () async {
      // Initialize with no endpoint to avoid collector communication
      await OTel.initialize(
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
      
      // End spans to release resources
      defaultSpan.end();
      customSpan.end();
    });

    test('tracer can override provider sampler', () async {
      await OTel.initialize(
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
      
      // End span to release resources
      span.end();
    });

    test('parent sampling decision is respected', () async {
      await OTel.initialize(
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
      
      // End spans to release resources
      child.end();
      parent.end();
    });
  });
}
