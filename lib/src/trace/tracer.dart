// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

library;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
// The API hides these from its barrel on purpose: span construction and
// scope construction are SDK concerns, not application API, and the API
// package documents this import path as the way an SDK reaches them.
// ignore_for_file: invalid_use_of_internal_member, implementation_imports
import 'package:dartastic_opentelemetry_api/src/api/common/instrumentation_scope.dart'
    show InstrumentationScopeCreate;
import 'package:dartastic_opentelemetry_api/src/api/trace/span.dart'
    show APISpanCreate;
import 'package:meta/meta.dart';

import '../otel.dart';
import '../resource/resource.dart';
import 'sampling/sampler.dart';
import 'span.dart';
import 'span_exception_options.dart';
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
/// Note: Per [OTEP 0265: Event Vision](https://github.com/open-telemetry/opentelemetry-specification/blob/main/oteps/0265-event-vision.md)
/// and [OTEP 4430: Span Event API deprecation plan](https://github.com/open-telemetry/opentelemetry-specification/blob/main/oteps/4430-span-event-api-deprecation-plan.md),
/// span events are planned for deprecation in favor of log-based events
/// emitted via the Logs API; SDKs will provide options to render log-based
/// events as span events for compatibility.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/trace/sdk/
class Tracer implements APITracer {
  final TracerProvider _provider;
  final APITracer _delegate;
  final Sampler? _sampler;
  bool _enabled = true;

  /// The scope stamped on every span this tracer creates: the tracer's own
  /// name, version, schema URL and attributes, built once (API #129).
  late final InstrumentationScope _instrumentationScope =
      InstrumentationScopeCreate.create(
    name: name,
    version: version,
    schemaUrl: schemaUrl,
    attributes: attributes,
  );

  /// Gets the sampler associated with this tracer.
  /// If no sampler was specified for this tracer, uses the provider's sampler.
  Sampler? get sampler => _sampler ?? _provider.sampler;

