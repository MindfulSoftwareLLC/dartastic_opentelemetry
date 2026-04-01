// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Combined test file for OTel SDK initialization, configuration, factory
// methods, shutdown handling, and SimpleSpanProcessor error paths.
//
// Merged from:
//   - otel_coverage_test.dart
//   - otel_init_coverage_test.dart

import 'dart:typed_data';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

import '../testing_utils/in_memory_span_exporter.dart';

// ---------------------------------------------------------------------------
// Test doubles for SimpleSpanProcessor error-path testing
// ---------------------------------------------------------------------------

/// An exporter that throws on export (to trigger inner catch in onEnd).
class _ThrowingExportExporter implements SpanExporter {
  @override
  Future<void> export(List<Span> spans) async {
    throw Exception('export fail');
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

/// An exporter whose shutdown and forceFlush throw exceptions.
class _ErrorShutdownExporter implements SpanExporter {
  @override
  Future<void> export(List<Span> spans) async {}

  @override
  Future<void> forceFlush() async {
    throw Exception('flush fail');
  }

  @override
  Future<void> shutdown() async {
    throw Exception('shutdown fail');
  }
}

/// An exporter that throws a non-Exception (e.g., a String) to trigger the
/// outer catch block in onEnd (lines 97-103).
class _NonStandardThrowExporter implements SpanExporter {
  @override
  Future<void> export(List<Span> spans) {
    // Throw a non-Exception type to bypass the inner catch
    throw 'non-standard error';
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

void main() {
  // =========================================================================
  // Tests from otel_init_coverage_test.dart
  // =========================================================================
  group('OTel.initialize options', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test('initialize with tenantId sets tenant_id in resource', () async {
      await OTel.initialize(
        serviceName: 'tenant-test-service',
        serviceVersion: '1.0.0',
        tenantId: 'test-tenant',
        detectPlatformResources: false,
        enableMetrics: false,
      );

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();
      final tenantAttr = attrs.firstWhere(
        (a) => a.key == 'tenant_id',
        orElse: () => throw StateError('tenant_id attribute not found'),
      );
      expect(tenantAttr.value, equals('test-tenant'));
    });

    test('initialize with resourceAttributes merges attributes', () async {
      final resourceAttrs = OTel.attributesFromMap({
        'custom.attr': 'custom-value',
        'deployment.environment': 'testing',
      });

      await OTel.initialize(
        serviceName: 'resource-attrs-service',
        serviceVersion: '1.0.0',
        resourceAttributes: resourceAttrs,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();

      final customAttr = attrs.firstWhere(
        (a) => a.key == 'custom.attr',
        orElse: () => throw StateError('custom.attr attribute not found'),
      );
      expect(customAttr.value, equals('custom-value'));

      final envAttr = attrs.firstWhere(
        (a) => a.key == 'deployment.environment',
        orElse: () =>
            throw StateError('deployment.environment attribute not found'),
      );
      expect(envAttr.value, equals('testing'));
    });

    test('initialize with detectPlatformResources=true detects platform',
        () async {
      await OTel.initialize(
        serviceName: 'platform-detect-service',
        serviceVersion: '1.0.0',
        detectPlatformResources: true,
        enableMetrics: false,
      );

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();
      final attrKeys = attrs.map((a) => a.key).toList();

      // Platform detection should add at least some platform-related attributes
      // On a Dart VM, host.name or process.runtime.name are typically detected
      final hasPlatformAttrs = attrKeys.any(
        (key) =>
            key.startsWith('host.') ||
            key.startsWith('process.') ||
            key.startsWith('os.') ||
            key.startsWith('telemetry.'),
      );
      expect(hasPlatformAttrs, isTrue,
          reason:
              'Platform resource detection should add platform-related attributes');
    });

    test('initialize with tenantId and resourceAttributes', () async {
      final resourceAttrs = OTel.attributesFromMap({
        'custom.key': 'custom-value',
      });

      await OTel.initialize(
        serviceName: 'combined-test-service',
        serviceVersion: '1.0.0',
        tenantId: 'test-tenant',
        resourceAttributes: resourceAttrs,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();

      final tenantAttr = attrs.firstWhere(
        (a) => a.key == 'tenant_id',
        orElse: () => throw StateError('tenant_id attribute not found'),
      );
      expect(tenantAttr.value, equals('test-tenant'));

      final customAttr = attrs.firstWhere(
        (a) => a.key == 'custom.key',
        orElse: () => throw StateError('custom.key attribute not found'),
      );
      expect(customAttr.value, equals('custom-value'));

      final serviceAttr = attrs.firstWhere(
        (a) => a.key == 'service.name',
        orElse: () => throw StateError('service.name attribute not found'),
      );
      expect(serviceAttr.value, equals('combined-test-service'));
    });

    test('initialize throws if called twice', () async {
      await OTel.initialize(
        serviceName: 'first-init',
        serviceVersion: '1.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );

      // Do NOT reset between inits -- should throw StateError
      expect(
        () => OTel.initialize(
          serviceName: 'second-init',
          serviceVersion: '1.0.0',
          detectPlatformResources: false,
          enableMetrics: false,
        ),
        throwsStateError,
      );
    });

    test('initialize with custom tracerName and tracerVersion', () async {
      await OTel.initialize(
        serviceName: 'tracer-name-service',
        serviceVersion: '1.0.0',
        tracerName: 'my-custom-tracer',
        tracerVersion: '2.5.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );

      expect(OTel.defaultTracerName, equals('my-custom-tracer'));
      expect(OTel.defaultTracerVersion, equals('2.5.0'));
    });
  });

  group('OTel static factory methods', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'factory-test-service',
        serviceVersion: '1.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test('attributeStringList creates list attribute', () {
      final attr = OTel.attributeStringList('k', ['a', 'b']);
      expect(attr.key, equals('k'));
      expect(attr.value, equals(['a', 'b']));
      expect(attr, isA<Attribute<List<String>>>());
    });

    test('attributeBoolList creates list attribute', () {
      final attr = OTel.attributeBoolList('k', [true, false]);
      expect(attr.key, equals('k'));
      expect(attr.value, equals([true, false]));
      expect(attr, isA<Attribute<List<bool>>>());
    });

    test('attributeIntList creates list attribute', () {
      final attr = OTel.attributeIntList('k', [1, 2]);
      expect(attr.key, equals('k'));
      expect(attr.value, equals([1, 2]));
      expect(attr, isA<Attribute<List<int>>>());
    });

    test('attributeDoubleList creates list attribute', () {
      final attr = OTel.attributeDoubleList('k', [1.0, 2.0]);
      expect(attr.key, equals('k'));
      expect(attr.value, equals([1.0, 2.0]));
      expect(attr, isA<Attribute<List<double>>>());
    });

    test('attributeDouble creates attribute', () {
      final attr = OTel.attributeDouble('k', 1.5);
      expect(attr.key, equals('k'));
      expect(attr.value, equals(1.5));
      expect(attr, isA<Attribute<double>>());
    });

    test('createAttributes creates empty attributes', () {
      final attrs = OTel.createAttributes();
      expect(attrs, isNotNull);
      expect(attrs.toList(), isEmpty);
    });

    test('spanEventNow creates event with current time', () {
      final attrs = OTel.attributesFromMap({'event.key': 'event-value'});
      final before = DateTime.now();
      final event = OTel.spanEventNow('test', attrs);
      final after = DateTime.now();

      expect(event.name, equals('test'));
      expect(event.attributes, isNotNull);
      // The timestamp should be between before and after
      expect(event.timestamp.millisecondsSinceEpoch,
          greaterThanOrEqualTo(before.millisecondsSinceEpoch));
      expect(event.timestamp.millisecondsSinceEpoch,
          lessThanOrEqualTo(after.millisecondsSinceEpoch));
    });

    test('spanEvent creates event', () {
      final attrs = OTel.attributesFromMap({'event.key': 'event-value'});
      final timestamp = DateTime(2025, 6, 15, 12, 0, 0);
      final event = OTel.spanEvent('test', attrs, timestamp);

      expect(event.name, equals('test'));
      expect(event.attributes, isNotNull);
      expect(event.timestamp, equals(timestamp));
    });

    test('baggageForMap creates baggage', () {
      final baggage = OTel.baggageForMap({'k': 'v'});
      expect(baggage, isNotNull);
      final entry = baggage.getEntry('k');
      expect(entry, isNotNull);
      expect(entry!.value, equals('v'));
    });

    test('baggageEntry creates entry', () {
      final entry = OTel.baggageEntry('value', 'metadata');
      expect(entry, isNotNull);
      expect(entry.value, equals('value'));
      expect(entry.metadata, equals('metadata'));
    });

    test('baggage creates empty baggage', () {
      final bag = OTel.baggage();
      expect(bag, isNotNull);
      expect(bag.isEmpty, isTrue);
    });

    test('baggageFromJson creates baggage', () {
      final bag = OTel.baggageFromJson({'entries': <String, dynamic>{}});
      expect(bag, isNotNull);
    });

    test('attributesFromList creates from list', () {
      final attr1 = OTel.attributeString('key1', 'value1');
      final attr2 = OTel.attributeInt('key2', 42);
      final attrs = OTel.attributesFromList([attr1, attr2]);

      expect(attrs, isNotNull);
      final attrList = attrs.toList();
      expect(attrList.length, equals(2));
      expect(
          attrList.any((a) => a.key == 'key1' && a.value == 'value1'), isTrue);
      expect(attrList.any((a) => a.key == 'key2' && a.value == 42), isTrue);
    });

    test('spanContextInvalid returns invalid context', () {
      final ctx = OTel.spanContextInvalid();
      expect(ctx, isNotNull);
      expect(ctx.isValid, isFalse);
    });
  });

  group('TracerProvider', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'provider-test-service',
        serviceVersion: '1.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test('addTracerProvider creates named provider', () {
      final provider = OTel.addTracerProvider('custom',
          serviceName: 'custom-service', serviceVersion: '2.0.0');

      expect(provider, isNotNull);
      expect(provider, isA<TracerProvider>());
      expect(provider.resource, isNotNull);
    });

    test('tracerProviders returns all providers', () {
      // There should be at least the default provider
      final providersBefore = OTel.tracerProviders();
      final countBefore = providersBefore.length;

      // Add a named provider
      OTel.addTracerProvider('custom-named');

      final providersAfter = OTel.tracerProviders();
      expect(providersAfter.length, equals(countBefore + 1));
    });

    test('tracerProvider with null resource gets default', () {
      final provider = OTel.tracerProvider();
      expect(provider, isNotNull);
      expect(provider.resource, isNotNull);
      expect(provider.resource, equals(OTel.defaultResource));
    });
  });

  group('OTel.shutdown (init)', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test('shutdown completes gracefully', () async {
      await OTel.initialize(
        serviceName: 'shutdown-test-service',
        serviceVersion: '1.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );

      // Shutdown should complete without throwing
      await OTel.shutdown();
    });

    test('shutdown and reset allow reinitialize', () async {
      await OTel.initialize(
        serviceName: 'first-service',
        serviceVersion: '1.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );

      expect(OTel.defaultResource, isNotNull);

      await OTel.shutdown();
      await OTel.reset();

      // Should be able to reinitialize after shutdown and reset
      await OTel.initialize(
        serviceName: 'second-service',
        serviceVersion: '2.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();
      final serviceAttr = attrs.firstWhere(
        (a) => a.key == 'service.name',
        orElse: () => throw StateError('service.name attribute not found'),
      );
      expect(serviceAttr.value, equals('second-service'));
    });
  });

  // =========================================================================
  // Tests from otel_coverage_test.dart
  // =========================================================================
  group('OTel.initialize with env resource attributes', () {
    setUp(() async {
      await OTel.reset();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = (_) {};
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
      OTelLog.logFunction = null;
    });

    test('initialize with detectPlatformResources true detects platform',
        () async {
      // This covers the detectPlatformResources=true branch
      await OTel.initialize(
        serviceName: 'platform-test',
        serviceVersion: '1.0.0',
        detectPlatformResources: true,
        enableMetrics: false,
      );

      expect(OTel.defaultResource, isNotNull);
      final attrs = OTel.defaultResource!.attributes.toList();
      final attrKeys = attrs.map((a) => a.key).toList();

      // Platform detection should add at least some platform-related attributes
      final hasPlatformAttrs = attrKeys.any(
        (key) =>
            key.startsWith('host.') ||
            key.startsWith('process.') ||
            key.startsWith('os.') ||
            key.startsWith('telemetry.'),
      );
      expect(hasPlatformAttrs, isTrue);
    });

    test('initialize with custom spanProcessor skips env exporter creation',
        () async {
      // Providing a spanProcessor directly bypasses lines 297-378 (exporter
      // creation from env vars). This verifies the provided-processor path
      // works and no env-based exporter is created.
      final exporter = InMemorySpanExporter();
      final processor = SimpleSpanProcessor(exporter);

      await OTel.initialize(
        serviceName: 'custom-processor',
        serviceVersion: '1.0.0',
        spanProcessor: processor,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      // Create and end a span to verify processor is wired up
      final tracer = OTel.tracer();
      final span = tracer.startSpan('test-span');
      span.end();

      // Give the processor time to export
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(exporter.hasSpanWithName('test-span'), isTrue);
    });

    test('initialize with console exporter via env (spanProcessor=none path)',
        () async {
      // When we provide a spanProcessor, it bypasses the exporter creation.
      // Test that initialization completes with the 'none' exporter type
      // when we provide our own processor.
      final exporter = InMemorySpanExporter();
      final processor = SimpleSpanProcessor(exporter);

      await OTel.initialize(
        serviceName: 'console-export-test',
        serviceVersion: '1.0.0',
        spanProcessor: processor,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      expect(OTel.tracerProvider(), isNotNull);
    });
  });

  group('OTel factory methods coverage', () {
    setUp(() async {
      await OTel.reset();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = (_) {};
      final exporter = InMemorySpanExporter();
      await OTel.initialize(
        serviceName: 'factory-methods-test',
        serviceVersion: '1.0.0',
        spanProcessor: SimpleSpanProcessor(exporter),
        detectPlatformResources: false,
        enableMetrics: true,
      );
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
      OTelLog.logFunction = null;
    });

    test('attributes() with factory initialized uses factory path', () {
      // Covers line 812: factory exists path in attributes()
      final attrs = OTel.attributes();
      expect(attrs, isNotNull);
      expect(attrs.toList(), isEmpty);

      // Also with entries
      final attr = OTel.attributeString('key', 'value');
      final attrsWithEntries = OTel.attributes([attr]);
      expect(attrsWithEntries.toList().length, equals(1));
    });

    test('traceIdOf throws for wrong length', () {
      // Covers lines 885-886
      expect(
        () => OTel.traceIdOf(Uint8List(5)),
        throwsArgumentError,
      );
    });

    test('traceIdOf works with correct length', () {
      // Covers traceIdOf normal path
      final bytes = Uint8List(16);
      for (var i = 0; i < 16; i++) {
        bytes[i] = i + 1;
      }
      final traceId = OTel.traceIdOf(bytes);
      expect(traceId, isNotNull);
    });

    test('spanIdOf throws for wrong length', () {
      // Covers lines 921-922
      expect(
        () => OTel.spanIdOf(Uint8List(3)),
        throwsArgumentError,
      );
    });

    test('spanIdOf works with correct length', () {
      // Covers spanIdOf normal path
      final bytes = Uint8List(8);
      for (var i = 0; i < 8; i++) {
        bytes[i] = i + 1;
      }
      final spanId = OTel.spanIdOf(bytes);
      expect(spanId, isNotNull);
    });

    test('meterProviders returns list', () {
      final providers = OTel.meterProviders();
      expect(providers, isA<List<dynamic>>());
    });
  });

  group('OTel uninitialized state', () {
    setUp(() async {
      await OTel.reset();
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
    });

    test('_getAndCacheOtelFactory throws when not initialized', () {
      // Covers line 964: StateError('initialize() must be called first.')
      expect(
        () => OTel.contextKey<String>('test-key'),
        throwsStateError,
      );
    });
  });

  group('OTel.shutdown error handling', () {
    setUp(() async {
      await OTel.reset();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = (_) {};
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
      OTelLog.logFunction = null;
    });

    test('shutdown completes gracefully with debug logging', () async {
      // Covers lines 999-1017, 1033-1034: shutdown with debug logging
      final exporter = InMemorySpanExporter();
      await OTel.initialize(
        serviceName: 'shutdown-debug-test',
        serviceVersion: '1.0.0',
        spanProcessor: SimpleSpanProcessor(exporter),
        detectPlatformResources: false,
        enableMetrics: true,
      );

      // Create a span to have something in the pipeline
      final tracer = OTel.tracer();
      final span = tracer.startSpan('shutdown-span');
      span.end();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Shutdown with debug logging enabled
      await OTel.shutdown();

      // Should complete without throwing
    });

    test('shutdown then reset allows reinitialization', () async {
      // This exercises both shutdown and reset paths fully
      await OTel.initialize(
        serviceName: 'first',
        serviceVersion: '1.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );

      await OTel.shutdown();
      await OTel.reset();

      // Line 1065: if OTelAPI.reset() throws, it's caught
      // Reinitialize should work
      await OTel.initialize(
        serviceName: 'second',
        serviceVersion: '2.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
      );

      expect(OTel.defaultResource, isNotNull);
    });
  });

  group('SimpleSpanProcessor error paths', () {
    setUp(() async {
      await OTel.reset();
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = (_) {};
    });

    tearDown(() async {
      try {
        await OTel.shutdown();
      } catch (_) {}
      await OTel.reset();
      OTelLog.logFunction = null;
    });

    test('onEnd with span that has no endTime logs warning', () async {
      // Covers lines 47-49: warn log when span has no endTime
      final logMessages = <String>[];
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logMessages.add;

      final exporter = InMemorySpanExporter();
      final processor = SimpleSpanProcessor(exporter);

      await OTel.initialize(
        serviceName: 'no-endtime-test',
        serviceVersion: '1.0.0',
        spanProcessor: processor,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      final tracer = OTel.tracer();
      final span = tracer.startSpan('no-end-span');
      // Do NOT call span.end() - directly call processor.onEnd
      await processor.onEnd(span);

      // The warning should have been logged
      final hasWarning = logMessages.any(
        (msg) => msg.contains('has no end time'),
      );
      expect(hasWarning, isTrue,
          reason: 'Should warn about span with no end time');
    });

    test('onEnd with throwing exporter catches export error', () async {
      // Covers inner catch at lines 84-89 (export error)
      final logMessages = <String>[];
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logMessages.add;

      final exporter = _ThrowingExportExporter();
      final processor = SimpleSpanProcessor(exporter);

      await OTel.initialize(
        serviceName: 'throw-export-test',
        serviceVersion: '1.0.0',
        spanProcessor: processor,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      final tracer = OTel.tracer();
      final span = tracer.startSpan('failing-span');
      span.end();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should have logged the export error
      final hasError = logMessages.any(
        (msg) => msg.contains('Export error') || msg.contains('export fail'),
      );
      expect(hasError, isTrue,
          reason: 'Should log export error from throwing exporter');
    });

    test('onEnd with non-standard throw hits outer catch', () async {
      // Covers lines 98-101: outer catch block in onEnd
      final logMessages = <String>[];
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logMessages.add;

      final exporter = _NonStandardThrowExporter();
      final processor = SimpleSpanProcessor(exporter);

      await OTel.initialize(
        serviceName: 'non-standard-throw-test',
        serviceVersion: '1.0.0',
        spanProcessor: processor,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      final tracer = OTel.tracer();
      final span = tracer.startSpan('outer-catch-span');
      // Call processor.onEnd directly to control the flow
      await processor.onEnd(span);

      // The outer catch should have logged
      final hasOuterError = logMessages.any(
        (msg) =>
            msg.contains('Failed to start export') ||
            msg.contains('non-standard error'),
      );
      expect(hasOuterError, isTrue,
          reason: 'Should log outer catch error for non-standard throw');
    });

    test('shutdown with failing exporter shutdown logs error', () async {
      // Covers lines 159-161: error log during exporter shutdown failure
      final logMessages = <String>[];
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logMessages.add;

      final exporter = _ErrorShutdownExporter();
      final processor = SimpleSpanProcessor(exporter);

      await OTel.initialize(
        serviceName: 'shutdown-fail-test',
        serviceVersion: '1.0.0',
        spanProcessor: processor,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      // Shutdown the processor - the exporter shutdown will throw
      await processor.shutdown();

      final hasShutdownError = logMessages.any(
        (msg) =>
            msg.contains('Error shutting down exporter') ||
            msg.contains('shutdown fail'),
      );
      expect(hasShutdownError, isTrue,
          reason: 'Should log exporter shutdown error');
    });

    test('forceFlush with failing exporter logs error', () async {
      // Covers lines 219-221: error log in forceFlush
      final logMessages = <String>[];
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logMessages.add;

      final exporter = _ErrorShutdownExporter();
      final processor = SimpleSpanProcessor(exporter);

      await OTel.initialize(
        serviceName: 'flush-fail-test',
        serviceVersion: '1.0.0',
        spanProcessor: processor,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      // forceFlush will call exporter.forceFlush() which throws
      await processor.forceFlush();

      final hasFlushError = logMessages.any(
        (msg) =>
            msg.contains('Error during force flush') ||
            msg.contains('flush fail'),
      );
      expect(hasFlushError, isTrue, reason: 'Should log forceFlush error');
    });

    test('shutdown after processing span with already-shutdown state',
        () async {
      // Covers lines 36-42: skipping export when processor is shutdown
      final logMessages = <String>[];
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logMessages.add;

      final exporter = InMemorySpanExporter();
      final processor = SimpleSpanProcessor(exporter);

      await OTel.initialize(
        serviceName: 'shutdown-skip-test',
        serviceVersion: '1.0.0',
        spanProcessor: processor,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      // Shutdown first
      await processor.shutdown();

      // Then try to end a span - should be skipped
      final tracer = OTel.tracer();
      final span = tracer.startSpan('after-shutdown');
      await processor.onEnd(span);

      final hasSkipLog = logMessages.any(
        (msg) => msg.contains('Skipping export'),
      );
      expect(hasSkipLog, isTrue,
          reason: 'Should log that export was skipped after shutdown');
    });

    test('double shutdown is a no-op', () async {
      // Covers lines 118-122: already shutdown branch
      final logMessages = <String>[];
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logMessages.add;

      final exporter = InMemorySpanExporter();
      final processor = SimpleSpanProcessor(exporter);

      await OTel.initialize(
        serviceName: 'double-shutdown-test',
        serviceVersion: '1.0.0',
        spanProcessor: processor,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      await processor.shutdown();
      await processor.shutdown();

      final hasAlreadyShutdown = logMessages.any(
        (msg) => msg.contains('Already shut down'),
      );
      expect(hasAlreadyShutdown, isTrue,
          reason: 'Should log that processor is already shutdown');
    });

    test('forceFlush after shutdown is a no-op', () async {
      // Covers lines 178-183: cannot force flush after shutdown
      final logMessages = <String>[];
      OTelLog.enableTraceLogging();
      OTelLog.logFunction = logMessages.add;

      final exporter = InMemorySpanExporter();
      final processor = SimpleSpanProcessor(exporter);

      await OTel.initialize(
        serviceName: 'flush-after-shutdown-test',
        serviceVersion: '1.0.0',
        spanProcessor: processor,
        detectPlatformResources: false,
        enableMetrics: false,
      );

      await processor.shutdown();
      await processor.forceFlush();

      final hasCannotFlush = logMessages.any(
        (msg) => msg.contains('Cannot force flush'),
      );
      expect(hasCannotFlush, isTrue,
          reason: 'Should log that flush cannot happen after shutdown');
    });
  });
}
