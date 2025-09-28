// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

class MockSpanProcessor implements SpanProcessor {
  bool _isShutdown = false;
  bool _forceFlushCalled = false;
  bool _shouldThrow = false;

  @override
  Future<void> shutdown() async {
    if (_shouldThrow) {
      throw Exception('Mock exception during shutdown');
    }
    _isShutdown = true;
  }

  bool get isShutdown => _isShutdown;

  @override
  Future<void> forceFlush() async {
    if (_shouldThrow) {
      throw Exception('Mock exception during force flush');
    }
    _forceFlushCalled = true;
  }

  bool get forceFlushCalled => _forceFlushCalled;

  @override
  Future<void> onEnd(Span span) async {
    // Not used in test
  }

  @override
  Future<void> onStart(Span span, Context? parentContext) {
    // Not used in test
    throw UnimplementedError();
  }

  void setShouldThrow(bool value) {
    _shouldThrow = value;
  }

  @override
  Future<void> onNameUpdate(Span span, String newName) {
    // TODO: implement onNameUpdate
    throw UnimplementedError();
  }
}

void main() {
  group('TracerProvider Tests', () {
    late TracerProvider tracerProvider;
    late MockSpanProcessor mockProcessor1;
    late MockSpanProcessor mockProcessor2;

    setUp(() async {
      await OTel.reset();

      // Initialize OTel
      await OTel.initialize(
        serviceName: 'tracer-provider-test-service',
        detectPlatformResources: false,
      );

      tracerProvider = OTel.tracerProvider();
      mockProcessor1 = MockSpanProcessor();
      mockProcessor2 = MockSpanProcessor();

      // Add our test processors
      tracerProvider.addSpanProcessor(mockProcessor1);
      tracerProvider.addSpanProcessor(mockProcessor2);
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('TracerProvider properties reflect API delegate', () {
      // Set properties
      tracerProvider.endpoint = 'https://test-endpoint';
      tracerProvider.serviceName = 'updated-service-name';
      tracerProvider.serviceVersion = '1.2.3';
      tracerProvider.enabled = false;

      // Verify properties
      expect(tracerProvider.endpoint, equals('https://test-endpoint'));
      expect(tracerProvider.serviceName, equals('updated-service-name'));
      expect(tracerProvider.serviceVersion, equals('1.2.3'));
      expect(tracerProvider.enabled, isFalse);

      // Reset enabled back to true for other tests
      tracerProvider.enabled = true;
    });

    test('TracerProvider returns same tracer for same configuration', () {
      final tracer1 = tracerProvider.getTracer('test-tracer');
      final tracer2 = tracerProvider.getTracer('test-tracer');
      final tracer3 = tracerProvider.getTracer('different-tracer');

      // Same name should return same tracer
      expect(identical(tracer1, tracer2), isTrue);

      // Different name should return different tracer
      expect(identical(tracer1, tracer3), isFalse);
    });

    test('addSpanProcessor adds processors to list', () {
      // Get the initial count (there might be default processors from OTel.initialize)
      final initialCount = tracerProvider.spanProcessors.length;

      // Add another processor
      final mockProcessor3 = MockSpanProcessor();
      tracerProvider.addSpanProcessor(mockProcessor3);

      // Should now have one more processor
      expect(tracerProvider.spanProcessors.length, equals(initialCount + 1));

      // Verify our test processors are in the list
      expect(tracerProvider.spanProcessors, contains(mockProcessor1));
      expect(tracerProvider.spanProcessors, contains(mockProcessor2));
      expect(tracerProvider.spanProcessors, contains(mockProcessor3));
    });

    test('spanProcessors returns unmodifiable list', () {
      final processors = tracerProvider.spanProcessors;

      // Try to modify the list - should throw UnsupportedError
      expect(() => processors.add(MockSpanProcessor()), throwsUnsupportedError);
    });

    test('ensureResourceIsSet sets resource if null', () {
      // Initially resource is default from OTel.initialize
      expect(tracerProvider.resource, isNotNull);

      // Set resource to null
      tracerProvider.resource = null;
      expect(tracerProvider.resource, isNull);

      // Call ensureResourceIsSet
      tracerProvider.ensureResourceIsSet();

      // Resource should now be set to default
      expect(tracerProvider.resource, isNotNull);
      expect(tracerProvider.resource, equals(OTel.defaultResource));
    });

    test('shutdown calls shutdown on all span processors', () async {
      // Initially not shut down
      expect(tracerProvider.isShutdown, isFalse);
      expect(mockProcessor1.isShutdown, isFalse);
      expect(mockProcessor2.isShutdown, isFalse);

      // Shut down
      await tracerProvider.shutdown();

      // All should be shut down
      expect(tracerProvider.isShutdown, isTrue);
      expect(mockProcessor1.isShutdown, isTrue);
      expect(mockProcessor2.isShutdown, isTrue);
    });

    test('shutdown handles processor exceptions', () async {
      // Make one processor throw
      mockProcessor1.setShouldThrow(true);

      // Shutdown should still complete
      await tracerProvider.shutdown();

      // Provider should be shut down
      expect(tracerProvider.isShutdown, isTrue);

      // The processor that didn't throw should be shut down
      expect(mockProcessor2.isShutdown, isTrue);
    });

    test('forceFlush calls forceFlush on all span processors', () async {
      // Initially not called
      expect(mockProcessor1.forceFlushCalled, isFalse);
      expect(mockProcessor2.forceFlushCalled, isFalse);

      // Force flush
      await tracerProvider.forceFlush();

      // Should be called on both
      expect(mockProcessor1.forceFlushCalled, isTrue);
      expect(mockProcessor2.forceFlushCalled, isTrue);
    });

    test('forceFlush handles processor exceptions', () async {
      // Make one processor throw
      mockProcessor1.setShouldThrow(true);

      // Force flush should still complete
      await tracerProvider.forceFlush();

      // The processor that didn't throw should be flushed
      expect(mockProcessor2.forceFlushCalled, isTrue);
    });

    test('forceFlush does nothing when provider is shut down', () async {
      // Shut down the provider
      await tracerProvider.shutdown();

      // Reset processor state to verify they aren't called again
      mockProcessor1._forceFlushCalled = false;
      mockProcessor2._forceFlushCalled = false;

      // Force flush on shut down provider
      await tracerProvider.forceFlush();

      // Processors should not be called again
      expect(mockProcessor1.forceFlushCalled, isFalse);
      expect(mockProcessor2.forceFlushCalled, isFalse);
    });

    test('second shutdown call does nothing', () async {
      // First shutdown
      await tracerProvider.shutdown();
      expect(tracerProvider.isShutdown, isTrue);

      // Reset processor state to verify they aren't called again
      mockProcessor1._isShutdown = false;
      mockProcessor2._isShutdown = false;

      // Second shutdown should be a no-op
      await tracerProvider.shutdown();

      // Provider should still be shut down but processors shouldn't be called again
      expect(tracerProvider.isShutdown, isTrue);
      expect(mockProcessor1.isShutdown, isFalse);
      expect(mockProcessor2.isShutdown, isFalse);
    });

    test('getTracer throws when provider is shut down', () async {
      // Shut down the provider
      await tracerProvider.shutdown();

      // Trying to get a tracer should throw
      expect(() => tracerProvider.getTracer('test-tracer'), throwsStateError);
    });

    test('addSpanProcessor throws when provider is shut down', () async {
      // Shut down the provider
      await tracerProvider.shutdown();

      // Trying to add a processor should throw
      expect(() => tracerProvider.addSpanProcessor(MockSpanProcessor()),
          throwsStateError);
    });

    test('resource can be set and retrieved', () {
      final newResource =
          OTel.resource({'custom.key': 'custom.value'}.toAttributes());

      tracerProvider.resource = newResource;
      expect(tracerProvider.resource, equals(newResource));
    });
  });
}