  /// The effective exception handling options used by [withSpan] /
  /// [withSpanAsync] when no per-call options are supplied.
  ///
  /// Falls back to the provider's [TracerProvider.spanExceptionOptions]
  /// (configured globally via `OTel.initialize(spanExceptionOptions: ...)`)
  /// and finally to a default [SpanExceptionOptions] that records the
  /// exception and sets the span status to error.
  SpanExceptionOptions get spanExceptionOptions =>
      _provider.spanExceptionOptions ?? SpanExceptionOptions.defaults;

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
  bool isEnabled({SpanKind? kind, Context? context}) =>
      _enabled && _provider.hasSpanProcessors;

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
  T withSpan<T>(
    APISpan span,
    T Function() fn, {
    SpanExceptionOptions? exceptionOptions,
  }) {
    // Per-call options are merged field-by-field over the tracer/provider
    // default (set globally via OTel.initialize), so overriding a single flag
    // preserves the globally configured sanitizer.
    final options = spanExceptionOptions.mergeWith(exceptionOptions);
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
            _handleSpanException(span, e, stackTrace, options);
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
  Future<T> withSpanAsync<T>(
    APISpan span,
    Future<T> Function() fn, {
    SpanExceptionOptions? exceptionOptions,
  }) async {
    // Per-call options are merged field-by-field over the tracer/provider
    // default (set globally via OTel.initialize), so overriding a single flag
    // preserves the globally configured sanitizer.
    final options = spanExceptionOptions.mergeWith(exceptionOptions);
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
            _handleSpanException(span, e, stackTrace, options);
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

  /// Creates a span without making it active in any context.
  ///
  /// Per the Trace SDK spec (SDK Span creation), this goes through the
  /// same pipeline as [startSpan]: the parent is resolved from [context]
  /// (or [Context.current]), the sampler is queried and the span
  /// processors are notified. Unlike [startSpan], it also accepts
  /// [spanEvents]. [root] forces a new trace with no parent, whatever the
  /// context holds.
  @override
  Span createSpan({
    required String name,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
    List<SpanLink>? links,
    List<SpanEvent>? spanEvents,
    DateTime? startTime,
    bool? isRecording,
    Context? context,
    bool root = false,
  }) {
    if (OTelLog.isDebug()) {
      OTelLog.debug('Tracer: Creating span with name: $name, kind: $kind');
    }

    return _startSpanInternal(
      name: name,
      context: context,
      root: root,
      kind: kind,
      attributes: attributes,
      links: links,
      spanEvents: spanEvents,
      startTime: startTime,
      isRecording: isRecording,
    );
  }

  /// Starts a new span.
  ///
  /// The parent comes from [context] (or [Context.current]) with the
  /// precedence documented on [APITracer.startSpan]: [root] > remote
  /// `SpanContext` > local span > valid non-remote `SpanContext` > new
  /// root. To parent a span explicitly, put the parent on a context:
  /// `startSpan('child', context: Context.current.withSpan(parent))`.
  ///
  /// [isRecording] defaults to null, which means the sampler's decision
  /// determines whether the span records. Passing false forces a
  /// non-recording span and clears the Sampled flag (the SDK MUST NOT
  /// produce Sampled == true with IsRecording == false); passing true
  /// cannot resurrect a span the sampler decided to drop.
  @override
  Span startSpan(
    String name, {
    Context? context,
    bool root = false,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
    List<SpanLink>? links,
    DateTime? startTime,
    bool? isRecording,
  }) {
    if (OTelLog.isDebug()) {
      OTelLog.debug('Tracer: Starting span with name: $name, kind: $kind');
    }

    return _startSpanInternal(
      name: name,
      context: context,
      root: root,
      kind: kind,
      attributes: attributes,
      links: links,
      startTime: startTime,
      isRecording: isRecording,
    );
  }

  /// Shared SDK span-creation pipeline, per the Trace SDK spec
  /// ("SDK Span creation"): resolve the parent from the context, generate
  /// a new SpanId, query the sampler's ShouldSample, create the span
  /// according to the decision, and notify the span processors.
  Span _startSpanInternal({
    required String name,
    Context? context,
    bool root = false,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
    List<SpanLink>? links,
    List<SpanEvent>? spanEvents,
    DateTime? startTime,
    bool? isRecording,
  }) {
    // Use a content-based check rather than `effectiveContext != Context.root`
    // — Context.root can carry the propagated context inside an isolate
    // spawned via Context.runIsolate (the API treats the receiving isolate's
    // root as the propagated starting context), so an identity-style check
    // would incorrectly skip parent inheritance there.
    final effectiveContext = context ?? Context.current;

    // The parent Context "that the SDK determined" (Trace SDK spec,
    // OnStart) is what both the sampler and the processors see. A root
    // span has no parent, so it is sampled and announced against the
    // context with its parent slot cleared; otherwise the parent resolves
    // from the context exactly as the API does without an SDK.
    final parentContext = root
        ? effectiveContext.withSpanContext(OTel.spanContextInvalid())
        : effectiveContext;
    final parent = root
        ? (parentSpanContext: null, parentSpan: null)
        : _resolveParent(effectiveContext);
    final parentSpanContext = parent.parentSpanContext;

    // Child spans inherit the trace ID, trace flags and TraceState of the
    // parent — per the Trace API spec (Span creation), "the child span
    // MUST inherit all TraceState values of its parent by default"; this
    // applies to local and remote parents alike. Root spans mint a trace.
    final traceId = parentSpanContext?.traceId ?? OTel.traceId();
    final parentSpanId = parentSpanContext?.spanId;
    var traceFlags = parentSpanContext?.traceFlags;
    var traceState = parentSpanContext?.traceState;

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
    bool? sampled; // null: no sampler configured, keep inherited flags
    if (sampler != null) {
      final samplingResult = sampler!.shouldSample(
        parentContext: parentContext,
        traceId: traceId.toString(),
        name: name,
        spanKind: kind,
        attributes: attributes,
        links: links,
      );

      // Map the decision onto the (IsRecording, Sampled) pair, per the
      // Trace SDK spec (ShouldSample):
      //   DROP              -> IsRecording false, Sampled MUST NOT be set
      //   RECORD_ONLY       -> IsRecording true,  Sampled MUST NOT be set
      //   RECORD_AND_SAMPLE -> IsRecording true,  Sampled MUST be set
      switch (samplingResult.decision) {
        case SamplingDecision.drop:
          shouldRecord = false;
          sampled = false;
        case SamplingDecision.recordOnly:
          shouldRecord = true;
          sampled = false;
        case SamplingDecision.recordAndSample:
          shouldRecord = true;
          sampled = true;
      }

      // Per the Trace SDK spec (ShouldSample), the Tracestate returned
      // by the sampler is associated with the Span through the new
      // SpanContext. An explicitly empty TraceState clears it; null
      // means the sampler has no opinion (samplers written before
      // SamplingResult.traceState existed keep parent inheritance).
      final samplerTraceState = samplingResult.traceState;
      if (samplerTraceState != null) {
        traceState = samplerTraceState.isEmpty ? null : samplerTraceState;
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

    // The sampler owns the recording decision. A caller may pass
    // isRecording: false to force a non-recording span, but can never
    // resurrect a dropped one (spec: DROP => IsRecording will be false).
    final recording = shouldRecord && (isRecording ?? true);

    // The SDK MUST NOT allow Sampled == true with IsRecording == false
    // (Trace SDK spec, Sampling — the combination causes gaps in the
    // distributed trace). A forced non-recording span is never sampled.
    if (!recording) {
      sampled = false;
    }

    if (sampled != null) {
      // The Sampled trace flag reflects the sampling decision only —
      // RECORD_ONLY records without setting the flag.
      traceFlags = OTel.traceFlags(
        sampled ? TraceFlags.SAMPLED_FLAG : TraceFlags.NONE_FLAG,
      );
    } else if (!recording && (traceFlags?.isSampled ?? false)) {
      // No sampler configured and flags inherited from the parent:
      // still clear Sampled on a forced non-recording span.
      traceFlags = OTel.traceFlags(TraceFlags.NONE_FLAG);
    }

    // Always create a new span context with a new span ID
    // For root spans, ensure we set an invalid parent span ID (zeros)
    final newSpanContext = OTel.spanContext(
      traceId: traceId,
      spanId: OTel.spanId(), // Always generate a new span ID
      parentSpanId: parentSpanId ??
          OTel.spanIdInvalid(), // Use invalid span ID for root spans
      traceFlags: traceFlags,
      traceState: traceState,
    );

    // Build the API span around the SpanContext decided above. The API
    // tracer's createSpan mints its own IDs and flags, so the SDK
    // constructs the span directly, the way the API package intends an
    // SDK to (its span.dart library exposes APISpanCreate for this).
    final delegateSpan = APISpanCreate.create(
      name: name,
      spanContext: newSpanContext,
      parentSpan: parent.parentSpan,
      instrumentationScope: _instrumentationScope,
      spanKind: kind,
      attributes: attributes,
      links: links,
      spanEvents: spanEvents,
      startTime: startTime,
      isRecording: recording,
      timeProvider: timeProvider,
    );

    // Wrap it in our SDK span which will handle processing
    final sdkSpan = SDKSpanCreate.create(
      delegateSpan: delegateSpan,
      sdkTracer: this,
      isRecording: recording,
    );

    // Notify processors. Per the Trace SDK spec (Sampling), span
    // processors MUST receive only spans with IsRecording == true.
    // OnStart receives "the parent Context of the span that the SDK
    // determined", so pass the resolved parentContext, never the raw
    // (possibly null) context argument.
    if (recording) {
      for (final processor in _provider.spanProcessors) {
        processor.onStart(sdkSpan, parentContext);
      }
    }

    return sdkSpan;
  }

  /// Resolves the parent a new span created in [context] should get, with
  /// the precedence [APITracer.startSpan] documents: remote `SpanContext`
  /// > local span > valid non-remote `SpanContext` > none. The `root` case
  /// is handled by the caller. This mirrors the API's own resolution so a
  /// given Context parents identically with and without an SDK.
  ///
  /// Every candidate must carry a valid [SpanContext]; an invalid
  /// (all-zero) one is skipped, so per trace/api.md it yields a root span
  /// rather than an error. Validity is the only filter: an *ended* span in
  /// the context is still a usable parent, which trace/api.md makes a MUST.
  static ({SpanContext? parentSpanContext, APISpan? parentSpan}) _resolveParent(
      Context context) {
    final contextSpanContext = context.spanContext;
    final contextSpan = context.span;

    if (contextSpanContext != null &&
        contextSpanContext.isValid &&
        contextSpanContext.isRemote) {
      // Remote context (propagator extract path) wins over a local span
      // in the same context. Context.withSpan writes both slots, so a
      // remote SpanContext wrapped in a non-recording span lands here
      // with the wrapper present: keep it as the parent object only when
      // it is the very span the remote SpanContext identifies.
      final contextSpanSc = contextSpan?.spanContext;
      final parentSpan = (contextSpanSc != null &&
              contextSpanSc.traceId == contextSpanContext.traceId &&
              contextSpanSc.spanId == contextSpanContext.spanId)
          ? contextSpan
          : null;
      return (parentSpanContext: contextSpanContext, parentSpan: parentSpan);
    }

    if (contextSpan != null && contextSpan.spanContext.isValid) {
      return (
        parentSpanContext: contextSpan.spanContext,
        parentSpan: contextSpan,
      );
    }

    if (contextSpanContext != null && contextSpanContext.isValid) {
      // A valid non-remote SpanContext with no span object behind it,
      // e.g. set via Context.withSpanContext. It still identifies a
      // parent, so the new span is a child of it rather than a fresh root.
      return (parentSpanContext: contextSpanContext, parentSpan: null);
    }

    return (parentSpanContext: null, parentSpan: null);
  }

  /// Like [startSpan] + [withSpan] but passes the started span to [fn]
  /// as an argument and ends the span when [fn] returns,
  /// so callers can attach attributes / events without going through
  /// `Context.current`. Routes through [withSpan] for activation;
  /// [withSpan] handles `recordException` / `setStatus(Error)` on throw,
  /// honoring [exceptionOptions].
  T startActiveSpan<T>({
    required String name,
    required T Function(APISpan span) fn,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
    SpanExceptionOptions? exceptionOptions,
  }) {
    final span = startSpan(name, kind: kind, attributes: attributes);
    try {
      return withSpan(span, () => fn(span), exceptionOptions: exceptionOptions);
    } finally {
      span.end();
    }
  }

  /// Async variant of [startActiveSpan]. Routes through [withSpanAsync]
  /// for activation; [withSpanAsync] handles `recordException` /
  /// `setStatus(Error)` on throw, honoring [exceptionOptions].
  Future<T> startActiveSpanAsync<T>({
    required String name,
    required Future<T> Function(APISpan span) fn,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
    SpanExceptionOptions? exceptionOptions,
  }) async {
    final span = startSpan(name, kind: kind, attributes: attributes);
    try {
      return await withSpanAsync(
        span,
        () => fn(span),
        exceptionOptions: exceptionOptions,
      );
    } finally {
      span.end();
    }
  }

  /// Applies [options] when [fn] throws inside [withSpan] / [withSpanAsync].
  ///
  /// Default behavior (no sanitizer): records the exception and sets the
  /// span status to [SpanStatusCode.Error], each gated by
  /// [SpanExceptionOptions.recordException] and
  /// [SpanExceptionOptions.setStatusOnException].
  ///
  /// When a [SpanExceptionOptions.exceptionSanitizer] is provided, it is
  /// invoked first and only its returned [SanitizedSpanException] values are
  /// recorded — the original exception's type, message, and stack trace are
  /// never recorded, so unsanitized data cannot leak. If the sanitizer
  /// throws, the span is marked with [SpanStatusCode.Error] using a generic
  /// description (when status updates are enabled) and the exception is not
  /// recorded.
  ///
  /// The caller always rethrows the original exception; this method never
  /// throws.
  void _handleSpanException(
    Span span,
    Object error,
    StackTrace stackTrace,
    SpanExceptionOptions options,
  ) {
    final sanitizer = options.exceptionSanitizer;
    if (sanitizer != null) {
      // Nothing to sanitize for if neither recording nor status is enabled.
      if (!options.recordException && !options.setStatusOnException) {
        return;
      }
      SanitizedSpanException sanitized;
      try {
        sanitized = sanitizer(error, stackTrace);
      } catch (sanitizerError) {
        if (OTelLog.isError()) {
          OTelLog.error(
            'Tracer: exceptionSanitizer threw while handling an exception '
            'on span ${span.name}: $sanitizerError',
          );
        }
        // The sanitizer failed, so we cannot safely record the original
        // (possibly sensitive) exception. Mark the span as failed with a
        // generic description instead.
        if (options.setStatusOnException) {
          span.setStatus(SpanStatusCode.Error, 'Exception sanitizer failed');
        }
        return;
      }
      if (options.recordException) {
        // Pass only the sanitized type/message/stacktrace. recordException
        // derives defaults from `error`, but the attribute overrides below
        // replace them, and the original stack trace is never forwarded.
        span.recordException(
          error,
          stackTrace: sanitized.stackTrace,
          attributes: OTel.attributesFromMap(<String, Object>{
            ExceptionAttributes.exceptionType.key: sanitized.type,
            ExceptionAttributes.exceptionMessage.key: sanitized.message,
          }),
        );
      }
      if (options.setStatusOnException) {
        span.setStatus(
          SpanStatusCode.Error,
          sanitized.statusDescription ?? sanitized.message,
        );
      }
      return;
    }

    if (options.recordException) {
      span.recordException(error, stackTrace: stackTrace);
    }
    if (options.setStatusOnException) {
      span.setStatus(SpanStatusCode.Error, error.toString());
    }
  }
}
