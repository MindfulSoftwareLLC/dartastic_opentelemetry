// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Comprehensive test file that covers remaining small coverage gaps across
// multiple source files, with trace-level logging enabled to exercise
// debug log guards.
//
// Targets:
//   - w3c_trace_context_propagator.dart (14 uncovered lines)
//   - resource.dart (5 uncovered lines)
//   - metrics/metric_reader.dart (7 uncovered lines)
//   - metrics/storage/sum_storage.dart (9 uncovered lines)
//   - trace/export/otlp/certificate_utils.dart (10 uncovered lines)
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/trace/export/otlp/certificate_utils.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:test/test.dart';

import '../testing_utils/memory_metric_exporter.dart';

// ---------------------------------------------------------------------------
// Helpers for W3C propagator tests
// ---------------------------------------------------------------------------

/// Simple TextMapGetter for `Map<String, String>`.
class _MapGetter implements TextMapGetter<String> {
  final Map<String, String> _map;
  _MapGetter(this._map);

  @override
  String? get(String key) => _map[key];

  @override
  Iterable<String> keys() => _map.keys;
}

/// Simple TextMapSetter for `Map<String, String>`.
class _MapSetter implements TextMapSetter<String> {
  final Map<String, String> _map;
  _MapSetter(this._map);

  @override
  void set(String key, String value) {
    _map[key] = value;
  }
}

