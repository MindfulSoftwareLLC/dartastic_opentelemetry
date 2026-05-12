// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

library;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../otel.dart';
import '../resource/resource.dart';
import 'sampling/sampler.dart';
import 'span.dart';
import 'tracer_provider.dart';

part 'tracer_create.dart';

/// SDK implementation of the APITracer interface.
///
/// A Tracer is responsible for creating and managing spans. Each Tracer
/// is associated with a specific instrumentation scope and can create
/// spans that represent operations within that scope.
///
/// This implementation delegates some functionality to the API Tracer
/// implementation while adding SDK-specific behaviors like sampling and
/// span processor notification.
///
/// Note: Per [OTEP 0265](https://opentelemetry.io/docs/specs/semconv/general/events/),
/// span events are being deprecated and will be replaced by the Logging API in future versions.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/trace/sdk/
class Tracer implements APITracer {
  final TracerProvider _provider;
  final APITracer _delegate;
  final Sampler? _sampler;
  bool _enabled = true;

  /// Gets the sampler associated with this tracer.
  /// If no sampler was specified for this tracer, uses the provider's sampler.
  Sampler? get sampler => _sampler ?? _provider.sampler;

  /// Private constructor for creating Tracer instances.
  ///
  /// @param provider The TracerProvider that created this Tracer
  /// @param delegate The API Tracer implementation to delegate to
  /// @param sampler Optional custom sampler for this Tracer
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

  @override
  APISpan? get currentSpan => _delegate.currentSpan;

  /// Sets whether this tracer is enabled.
  ///
  /// When disabled, the tracer will still create spans, but they may not be
  /// recorded or exported.
  set enabled(bool enable) => _enabled = enable;

  /// Gets the provider that created this tracer.
  TracerProvider get provider => _provider;

  /// Gets the resource associated with this tracer's provider.
  Resource? get resource => _provider.resource;

  @override
  TimeProvider get timeProvider => _delegate.timeProvider;

