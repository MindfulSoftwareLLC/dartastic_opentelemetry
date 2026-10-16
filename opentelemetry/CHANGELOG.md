# Changelog

All notable changes to the `opentelemetry` 1.x line are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic
Versioning](https://semver.org/spec/v2.0.0.html).

Each `1.0.0-beta.N` release is a cross-post of `dartastic_opentelemetry` `1.1.0-beta.N` (see README.md), and its
section carries that release's entry. Versions 0.18.x and earlier are Workiva's implementation, now published as
[`opentelemetry_wk`](https://pub.dev/packages/opentelemetry_wk); their history is in
[its changelog](https://pub.dev/packages/opentelemetry_wk/changelog).

<!-- Sections below are written by tool/opentelemetry_release.dart. -->

## [1.0.0-beta.17] - 2026-10-16

Cross-post of [`dartastic_opentelemetry` 1.1.0-beta.17](https://pub.dev/packages/dartastic_opentelemetry/versions/1.1.0-beta.17), which this release is pinned to and re-exports. Its CHANGELOG entry follows.

The spec-compliance issues this release closes ([#106](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/106), 
[#111](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/111), 
[#115](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/115), 
[#142](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/142), 
[#143](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/143), 
[#144](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/144), 
[#145](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/145), 
[#193](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/193), 
[#194](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/194), 
[#224](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/224))
were written by @michaelbushe and @yuzurihaaa; each entry credits the pull requests that made the change.

### Changed

- **BREAKING**: Built on `dartastic_opentelemetry_api` 1.0.0-rc.4. The API's breaking changes
  ([api CHANGELOG](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/blob/main/CHANGELOG.md)) apply
  to SDK users through the re-exported API: `Baggage.getAllValues()` returns `Map<String, BaggageEntry>`,
  `Context.copyWithValue` is gone, `TraceFlags.fromString` returns null on invalid input, and `APISpan` no longer
  exposes its recorded data. `OTel.traceIdFrom` and `OTel.spanIdFrom` accept only lowercase hex and return an invalid
  (all-zero) id for malformed input instead of throwing `FormatException`. `APIMeterProvider` no longer has
  `endpoint`, `serviceName`, `serviceVersion`, `enabled` or `isShutdown`; the SDK `MeterProvider` that
  `OTel.meterProvider()` returns keeps them
  ([api#112](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/112) by @robert-northmind,
  [api#113](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/113) by @harshitt13,
  [api#127](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/127) by @harshitt13, 
  [api#130](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/130) by @harshitt13,
  [api#114](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/114) by @robert-northmind, 
  [api#137](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/137) by @i-am-paradox, 
  [api#140](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/140) by @michaelbushe, 
  [#309](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/309) by @michaelbushe).
- **BREAKING**: `Tracer.startSpan` and `Tracer.createSpan` no longer take `parentSpan` or `spanContext`. The parent
  comes from the `Context` (or `Context.current`) with the precedence the API documents: 
  `root` > remote `SpanContext` > local span > valid non-remote `SpanContext` > new root.
  `parentSpan: parent` becomes `context: Context.current.withSpan(parent)`; a `SpanContext` placed on the context with `withSpanContext` parents a
  child of it (new span ID, `parentSpanId` set), which replaces the old verbatim `spanContext:` behavior of
  `createSpan`. Both methods accept `root: true` to force a new trace, and `startSpan` accepts `startTime`
  ([api#118](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/118) by @harshitt13, [#309](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/309)).
- `Span.attributes`, `spanEvents`, `spanLinks`, `status` and `statusDescription` are SDK accessors now, read through
  the API's `ReadableSpan`, since `APISpan` no longer exposes them
  ([api#140](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/140) by @michaelbushe). Exporters and processors
  that hold the SDK `Span` are unaffected; `Span.attributes` is no longer marked `@visibleForTesting`
  ([#309](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/309)).
- `MeterProvider` now owns its `endpoint`, `serviceName`, `serviceVersion`, `enabled` and `isShutdown` state instead
  of forwarding to the API provider, which no longer holds any
  ([api#113](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/113) by @harshitt13). The SDK surface is
  unchanged for callers ([#309](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/309)).
- `Meter.createHistogram` reads its bucket boundaries from `advisory.explicitBucketBoundaries` when the deprecated
  `boundaries` parameter is absent; when both are given, `boundaries` wins, matching the API
  ([api#113](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/113) by @harshitt13, [#309](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/309)).
- A sum `Metric` with no `isMonotonic` value is now exported as non-monotonic: OTLP sends `is_monotonic: false` and
  the Prometheus exporter types it as `gauge`. Before, both assumed monotonic. SDK instruments always set the value, so
  only a `Metric(type: MetricType.sum)` built by hand without `isMonotonic` is affected. `Metric.sum()` still defaults
  to `isMonotonic: true`
  ([#307](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/307) by @yuzurihaaa).
- **BREAKING**: The Prometheus exporter now types a non-monotonic sum, including every `UpDownCounter`, as `gauge`,
  not `counter`, which compatibility/prometheus_and_openmetrics.md specifies. PromQL that applies `rate()` or
  `increase()` to these series needs updating
  ([#307](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/307) by @yuzurihaaa).

### Added

- `Meter.registerBatchCallback(callback, instruments)` runs one callback that observes several asynchronous instruments
  at once, once per collection, before those instruments collect; the returned registration's `unregister()` stops it.
  An instrument from another meter is reported through `OTelErrorHandling` and the callback is not registered; an
  observation for an instrument the callback was not registered with is dropped and reported
  ([api#113](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/113) by @harshitt13, [#309](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/309)).
- `InstrumentAdvisory` is accepted by all seven `Meter.create*` methods and exposed as `advisory` on every SDK and no-op
  instrument. The three `createObservable*` methods accept a `callbacks` list
  ([api#113](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/113) by @harshitt13, [#309](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/309)).

### Deprecated

- The `boundaries` parameter on `Meter.createHistogram` and the `boundaries` getter on `Histogram`; use
  `InstrumentAdvisory.explicitBucketBoundaries`. The `callback` parameter on the three `createObservable*` methods; use
  `callbacks`, to which a `callback` is prepended
  ([api#113](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/113) by @harshitt13, [#309](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/309)).

### Fixed

- `W3CTraceContextPropagator.extract` rejects a `traceparent` whose trace-id, parent-id or trace-flags field is not
  lowercase hex, as context/api-propagators.md requires. Before, uppercase or signed hex in the IDs was accepted and an
  invalid trace-flags field defaulted the flags
  ([api#112](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/112) by @robert-northmind, [api#114](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/114) by @robert-northmind,
  [api#137](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/137) by @i-am-paradox, [#309](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/309)).
- **The OTLP log exporters now send `event_name`.** `LogRecord.eventName` was never copied onto the wire, so every
  event emitted with `emit(eventName: ...)` arrived at the collector as a plain log record with no name, and anything
  filtering on `event_name` saw nothing. The bundled protobuf definitions were generated from opentelemetry-proto
  v1.1.0, which predates the field; they are regenerated from v1.11.0, which adds `LogRecord.event_name` and the
  `EntityRef` and string-table fields on `Resource`, `AnyValue` and `KeyValue`. No generated type was removed
  ([#303](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/303) by @michaelbushe).
- The OTLP log exporters write an instrumentation scope's schema URL to `ScopeLogs.schema_url`, where
  logs/data-model.md and the OTLP proto place it, instead of to `ResourceLogs.schema_url`, which describes the resource
  and now carries the `Resource`'s own schema URL. Loggers whose scopes differ only by schema URL are no longer merged
  into one `ScopeLogs` ([#303](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/303) by @michaelbushe).
- A synchronous `UpDownCounter` is now exported as a non-monotonic sum, which metrics/sdk.md makes a MUST for Sum
  aggregation. Before, OTLP exported it with `is_monotonic: true`. `Counter` now sets `isMonotonic: true` explicitly
  ([#307](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/307) by @yuzurihaaa).
- `TraceIdRatioSampler.description` is `TraceIdRatioBased{RATIO}`, the name trace/sdk.md gives the sampler, instead of
  `TraceIdRatioSampler{RATIO}` ([#298](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/298) by @LaPyaeOo).
- OTLP/HTTP exporters now retry transient errors for the retryable HTTP status codes 429, 502, 503 and 504, as
  protocol/exporter.md requires (MUST). Before, 502 and 504 failed the export without a retry, and retryability was
  decided by matching the exception message instead of the status code
  ([#305](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/pull/305) by @LaPyaeOo).

