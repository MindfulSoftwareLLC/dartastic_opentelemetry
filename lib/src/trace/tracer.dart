// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

library;

import 'package:dartastic_opentelemetry/src/trace/sampling/sampler.dart';
import 'package:dartastic_opentelemetry/src/trace/tracer_provider.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';

import '../resource/resource.dart';
import '../util/otel_log.dart';
import 'span.dart';

part 'tracer_create.dart';

class Tracer implements APITracer {
  final TracerProvider _provider;
  final APITracer _delegate;
  final Sampler? _sampler;
  bool _enabled = true;

  Sampler? get sampler => _sampler ?? _provider.sampler;

  Tracer._({
    required TracerProvider provider,
    required APITracer delegate,
    Sampler? sampler,
  })  : _provider = provider,
        _delegate = delegate,
        _sampler = sampler;

  @override
  String get name => _delegate.name;

  @override
  String? get schemaUrl => _delegate.schemaUrl;

  @override
  String? get version => _delegate.version;

  @override
  Attributes? get attributes => _delegate.attributes;

  @override
  set attributes(Attributes? attributes) => _delegate.attributes = attributes;

  @override
  bool get enabled => _enabled;

  set enabled(bool enable) => _enabled = enable;

  get provider => _provider;

  Resource? get resource => _provider.resource;

  @override
  Span createSpan({
    required String name,
    SpanContext? spanContext,
    APISpan? parentSpan,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
    List<SpanLink>? links,
    List<SpanEvent>? spanEvents,
    DateTime? startTime,
    bool? isRecording = true,
    Context? context,
  }) {
    if (OTelLog.isDebug()) OTelLog.debug('Tracer: Creating span with name: $name, kind: $kind');

    APISpan delegateSpan = _delegate.createSpan(
      name: name,
      spanContext: spanContext,
      parentSpan: parentSpan,
      kind: kind,
      attributes: attributes,
      links: links,
      startTime: startTime,
      spanEvents: spanEvents,
      isRecording: isRecording,
    );

    return SDKSpanCreate.create(
      delegateSpan: delegateSpan,
      sdkTracer: this,
    );
  }

  @override
  Span startSpan(
      String name, {
        Context? context,
        SpanContext? spanContext,
        APISpan? parentSpan,
        SpanKind kind = SpanKind.internal,
        Attributes? attributes,
        List<SpanLink>? links,
        bool? isRecording = true}) {

    if (OTelLog.isDebug()) OTelLog.debug('Tracer: Starting span with name: $name, kind: $kind');

    // Get parent context from either the passed context or parent span
    SpanContext? parentContext;
    if (context != null) {
      parentContext = context.spanContext;
    } else if (parentSpan != null) {
      parentContext = parentSpan.spanContext;
    }

    // If a span context was explicitly provided, use that
    if (spanContext != null) {
      if (parentContext != null && parentContext.isValid && spanContext.isValid) {
        // Validate that trace IDs match if both contexts are valid
        if (parentContext.traceId != spanContext.traceId) {
          throw ArgumentError(
              // ignore: prefer_adjacent_string_concatenation
              'Cannot create span with different trace ID than parent. ' +
                  'Parent trace ID: ${parentContext.traceId}, ' +
                  'Provided trace ID: ${spanContext.traceId}'
          );
        }
      }
      parentContext = spanContext;
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug(parentContext != null ?
    'Creating child context from parent: ${parentContext.traceId}' :
    'Creating new root span context');
    }

    // Create the delegate span with the validated context
    APISpan delegateSpan = _delegate.startSpan(
        name,
        context: context,
        spanContext: parentContext,
        parentSpan: parentSpan,
        kind: kind,
        attributes: attributes,
        links: links,
        isRecording: isRecording
    );

    // Wrap it in our SDK span which will handle processing
    final sdkSpan = SDKSpanCreate.create(
      delegateSpan: delegateSpan,
      sdkTracer: this,
    );

    // Notify processors
    for (final processor in _provider.spanProcessors) {
      processor.onStart(sdkSpan, context);
    }

    return sdkSpan;
  }
  
  @override
  T recordSpan<T>({
    required String name,
    required T Function() fn,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
  }) {
    final span = startSpan(name, kind: kind, attributes: attributes);
    try {
      return fn();
    } catch (e, stackTrace) {
      span.recordException(e, stackTrace: stackTrace);
      span.setStatus(SpanStatusCode.Error, e.toString());
      rethrow;
    } finally {
      span.end();
    }
  }

  @override
  Future<T> recordSpanAsync<T>({
    required String name,
    required Future<T> Function() fn,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
  }) async {
    final span = startSpan(name, kind: kind, attributes: attributes);
    try {
      return await fn();
    } catch (e, stackTrace) {
      span.recordException(e, stackTrace: stackTrace);
      span.setStatus(SpanStatusCode.Error, e.toString());
      rethrow;
    } finally {
      span.end();
    }
  }
  
  @override
  T startActiveSpan<T>({
    required String name,
    required T Function(APISpan span) fn,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
  }) {
    final span = startSpan(name, kind: kind, attributes: attributes);
    try {
      return _delegate.withSpan(span, () => fn(span));
    } finally {
      span.end();
    }
  }

  @override
  Future<T> startActiveSpanAsync<T>({
    required String name,
    required Future<T> Function(APISpan span) fn,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
  }) async {
    final span = startSpan(name, kind: kind, attributes: attributes);
    try {
      return await _delegate.withSpanAsync(span, () => fn(span));
    } finally {
      span.end();
    }
  }

}
