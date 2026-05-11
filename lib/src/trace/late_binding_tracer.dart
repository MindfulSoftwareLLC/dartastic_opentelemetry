// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Late-binding proxy implementations of [TracerProvider] and [Tracer].
///
/// ## The problem these solve
///
/// The OpenTelemetry spec says: in the absence of an installed SDK, the API
/// must behave as a noop. The Dartastic API honors that by lazy-installing
/// a noop `OTelAPIFactory` on first access. When `OTel.initialize` runs
/// later, it upgrades that noop factory to a real SDK factory.
///
/// Library code that captures references at module load — e.g. Genkit's
/// `final _tracer = otel.tracerProvider().getTracer('genkit-dart')` — runs
/// *before* the user's `main()` has a chance to call `OTel.initialize`.
/// Without late binding, that captured `_tracer` would point at the noop
/// SDK wrapper forever; spans created through it after init would still
/// be noops, even though `OTel.tracer()` (called later) would return a
/// real, SDK-backed Tracer.
///
/// ## How the proxy fixes it
///
/// `OTel.tracerProvider()` and `OTel.tracer()` (and the named variants)
/// return cached *proxy* instances — [LateBindingTracerProvider] and
/// [LateBindingTracer]. The proxies hold no state beyond their
/// identifying tuple (`name`/`version`/`schemaUrl`); every method,
/// getter, and setter forwards to a fresh `_resolveReal()` lookup that
/// asks `OTel` for the current underlying SDK provider or tracer.
///
/// Pre-init, that underlying is a noop SDK wrapper around the API noop
/// factory. Post-init, it's the real SDK provider installed by
/// `OTel.initialize`. The proxy's identity is stable across the
/// transition, so the captured `_tracer` reference in Genkit-style code
/// transparently starts producing real spans the moment initialization
/// completes.
///
/// ## Why this design over alternatives
///
/// - **Returning a different object pre vs post-init** (the prior design)
///   left captured references stale. Fine for `OTel.tracer()` called
///   after init, but the entire point is to support module-load capture
///   that runs before init.
/// - **Mutable-delegate swap inside the SDK noop wrapper** would also
///   work but requires non-final fields across `TracerProvider`,
///   `Tracer`, `Span` caches, etc. — a much wider surface change.
/// - **Late-binding proxies** scope the indirection to a single new
///   class per signal and leave the existing SDK classes untouched.
///
/// Matches Java's `GlobalOpenTelemetry.get()` / `getTracer()` shape:
/// callers receive an obliviously-late-binding entry point and don't
/// have to care whether the SDK has been initialized yet.
///
/// ## Limitations
///
/// Late binding applies at the [TracerProvider] / [Tracer] layer. A
/// span returned by `tracer.startSpan(...)` is a concrete one-shot
/// object created against whatever underlying tracer was resolved at
/// that moment, so spans created pre-init are still noop spans even
/// after a later `OTel.initialize` call. That's the spec-correct
/// outcome — a span represents work that's already happening; you can't
/// retroactively make it recorded.
library;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../otel.dart';
import '../resource/resource.dart';
import 'sampling/sampler.dart';
import 'span.dart';
import 'span_processor.dart';
import 'tracer.dart';
import 'tracer_provider.dart';

/// A [TracerProvider] proxy that re-resolves its underlying SDK
/// TracerProvider on every call.
///
/// Constructed and cached by [OTel] keyed by provider name (`null` for
/// the default provider). Instance identity is stable across
/// `OTel.initialize` — exactly the property that makes module-load
/// references work after initialization.
class LateBindingTracerProvider implements TracerProvider {
  /// Name of the underlying provider (`null` = the global default).
  final String? _providerName;

  /// Internal: do not construct directly. Use `OTel.tracerProvider(name: ...)`.
  LateBindingTracerProvider(this._providerName);

  /// Resolve the current real (non-proxy) TracerProvider — either the
  /// SDK-backed one installed by `OTel.initialize`, or the noop SDK
  /// wrapper around the API noop factory if init hasn't happened yet.
  TracerProvider _real() => OTel.internalResolveRealTracerProvider(_providerName);

  @override
  Tracer getTracer(
    String name, {
    String? version,
    String? schemaUrl,
    Attributes? attributes,
    Sampler? sampler,
  }) {
    // Forward to the real provider for its side effects: shutdown
    // guard (throws StateError on a shut-down provider), debug logging,
    // and priming of its internal Tracer cache. We discard the
    // returned real Tracer and hand back a late-binding proxy so the
    // caller's captured reference stays usable across `OTel.initialize`.
    _real().getTracer(
      name,
      version: version,
      schemaUrl: schemaUrl,
      attributes: attributes,
      sampler: sampler,
    );
    return OTel.internalGetCachedLateBindingTracer(
      providerName: _providerName,
      name: name,
      version: version,
      schemaUrl: schemaUrl,
      attributes: attributes,
      sampler: sampler,
    );
  }

  @override
  Resource? get resource => _real().resource;
  @override
  set resource(Resource? value) => _real().resource = value;

  @override
  Sampler? get sampler => _real().sampler;
  @override
  set sampler(Sampler? value) => _real().sampler = value;

  @override
  TimeProvider get timeProvider => _real().timeProvider;
  @override
  set timeProvider(TimeProvider value) => _real().timeProvider = value;