  @override
  T withSpan<T>(APISpan span, T Function() fn) {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
        'Tracer: withSpan called with span ${span.name}, spanId: ${span.spanContext.spanId}',
      );
    }
    // Activate the span in a new Zone via Context.runSync so the active span
    // propagates correctly across async boundaries inside fn. Wrap fn to
    // record exceptions on SDK spans.
    try {
      return Context.current.withSpan(span).runSync(() {
        if (OTelLog.isDebug()) {
          OTelLog.debug('Tracer: Context set with span ${span.name}');
        }
        try {
          final result = fn();
          if (OTelLog.isDebug()) {
            OTelLog.debug(
              'Tracer: Function completed in withSpan for ${span.name}',
            );
          }
          return result;
        } catch (e, stackTrace) {
          if (OTelLog.isError()) {
            OTelLog.error('Tracer: Exception in withSpan for ${span.name}: $e');
          }
          // SDK-specific exception recording only when the span is one
          // of ours. Foreign / no-op APISpans skip this branch — we
          // still activate them and rethrow.
          if (span is Span) {
            span.recordException(e, stackTrace: stackTrace);
            span.setStatus(SpanStatusCode.Error, e.toString());
          }
          rethrow;
        }
      });
    } finally {
      if (OTelLog.isDebug()) {
        OTelLog.debug('Tracer: withSpan completed for span ${span.name}');
        if (!span.isValid) {
          OTelLog.debug(
            'Tracer: Warning - span ${span.name} is invalid after withSpan operation',
          );
        }
      }
    }
  }

  @override
  Future<T> withSpanAsync<T>(APISpan span, Future<T> Function() fn) async {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
        'Tracer: withSpanAsync called with span ${span.name}, spanId: ${span.spanContext.spanId}',
      );
    }
    try {
      return await Context.current.withSpan(span).run(() async {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
            'Tracer: Context set with span ${span.name} for async operation',
          );
        }
        try {
          return await fn();
        } catch (e, stackTrace) {
          if (OTelLog.isError()) {
            OTelLog.error(
              'Tracer: Exception in withSpanAsync for ${span.name}: $e',
            );
          }
          // SDK-specific exception recording only when the span is one
          // of ours. Foreign / no-op APISpans skip this branch — we
          // still activate them and rethrow.
          if (span is Span) {
            span.recordException(e, stackTrace: stackTrace);
            span.setStatus(SpanStatusCode.Error, e.toString());
          }
          rethrow;
        }
      });
    } finally {
      if (OTelLog.isDebug()) {
        OTelLog.debug('Tracer: withSpanAsync completed for span ${span.name}');
        if (!span.isValid) {
          OTelLog.debug(
            'Tracer: Warning - span ${span.name} is invalid after withSpanAsync operation',
          );
        }
      }
    }
  }

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
    if (OTelLog.isDebug()) {
      OTelLog.debug('Tracer: Creating span with name: $name, kind: $kind');
    }

    final delegateSpan = _delegate.createSpan(
      name: name,
      spanContext: spanContext,
      parentSpan: parentSpan,
      kind: kind,
      attributes: attributes,
      links: links,
      startTime: startTime,
      spanEvents: spanEvents,
      isRecording: isRecording,
      context: context,
    );

    return SDKSpanCreate.create(delegateSpan: delegateSpan, sdkTracer: this);
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
    bool? isRecording = true,
  }) {
    if (OTelLog.isDebug()) {
      OTelLog.debug('Tracer: Starting span with name: $name, kind: $kind');
    }

    // Get parent context from either the passed context or parent span.
    // Use a content-based check rather than `effectiveContext != Context.root`
    // — Context.root can carry the propagated context inside an isolate
    // spawned via Context.runIsolate (the API treats the receiving isolate's
    // root as the propagated starting context), so an identity-style check
    // would incorrectly skip parent inheritance there.
    SpanContext? parentContext;
    var effectiveParentSpan = parentSpan;
    final effectiveContext = context ?? Context.current;

    if (effectiveContext.span != null) {
      effectiveParentSpan ??= effectiveContext.span;
    }
    parentContext = effectiveContext.spanContext;

    // If no parentContext from context but we have a parentSpan, use its context
    if (parentContext == null && effectiveParentSpan != null) {
      parentContext = effectiveParentSpan.spanContext;
    }

    // Determine the trace ID to use
    TraceId traceId;
    if (spanContext != null && spanContext.traceId.isValid) {
      // Use provided span context's trace ID if valid
      traceId = spanContext.traceId;

      // Validate it against parent if both exist and are valid
      if (parentContext != null && parentContext.isValid) {
        if (parentContext.traceId != traceId) {
          throw ArgumentError(
            'Cannot create span with different trace ID than parent. '
            'Parent trace ID: ${parentContext.traceId}, '
            'Provided trace ID: $traceId',
          );
        }
      }
    } else if (parentSpan != null && parentSpan.spanContext.isValid) {
      // An explicit parentSpan takes precedence over the context's span when
      // both are provided (the parent span ID and trace ID must come from the
      // same span — using context's traceId with parentSpan's spanId would
      // produce an invalid parent reference).
      traceId = parentSpan.spanContext.traceId;
    } else if (parentContext != null && parentContext.isValid) {
      // Inherit from parent if available
      traceId = parentContext.traceId;
    } else {
      // Generate new trace ID for root span
      traceId = OTel.traceId();
    }

    // Determine the parent span ID
    SpanId? parentSpanId;
    if (effectiveParentSpan != null &&
        effectiveParentSpan.spanContext.isValid) {
      // Use effective parent span's span ID
      parentSpanId = effectiveParentSpan.spanContext.spanId;
    } else if (parentContext != null && parentContext.isValid) {
      // Use parent context's span ID
      parentSpanId = parentContext.spanId;
    }

    // Inherit trace flags from parent — explicit parentSpan wins over context
    // for consistency with traceId resolution above.
    TraceFlags? traceFlags;
    if (parentSpan != null && parentSpan.spanContext.isValid) {
      traceFlags = parentSpan.spanContext.traceFlags;
    } else if (parentContext != null && parentContext.isValid) {
      traceFlags = parentContext.traceFlags;
    }

    if (OTelLog.isDebug()) {
      if (parentSpanId != null) {
        OTelLog.debug(
          'Creating child span: traceId=$traceId, parentSpanId=$parentSpanId',
        );
      } else {
        OTelLog.debug('Creating root span: traceId=$traceId');
      }
    }

    // Apply sampling decision if we have a sampler
    var shouldRecord = true;
    if (sampler != null) {
      final samplingResult = sampler!.shouldSample(
        parentContext: effectiveContext,
        traceId: traceId.toString(),
        name: name,
        spanKind: kind,
        attributes: attributes,
        links: links,
      );

      // Update the isRecording flag based on the sampling decision
      shouldRecord = samplingResult.decision != SamplingDecision.drop;

      // Update trace flags based on sampling decision
      if (traceFlags == null) {
        traceFlags = OTel.traceFlags(
          shouldRecord ? TraceFlags.SAMPLED_FLAG : TraceFlags.NONE_FLAG,
        );
      } else if (shouldRecord && !traceFlags.isSampled) {
        // Upgrade to sampled if necessary
        traceFlags = OTel.traceFlags(TraceFlags.SAMPLED_FLAG);
      } else if (!shouldRecord && traceFlags.isSampled) {
        // Downgrade to not sampled if necessary
        traceFlags = OTel.traceFlags(TraceFlags.NONE_FLAG);
      }

      // Add sampler attributes if provided
      if (samplingResult.attributes != null) {
        if (attributes == null) {
          attributes = samplingResult.attributes;
        } else {
          attributes = attributes.copyWithAttributes(
            samplingResult.attributes!,
          );
        }
      }

      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'Sampling decision for span $name: ${samplingResult.decision}',
        );
      }
    }

    // Always create a new span context with a new span ID
    // For root spans, ensure we set an invalid parent span ID (zeros)
    final newSpanContext = OTel.spanContext(
      traceId: traceId,
      spanId: OTel.spanId(), // Always generate a new span ID
      parentSpanId: parentSpanId ??
          OTel.spanIdInvalid(), // Use invalid span ID for root spans
      traceFlags: traceFlags,
    );

    // Create the delegate span with our newly created span context
    final delegateSpan = _delegate.startSpan(
      name,
      context: effectiveContext,
      spanContext: newSpanContext,
      parentSpan: effectiveParentSpan,
      kind: kind,
      attributes: attributes,
      links: links,
      isRecording: isRecording ?? shouldRecord,
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

  /// Like [startSpan] + [withSpan] but passes the started span to [fn]
  /// as an argument and ends the span when [fn] returns,
  /// so callers can attach attributes / events without going through
  /// `Context.current`. Routes through [withSpan] for activation;
  /// [withSpan] handles `recordException` / `setStatus(Error)` on throw.
  T startActiveSpan<T>({
    required String name,
    required T Function(APISpan span) fn,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
  }) {
    final span = startSpan(name, kind: kind, attributes: attributes);
    try {
      return withSpan(span, () => fn(span));
    } finally {
      span.end();
    }
  }

  /// Async variant of [startActiveSpan]. Routes through [withSpanAsync]
  /// for activation; [withSpanAsync] handles `recordException` /
  /// `setStatus(Error)` on throw.
  Future<T> startActiveSpanAsync<T>({
    required String name,
    required Future<T> Function(APISpan span) fn,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
  }) async {
    final span = startSpan(name, kind: kind, attributes: attributes);
    try {
      return await withSpanAsync(span, () => fn(span));
    } finally {
      span.end();
    }
  }
}
