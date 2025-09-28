// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('InstrumentationScope Test', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
      );
    });

    test('handles multiple instrumentation scopes correctly', () async {
      // Create tracer providers with explicit scope names
      final httpProvider = OTel.addTracerProvider(
        'http_provider',
        serviceName: 'http-service',
        serviceVersion: '1.0.0',
      );

      final dbProvider = OTel.addTracerProvider(
        'db_provider',
        serviceName: 'db-service',
        serviceVersion: '1.0.0',
      );

      // Create tracers with explicit names
      final httpTracer = httpProvider.getTracer(
        'http-instrumentation',
        version: '1.0',
      );

      final dbTracer = dbProvider.getTracer(
        'db-instrumentation',
        version: '1.0',
      );

      // Create spans
      final httpSpan = httpTracer.startSpan(
        'http-span',
        kind: SpanKind.server,
      );

      final dbSpan = dbTracer.startSpan(
        'db-span',
        kind: SpanKind.client,
      );

      // End spans
      httpSpan.end();
      dbSpan.end();

      // Now get the spans and check their instrumentation scopes
      final httpScope = httpSpan.instrumentationScope;
      final dbScope = dbSpan.instrumentationScope;

      print(
          'HTTP Span Instrumentation Scope: ${httpScope.name}, version: ${httpScope.version}');
      print(
          'DB Span Instrumentation Scope: ${dbScope.name}, version: ${dbScope.version}');

      // Verify the instrumentation scopes
      expect(httpScope.name, equals('http-instrumentation'));
      expect(httpScope.version, equals('1.0'));
      expect(dbScope.name, equals('db-instrumentation'));
      expect(dbScope.version, equals('1.0'));

      // Transform spans to OTLP format
      final request = OtlpSpanTransformer.transformSpans([httpSpan, dbSpan]);

      // Debug
      for (final rs in request.resourceSpans) {
        print('\nResource:');
        for (final attr in rs.resource.attributes) {
          print('  ${attr.key}: ${attr.value.stringValue}');
        }

        for (final ss in rs.scopeSpans) {
          print('\nScopeSpan:');
          print('  Name: "${ss.scope.name}"');
          print('  Version: "${ss.scope.version}"');
          print('  Spans: ${ss.spans.length}');
          for (final span in ss.spans) {
            print('    Name: ${span.name}');
          }
        }
      }

      // Find all scope names
      final allScopeNames = <String>[];

      for (final rs in request.resourceSpans) {
        for (final ss in rs.scopeSpans) {
          final name = ss.scope.name;
          allScopeNames.add(name);
        }
      }

      print('All scope names: $allScopeNames');

      // Check for both instrumentation scopes
      expect(allScopeNames.contains('http-instrumentation'), isTrue,
          reason: 'Should contain http-instrumentation scope');
      expect(allScopeNames.contains('db-instrumentation'), isTrue,
          reason: 'Should contain db-instrumentation scope');
    });
  });
}