void main() {
  // Shared log capture list.
  final List<String> logOutput = [];

  setUp(() async {
    await OTel.reset();
    logOutput.clear();
    OTelLog.logFunction = logOutput.add;
    await OTel.initialize(
      serviceName: 'remaining-coverage-test',
      detectPlatformResources: false,
      enableLogs: false,
    );
    // Set trace logging AFTER initialize, since initializeLogging() reads
    // OTEL_LOG_LEVEL from env and would override a level set before it.
    OTelLog.enableTraceLogging();
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
    OTelLog.currentLevel = LogLevel.info;
    OTelLog.logFunction = null;
  });

  // =========================================================================
  // W3C Trace Context Propagator - debug logging paths
  // =========================================================================
  group('W3CTraceContextPropagator with debug logging', () {
    late W3CTraceContextPropagator propagator;

    setUp(() {
      propagator = W3CTraceContextPropagator();
    });

    test('extract with valid traceparent logs debug messages', () {
      final carrier = {
        'traceparent':
            '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
      };
      logOutput.clear();
      final extracted = propagator.extract(
        OTel.context(),
        carrier,
        _MapGetter(carrier),
      );

      expect(extracted.spanContext, isNotNull);
      expect(extracted.spanContext!.isValid, isTrue);
      // Verify debug logs were emitted for extraction
      expect(
        logOutput.any((m) => m.contains('Extracting traceparent')),
        isTrue,
        reason: 'Expected "Extracting traceparent" debug log',
      );
      expect(
        logOutput.any((m) => m.contains('Extracted span context')),
        isTrue,
        reason: 'Expected "Extracted span context" debug log',
      );
    });

    test('extract with null/missing traceparent logs debug', () {
      final carrier = <String, String>{};
      logOutput.clear();
      final extracted = propagator.extract(
        OTel.context(),
        carrier,
        _MapGetter(carrier),
      );

      // Context returned unchanged.
      expect(extracted.spanContext, isNull);
      expect(
        logOutput.any((m) => m.contains('Extracting traceparent')),
        isTrue,
      );
    });

    test('extract with invalid traceparent format logs debug', () {
      // Correct total length (55) but wrong version to trigger version mismatch log.
      final carrier = {
        'traceparent':
            '01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
      };
      logOutput.clear();
      final extracted = propagator.extract(
        OTel.context(),
        carrier,
        _MapGetter(carrier),
      );

      expect(extracted.spanContext, isNull);
      expect(
        logOutput.any((m) => m.contains('Unsupported traceparent version')),
        isTrue,
        reason: 'Expected debug log about unsupported version',
      );
    });

    test('extract with wrong length logs debug', () {
      final carrier = {
        'traceparent': '00-abcdef-1234-01', // too short
      };
      logOutput.clear();
      propagator.extract(OTel.context(), carrier, _MapGetter(carrier));

      expect(
        logOutput.any((m) => m.contains('Invalid traceparent length')),
        isTrue,
        reason: 'Expected debug log about invalid length',
      );
    });

    test('extract with all-zero trace ID logs debug', () {
      final carrier = {
        'traceparent':
            '00-00000000000000000000000000000000-00f067aa0ba902b7-01',
      };
      logOutput.clear();
      propagator.extract(OTel.context(), carrier, _MapGetter(carrier));

      expect(
        logOutput.any((m) => m.contains('Invalid trace ID')),
        isTrue,
        reason: 'Expected debug log about invalid trace ID (all zeros)',
      );
    });

    test('extract with all-zero span ID logs debug', () {
      final carrier = {
        'traceparent':
            '00-4bf92f3577b34da6a3ce929d0e0e4736-0000000000000000-01',
      };
      logOutput.clear();
      propagator.extract(OTel.context(), carrier, _MapGetter(carrier));

      expect(
        logOutput.any((m) => m.contains('Invalid span ID')),
        isTrue,
        reason: 'Expected debug log about invalid span ID (all zeros)',
      );
    });

    test('extract with malformed tracestate entry logs debug', () {
      // "no-equals" has no '=' separator so it should be skipped with a log.
      final carrier = {
        'traceparent':
            '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
        'tracestate': 'no-equals,also-bad',
      };
      logOutput.clear();
      final extracted = propagator.extract(
        OTel.context(),
        carrier,
        _MapGetter(carrier),
      );

      expect(extracted.spanContext, isNotNull);
      expect(
        logOutput.any((m) => m.contains('Invalid tracestate entry format')),
        isTrue,
        reason: 'Expected debug log about invalid tracestate entry',
      );
    });

    test('extract with tracestate having value-less key=  logs debug', () {
      // "key=" has separator at last position, triggers separatorIndex >= length - 1.
      final carrier = {
        'traceparent':
            '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
        'tracestate': 'key=',
      };
      logOutput.clear();
      final extracted = propagator.extract(
        OTel.context(),
        carrier,
        _MapGetter(carrier),
      );

      expect(extracted.spanContext, isNotNull);
      expect(
        logOutput.any((m) => m.contains('Invalid tracestate entry format')),
        isTrue,
      );
    });

    test('inject with valid span context logs debug messages', () {
      final traceId = OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
      final spanId = OTel.spanIdFrom('00f067aa0ba902b7');
      final spanContext = OTel.spanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: TraceFlags.sampled,
      );
      final context = OTel.context(spanContext: spanContext);
      final carrier = <String, String>{};
      logOutput.clear();
      propagator.inject(context, carrier, _MapSetter(carrier));

      expect(carrier['traceparent'], isNotNull);
      expect(
        logOutput.any((m) => m.contains('Injecting span context')),
        isTrue,
        reason: 'Expected "Injecting span context" debug log',
      );
      expect(
        logOutput.any((m) => m.contains('Injected traceparent')),
        isTrue,
        reason: 'Expected "Injected traceparent" debug log',
      );
    });

    test('inject with no valid span context logs debug', () {
      final context = OTel.context(); // no span context
      final carrier = <String, String>{};
      logOutput.clear();
      propagator.inject(context, carrier, _MapSetter(carrier));

      expect(carrier, isEmpty);
      expect(
        logOutput.any((m) => m.contains('No valid span context to inject')),
        isTrue,
        reason: 'Expected "No valid span context to inject" debug log',
      );
    });

    test('inject with tracestate logs debug for tracestate', () {
      final traceId = OTel.traceIdFrom('4bf92f3577b34da6a3ce929d0e0e4736');
      final spanId = OTel.spanIdFrom('00f067aa0ba902b7');
      final traceState = OTel.traceState({
        'vendor1': 'val1',
        'vendor2': 'val2',
      });
      final spanContext = OTel.spanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: TraceFlags.sampled,
        traceState: traceState,
      );
      final context = OTel.context(spanContext: spanContext);
      final carrier = <String, String>{};
      logOutput.clear();
      propagator.inject(context, carrier, _MapSetter(carrier));

      expect(carrier['tracestate'], isNotNull);
      expect(
        logOutput.any((m) => m.contains('Injected tracestate')),
        isTrue,
        reason: 'Expected "Injected tracestate" debug log',
      );
    });

    test('roundtrip inject then extract with tracestate values', () {
      final traceId = OTel.traceIdFrom('abcdef1234567890abcdef1234567890');
      final spanId = OTel.spanIdFrom('1234567890abcdef');
      final traceState = OTel.traceState({
        'acme': 'some-value',
        'test': 'another-value',
      });
      final spanContext = OTel.spanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: TraceFlags.sampled,
        traceState: traceState,
      );
      final originalCtx = OTel.context(spanContext: spanContext);
      final carrier = <String, String>{};

      propagator.inject(originalCtx, carrier, _MapSetter(carrier));
      final extractedCtx = propagator.extract(
        OTel.context(),
        carrier,
        _MapGetter(carrier),
      );

      final sc = extractedCtx.spanContext;
      expect(sc, isNotNull);
      expect(sc!.traceId.hexString, equals('abcdef1234567890abcdef1234567890'));
      expect(sc.spanId.hexString, equals('1234567890abcdef'));
      expect(sc.traceFlags.isSampled, isTrue);
      expect(sc.isRemote, isTrue);
      expect(sc.traceState, isNotNull);
      expect(sc.traceState!.entries['acme'], equals('some-value'));
      expect(sc.traceState!.entries['test'], equals('another-value'));
    });

    test('extract with invalid traceparent logs "Invalid traceparent format"',
        () {
      // Force a traceparent that is exactly 55 chars but has no '-' separators,
      // so split('-') yields only 1 part instead of 4.
      final bogus = 'X' * 55;
      final carrier = {'traceparent': bogus};
      logOutput.clear();
      propagator.extract(OTel.context(), carrier, _MapGetter(carrier));

      expect(
        logOutput.any(
          (m) =>
              m.contains('Invalid traceparent format') ||
              m.contains('Invalid trace ID length') ||
              m.contains('Invalid span ID length') ||
              m.contains('Invalid trace flags length'),
        ),
        isTrue,
        reason:
            'Expected some validation debug log for the malformed traceparent',
      );
    });
  });

  // =========================================================================
  // Resource - merge, empty, toString debug logging
  // =========================================================================
  group('Resource coverage', () {
    test('Resource.empty has no attributes', () {
      final empty = Resource.empty;
      expect(empty.attributes.toList(), isEmpty);
      expect(empty.schemaUrl, isNull);
    });

    test('Resource merge combines attributes with other taking precedence', () {
      final r1 = OTel.resource(
        OTel.attributesFromMap({'key1': 'val1', 'shared': 'from-r1'}),
        'https://schema1.example.com',
      );
      final r2 = OTel.resource(
        OTel.attributesFromMap({'key2': 'val2', 'shared': 'from-r2'}),
        'https://schema2.example.com',
      );

      logOutput.clear();
      final merged = r1.merge(r2);

      // other (r2) takes precedence for 'shared'
      expect(merged.attributes.getString('shared'), equals('from-r2'));
      expect(merged.attributes.getString('key1'), equals('val1'));
      expect(merged.attributes.getString('key2'), equals('val2'));
      // Different schema URLs: other's (r2) schema URL wins.
      expect(merged.schemaUrl, equals('https://schema2.example.com'));
    });

    test('Resource merge when first has null schemaUrl uses other', () {
      final r1 = OTel.resource(OTel.attributesFromMap({'a': '1'}));
      final r2 = OTel.resource(
        OTel.attributesFromMap({'b': '2'}),
        'https://schema.example.com',
      );

      final merged = r1.merge(r2);
      expect(merged.schemaUrl, equals('https://schema.example.com'));
    });

    test('Resource merge when other has null schemaUrl keeps first', () {
      final r1 = OTel.resource(
        OTel.attributesFromMap({'a': '1'}),
        'https://schema.example.com',
      );
      final r2 = OTel.resource(OTel.attributesFromMap({'b': '2'}));

      final merged = r1.merge(r2);
      expect(merged.schemaUrl, equals('https://schema.example.com'));
    });

    test('Resource merge when both have same schemaUrl', () {
      final url = 'https://same-schema.example.com';
      final r1 = OTel.resource(OTel.attributesFromMap({'a': '1'}), url);
      final r2 = OTel.resource(OTel.attributesFromMap({'b': '2'}), url);

      final merged = r1.merge(r2);
      expect(merged.schemaUrl, equals(url));
    });

    test('Resource merge logs debug with service.name and tenant_id', () {
      final r1 = OTel.resource(
        OTel.attributesFromMap({
          'service.name': 'svc-a',
          'tenant_id': 'tenant-1',
        }),
      );
      final r2 = OTel.resource(
        OTel.attributesFromMap({'service.name': 'svc-b', 'other': 'value'}),
      );

      logOutput.clear();
      r1.merge(r2);

      expect(
        logOutput.any((m) => m.contains('Resource merge result attributes')),
        isTrue,
        reason: 'Expected resource merge debug log',
      );
      // The debug log should contain service.name and tenant_id entries.
      expect(
        logOutput.any((m) => m.contains('service.name')),
        isTrue,
        reason: 'Expected service.name in debug output',
      );
    });

    test('Resource merge with empty resources', () {
      final r1 = Resource.empty;
      final r2 = OTel.resource(OTel.attributesFromMap({'key': 'value'}));

      final merged = r1.merge(r2);
      expect(merged.attributes.getString('key'), equals('value'));
    });
  });

  // =========================================================================
  // MetricReader - PeriodicExportingMetricReader
  // =========================================================================
  group('PeriodicExportingMetricReader coverage', () {
    test('collect without registered MeterProvider returns empty', () async {
      final exporter = MemoryMetricExporter();
      // Enable metric logging for the OTelLog.isLogMetrics() guard.
      OTelLog.metricLogFunction = logOutput.add;

      final reader = PeriodicExportingMetricReader(
        exporter,
        interval: const Duration(
          hours: 1,
        ), // long interval so timer doesn't fire
      );
      // Do NOT register a MeterProvider.

      logOutput.clear();
      final data = await reader.collect();

      expect(data.metrics, isEmpty);
      expect(
        logOutput.any((m) => m.contains('No meter provider registered')),
        isTrue,
        reason: 'Expected "No meter provider registered" log',
      );

      await reader.shutdown();
      OTelLog.metricLogFunction = null;
    });

    test('collect with registered MeterProvider returns metrics', () async {
      final exporter = MemoryMetricExporter();
      OTelLog.metricLogFunction = logOutput.add;

      final reader = PeriodicExportingMetricReader(
        exporter,
        interval: const Duration(hours: 1),
      );
      final meterProvider = OTel.meterProvider();
      reader.registerMeterProvider(meterProvider);

      expect(reader.meterProvider, isNotNull);

      logOutput.clear();
      final data = await reader.collect();
      // May or may not have metrics depending on instruments, but should not throw.
      expect(data, isNotNull);
      expect(
        logOutput.any((m) => m.contains('Collected')),
        isTrue,
        reason: 'Expected "Collected N metrics" log',
      );

      await reader.shutdown();
      OTelLog.metricLogFunction = null;
    });

    test('forceFlush collects and exports', () async {
      final exporter = MemoryMetricExporter();
      final reader = PeriodicExportingMetricReader(
        exporter,
        interval: const Duration(hours: 1),
      );
      final meterProvider = OTel.meterProvider();
      reader.registerMeterProvider(meterProvider);

      final result = await reader.forceFlush();
      expect(result, isTrue);

      await reader.shutdown();
    });

    test('shutdown cancels timer and performs final export', () async {
      final exporter = MemoryMetricExporter();
      final reader = PeriodicExportingMetricReader(
        exporter,
        interval: const Duration(hours: 1),
      );
      final meterProvider = OTel.meterProvider();
      reader.registerMeterProvider(meterProvider);

      final result = await reader.shutdown();
      expect(result, isTrue);
    });
  });

  // =========================================================================
  // SumStorage<int> and SumStorage<double>
  // =========================================================================
  group('SumStorage coverage', () {
    test('SumStorage<int> record, getValue, collectPoints, reset', () {
      final storage = SumStorage<int>(isMonotonic: true);

      // Record some values with no attributes.
      storage.record(10);
      storage.record(20);
      expect(storage.getValue(), equals(30));

      // Record with specific attributes.
      final attrs = OTel.attributesFromMap({'region': 'us'});
      storage.record(5, attrs);
      storage.record(3, attrs);
      expect(storage.getValue(attrs), equals(8));

      // Total across all attribute sets.
      expect(storage.getValue(), equals(38)); // 30 + 8

      // Collect points.
      final points = storage.collectPoints();
      expect(points.length, equals(2)); // null-attrs + region=us

      // Reset clears all points.
      storage.reset();
      expect(storage.getValue(), equals(0));
      expect(storage.collectPoints(), isEmpty);
    });

    test('SumStorage<double> record and getValue', () {
      final storage = SumStorage<double>(isMonotonic: false);

      storage.record(1.5);
      storage.record(2.5);
      expect(storage.getValue(), closeTo(4.0, 0.001));

      // Non-monotonic allows negative values.
      storage.record(-1.0);
      expect(storage.getValue(), closeTo(3.0, 0.001));
    });

    test('SumStorage<int> rejects negative values for monotonic', () {
      final storage = SumStorage<int>(isMonotonic: true);

      storage.record(10);
      storage.record(-5); // should be ignored with a warning
      expect(storage.getValue(), equals(10));
    });

    test('SumStorage getValue for unknown attributes returns 0', () {
      final storage = SumStorage<int>(isMonotonic: true);
      storage.record(10);

      final unknownAttrs = OTel.attributesFromMap({'unknown': 'attr'});
      expect(storage.getValue(unknownAttrs), equals(0));
    });

    test('SumStorage<double> getValue for unknown attributes returns 0.0', () {
      final storage = SumStorage<double>(isMonotonic: false);
      storage.record(1.5);

      final unknownAttrs = OTel.attributesFromMap({'foo': 'bar'});
      expect(storage.getValue(unknownAttrs), closeTo(0.0, 0.001));
    });

    test('SumStorage addExemplar adds to existing point', () {
      final storage = SumStorage<int>(isMonotonic: true);

      final attrs = OTel.attributesFromMap({'key': 'val'});
      storage.record(42, attrs);

      final exemplar = Exemplar(
        attributes: OTel.attributes(),
        filteredAttributes: OTel.attributes(),
        timestamp: DateTime.now(),
        value: 42,
      );
      storage.addExemplar(exemplar, attrs);

      final points = storage.collectPoints();
      expect(points.length, equals(1));
      expect(points.first.exemplars?.length, equals(1));
    });

    test('SumStorage addExemplar does nothing for non-existing point', () {
      final storage = SumStorage<int>(isMonotonic: true);

      final attrs = OTel.attributesFromMap({'key': 'val'});
      final exemplar = Exemplar(
        attributes: OTel.attributes(),
        filteredAttributes: OTel.attributes(),
        timestamp: DateTime.now(),
        value: 42,
      );
      // No point exists for these attrs, so addExemplar should be a no-op.
      storage.addExemplar(exemplar, attrs);

      expect(storage.collectPoints(), isEmpty);
    });

    test('SumStorage collectPoints with null attributes', () {
      final storage = SumStorage<int>(isMonotonic: true);
      storage.record(7); // null attributes

      final points = storage.collectPoints();
      expect(points.length, equals(1));
      expect(points.first.value, equals(7));
      expect(points.first.attributes, isNotNull);
    });
  });

  // =========================================================================
  // CertificateUtils - debug logging paths
  // =========================================================================
  group('CertificateUtils with debug logging', () {
    test('createSecurityContext returns null when all params null', () {
      logOutput.clear();
      final ctx = CertificateUtils.createSecurityContext();
      expect(ctx, isNull);
    });

    test('createSecurityContext with test:// CA cert logs debug', () {
      logOutput.clear();
      final ctx = CertificateUtils.createSecurityContext(
        certificate: 'test://ca.pem',
      );

      expect(ctx, isNotNull);
      expect(ctx, isA<SecurityContext>());
      expect(
        logOutput.any((m) => m.contains('Using test certificate')),
        isTrue,
        reason: 'Expected debug log about test certificate',
      );
    });

    test(
      'createSecurityContext with test:// client cert and key logs debug',
      () {
        logOutput.clear();
        final ctx = CertificateUtils.createSecurityContext(
          clientKey: 'test://client.key',
          clientCertificate: 'test://client.pem',
        );

        expect(ctx, isNotNull);
        expect(
          logOutput.any(
            (m) => m.contains('Using test client certificate and key'),
          ),
          isTrue,
          reason: 'Expected debug log about test client certificate and key',
        );
      },
    );

    test('createSecurityContext with all test:// certs logs all debug', () {
      logOutput.clear();
      final ctx = CertificateUtils.createSecurityContext(
        certificate: 'test://ca.pem',
        clientKey: 'test://client.key',
        clientCertificate: 'test://client.pem',
      );

      expect(ctx, isNotNull);
      expect(
        logOutput.any((m) => m.contains('Using test certificate')),
        isTrue,
      );
      expect(
        logOutput.any(
          (m) => m.contains('Using test client certificate and key'),
        ),
        isTrue,
      );
    });

    test('createSecurityContext with withTrustedRoots false', () {
      final ctx = CertificateUtils.createSecurityContext(
        certificate: 'test://ca.pem',
        withTrustedRoots: false,
      );
      expect(ctx, isNotNull);
    });

    test('validateCertificates with all null succeeds', () {
      expect(CertificateUtils.validateCertificates, returnsNormally);
    });

    test('validateCertificates with test:// paths succeeds', () {
      expect(
        () => CertificateUtils.validateCertificates(
          certificate: 'test://ca.pem',
          clientKey: 'test://client.key',
          clientCertificate: 'test://client.pem',
        ),
        returnsNormally,
      );
    });

    test('validateCertificates with special test values succeeds', () {
      expect(
        () => CertificateUtils.validateCertificates(
          certificate: 'cert',
          clientKey: 'key',
        ),
        returnsNormally,
      );
    });

    test(
      'validateCertificates with invalid-cert-path throws ArgumentError',
      () {
        expect(
          () => CertificateUtils.validateCertificates(
            certificate: 'invalid-cert-path',
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('validateCertificates with non-existent certificate throws', () {
      expect(
        () => CertificateUtils.validateCertificates(
          certificate: '/nonexistent/path/cert.pem',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateCertificates with non-existent clientKey throws', () {
      expect(
        () => CertificateUtils.validateCertificates(
          clientKey: '/nonexistent/path/key.pem',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateCertificates with non-existent clientCertificate throws', () {
      expect(
        () => CertificateUtils.validateCertificates(
          clientCertificate: '/nonexistent/path/client.pem',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateCertificates with existing file succeeds', () {
      final tempDir = Directory.systemTemp.createTempSync('cert_cov_test_');
      final certFile = File('${tempDir.path}/ca.pem');
      certFile.writeAsStringSync('fake cert content');

      try {
        expect(
          () =>
              CertificateUtils.validateCertificates(certificate: certFile.path),
          returnsNormally,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
