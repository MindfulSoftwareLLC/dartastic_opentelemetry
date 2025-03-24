// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

library;
import 'package:dartastic_opentelemetry/src/trace/sampling/sampler.dart';
import 'package:dartastic_opentelemetry/src/trace/tracer.dart';
import 'package:dartastic_opentelemetry/src/trace/span_processor.dart';
import 'package:dartastic_opentelemetry/src/resource/resource.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';

import '../util/otel_log.dart';

part 'tracer_provider_create.dart';

class TracerProvider implements APITracerProvider {
  final Map<String, Tracer> _tracers = {};
  final List<SpanProcessor> _spanProcessors = [];
  final APITracerProvider delegate;
  Resource? resource;
  Sampler? sampler;

  @override
  bool get isShutdown => delegate.isShutdown;

  @override
  set isShutdown(bool value) {
    delegate.isShutdown = value;
  }

  TracerProvider._({
    required this.delegate,
    this.resource,
    Sampler? sampler,
  }) {
    if (OTelLog.isDebug()) OTelLog.debug('TracerProvider: Created with resource: $resource, sampler: $sampler');
  }

  @override
  Future<bool> shutdown() async {
    if (OTelLog.isDebug()) OTelLog.debug('TracerProvider: Shutting down with ${_spanProcessors.length} processors');
    if (!isShutdown) {
      // Shutdown all span processors
      for (final processor in _spanProcessors) {
        if (OTelLog.isDebug()) OTelLog.debug('SDKTracerProvider: Shutting down processor ${processor.runtimeType}');
        await processor.shutdown();
      }

      // Clear cached tracers
      _tracers.clear();
      await delegate.shutdown();
      isShutdown = true;
    }
    return isShutdown;
  }

  @override
  Tracer getTracer(String name, {
    String? version,
    String? schemaUrl,
    Attributes? attributes,
    Sampler? sampler,
  }) {
    if (OTelLog.isDebug()) OTelLog.debug('TracerProvider: Getting tracer with name: $name, version: $version, schemaUrl: $schemaUrl');
    if (isShutdown) {
      throw StateError('TracerProvider has been shut down');
    }

    final key = '$name:${version ?? ''}';
    return _tracers.putIfAbsent(
        key,
        () => SDKTracerCreate.create(
          delegate: delegate.getTracer(
            name,
            version: version,
            schemaUrl: schemaUrl,
            attributes: attributes,
          ),
          provider: this,
          sampler: sampler,
        ) as Tracer,
    );
  }

  /// Add a span processor
  void addSpanProcessor(SpanProcessor processor) {
    if (isShutdown) {
      throw StateError('TracerProvider has been shut down');
    }
    if (OTelLog.isDebug()) OTelLog.debug('SDKTracerProvider: Adding span processor of type ${processor.runtimeType}');
    _spanProcessors.add(processor);
  }

  /// Get all registered span processors
  List<SpanProcessor> get spanProcessors =>
      List.unmodifiable(_spanProcessors);

  @override
  String get endpoint => delegate.endpoint;

  @override
  set endpoint(String value) {
    delegate.endpoint = value;
  }

  @override
  String get serviceName => delegate.serviceName;

  @override
  set serviceName(String value) {
    delegate.serviceName = value;
  }

  @override
  String? get serviceVersion => delegate.serviceVersion;

  @override
  set serviceVersion(String? value) {
    delegate.serviceVersion = value;
  }

  @override
  bool get enabled => delegate.enabled;

  @override
  set enabled(bool value) {
    delegate.enabled = value;
  }

  /// Flushes all the span processors
  forceFlush() {
    for (var spanProcessor in _spanProcessors) {
      spanProcessor.forceFlush();
    }
  }
}