  @override
  bool get isShutdown => _real().isShutdown;
  @override
  set isShutdown(bool value) => _real().isShutdown = value;

  @override
  String get endpoint => _real().endpoint;
  @override
  set endpoint(String value) => _real().endpoint = value;

  @override
  String get serviceName => _real().serviceName;
  @override
  set serviceName(String value) => _real().serviceName = value;

  @override
  String? get serviceVersion => _real().serviceVersion;
  @override
  set serviceVersion(String? value) => _real().serviceVersion = value;

  @override
  bool get enabled => _real().enabled;
  @override
  set enabled(bool value) => _real().enabled = value;

  @override
  Future<bool> shutdown() => _real().shutdown();

  @override
  Future<void> forceFlush() => _real().forceFlush();

  @override
  void addSpanProcessor(SpanProcessor processor) =>
      _real().addSpanProcessor(processor);

  @override
  List<SpanProcessor> get spanProcessors => _real().spanProcessors;

  @override
  void ensureResourceIsSet() => _real().ensureResourceIsSet();
}

/// A [Tracer] proxy that re-resolves its underlying SDK Tracer on every
/// call.
///
/// Constructed and cached by [OTel] keyed by `(providerName, name,
/// version, schemaUrl)`. Identity is stable across `OTel.initialize`;
/// every method/getter calls [_real] which routes through the current
/// real TracerProvider.
class LateBindingTracer implements Tracer {
  final String? _providerName;
  @override
  final String name;
  @override
  final String? version;
  @override
  final String? schemaUrl;
  Attributes? _attributes;
  final Sampler? _explicitSampler;
  bool _enabled = true;

  /// Internal: do not construct directly. Use
  /// `OTel.tracerProvider().getTracer(...)` or `OTel.tracer()`.
  LateBindingTracer({
    required String? providerName,
    required this.name,
    this.version,
    this.schemaUrl,
    Attributes? attributes,
    Sampler? sampler,
  })  : _providerName = providerName,
        _attributes = attributes,
        _explicitSampler = sampler;

  /// Resolve the current real (non-proxy) Tracer for this proxy's
  /// `(name, version, schemaUrl)` tuple. Pre-init this returns a noop
  /// SDK Tracer wrapping the API noop tracer; post-init it returns the
  /// real SDK Tracer from the installed factory.
  Tracer _real() {
    final provider = OTel.internalResolveRealTracerProvider(_providerName);
    return provider.getTracer(
      name,
      version: version,
      schemaUrl: schemaUrl,
      attributes: _attributes,
      sampler: _explicitSampler,
    );
  }

  @override
  Attributes? get attributes => _attributes;
  @override
  set attributes(Attributes? value) {
    _attributes = value;
    // Keep the underlying tracer's attributes in sync — `Tracer` exposes
    // a setter, and the real implementation may use the value the next
    // time it builds an instrumentation scope.
    _real().attributes = value;
  }

  @override
  bool get enabled => _enabled && _real().enabled;
  @override
  set enabled(bool value) {
    _enabled = value;
    _real().enabled = value;
  }

  @override
  APISpan? get currentSpan => _real().currentSpan;

  @override
  TimeProvider get timeProvider => _real().timeProvider;

  @override
  Sampler? get sampler => _real().sampler;

  @override
  TracerProvider get provider {
    // Return the proxy provider so identity stays stable for callers.
    return OTel.tracerProvider(name: _providerName);
  }

  @override
  Resource? get resource => _real().resource;

  @override
  T withSpan<T>(APISpan span, T Function() fn) => _real().withSpan(span, fn);

  @override
  Future<T> withSpanAsync<T>(APISpan span, Future<T> Function() fn) =>
      _real().withSpanAsync(span, fn);

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
  }) =>
      _real().createSpan(
        name: name,
        spanContext: spanContext,
        parentSpan: parentSpan,
        kind: kind,
        attributes: attributes,
        links: links,
        spanEvents: spanEvents,
        startTime: startTime,
        isRecording: isRecording,
        context: context,
      );

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
  }) =>
      _real().startSpan(
        name,
        context: context,
        spanContext: spanContext,
        parentSpan: parentSpan,
        kind: kind,
        attributes: attributes,
        links: links,
        isRecording: isRecording,
      );

  @Deprecated(
      'Use startSpan(name, context: ctx) and tracer.withSpan/withSpanAsync to activate the returned span.')
  @override
  APISpan startSpanWithContext({
    required String name,
    required Context context,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
  }) =>
      _real().startSpanWithContext(
        name: name,
        context: context,
        kind: kind,
        attributes: attributes,
      );

  @override
  T startActiveSpan<T>({
    required String name,
    required T Function(APISpan span) fn,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
  }) =>
      _real().startActiveSpan<T>(
        name: name,
        fn: fn,
        kind: kind,
        attributes: attributes,
      );

  @override
  Future<T> startActiveSpanAsync<T>({
    required String name,
    required Future<T> Function(APISpan span) fn,
    SpanKind kind = SpanKind.internal,
    Attributes? attributes,
  }) =>
      _real().startActiveSpanAsync<T>(
        name: name,
        fn: fn,
        kind: kind,
        attributes: attributes,
      );
}
