# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [1.1.0-beta.15-wip]

### Fixed

- **The programmatic `secure` parameter is honored by the logs and metrics
  configurations** (#253). `LogsConfiguration.configureLoggerProvider` and
  `MetricsConfiguration.configureMeterProvider` declared `bool secure = false`
  and passed it as the lowest-precedence fallback, so the parameter was a
  no-op whenever the endpoint carried a scheme — which both defaults do. It is
  now `bool? secure`: a non-null value is the caller's explicit choice and
  outranks `OTEL_EXPORTER_OTLP_INSECURE`, while `null` (the default) defers to
  the endpoint scheme, then the environment, then the built-in default.

  Precedence now follows `protocol/exporter.md`: the endpoint **scheme**
  decides when there is one (an `https` or `http` scheme "takes precedence
  over the `insecure` configuration setting"), so the setting applies only
  to OTLP/gRPC with a scheme-less endpoint such as `my-collector:4317` —
  the one case where nothing else can express the choice. Previously an
  explicit value outranked the scheme, meaning `secure: true` alongside an
  `http://` endpoint produced TLS against the spec. Fixes #225.

  `OTel.initialize` now forwards the caller's original value rather than the
  boolean it resolved for the traces signal. Without that, a plaintext generic
  endpoint could turn TLS **off** for a signal the operator had pointed at an
  `https://` endpoint via `OTEL_EXPORTER_OTLP_{LOGS,METRICS}_ENDPOINT`.

## [1.1.0-beta.14] - 2026-08-23

### Changed
- **Requires `dartastic_opentelemetry_api` ^1.0.0-rc.2.** Picks up the
  semantic conventions at registry v1.44.0 — including the full
  `browser.web_vital.*` set — and three spec-compliance fixes.

  One of those changes behaviour visible from this package:
  `Context.withSpanContext` now returns a derived Context when the incoming
  span context belongs to a different trace, instead of throwing
  `ArgumentError`. Per the Context specification a set-value operation always
  returns a derived Context, and per the Propagators API `extract` must never
  throw — receiving a valid span context for another trace during extraction
  is ordinary, not an error. Four tests that asserted the throw now assert the
  derived Context.

  `SDKSpan.end()` no longer forwards the deprecated `spanStatus` argument to
  its delegate; `setStatus()` had already applied it to the same delegate, so
  the second pass was redundant.


- **BREAKING (spec compliance): sampler decisions are now honored end to end**
  (#120, #121, #122, #123, #129). A `Drop` decision produces a non-recording
  span that reaches no processor; `RecordOnly` records without setting the
  W3C `Sampled` flag; built-in processors deliver only recording spans to
  `onStart`/`onEnd` and only sampled spans to exporters, per the spec's
  IsRecording/Sampled reaction table; the forbidden Sampled+non-recording
  combination is unrepresentable; `createSpan` routes through the sampler and
  processors instead of bypassing them. Code that relied on unsampled or
  dropped spans being exported must adjust its sampler configuration.

- **BREAKING (spec compliance): the default sampler is now
  `ParentBased(root: AlwaysOn)`** instead of bare `AlwaysOn` (#126). Root
  spans still sample by default, but child spans of unsampled remote or local
  parents now respect the parent's decision. Pass
  `sampler: const AlwaysOnSampler()` to restore the old behavior.

- **Child spans inherit the parent `TraceState`** (#124), and
  **`SamplingResult` gains a `traceState` field** (#125) so samplers can
  modify or replace it: `null` keeps the inherited parent TraceState, an
  explicitly empty `TraceState` clears it. Existing custom samplers keep
  working unchanged.

- **BREAKING**: `OTelEnv` configuration functions (`getOtlpConfig`, `getBspConfig`, `getServiceConfig`, `getLogRecordLimits`, etc.) now return strongly-typed Dart Records instead of `Map<String, dynamic>`.
  Migration hint: Update map accesses to record property accesses (e.g., `config['endpoint'] as String?` → `config.endpoint`).

### Added

- `TracerProvider.hasSpanProcessors` — allocation-free check for registered
  span processors.

- **OTLP exporters send an identifying `User-Agent` header.** Per the OTLP
  spec, OTLP requests SHOULD identify the exporter, language, and version.
  Every OTLP request now carries `OTel-OTLP-Exporter-Dart/<version>` (HTTP
  headers on the HTTP exporters; `ChannelOptions.userAgent` on the gRPC
  exporters). A user-supplied `user-agent` header is prepended to the default
  rather than replacing it (#228).

- **`OTel.defaultGrpcEndpoint`** (`http://localhost:4317`), the OTLP/gRPC
  default endpoint. The endpoint default is now picked per signal after the
  protocol is resolved instead of defaulting everything to the HTTP port
  4318 (#220).

### Fixed

- **`browser.*` resource attributes and `user_agent.original` are now
  populated on web** (#190). Invalid `@JS` bindings made the web resource
  detector throw on first use; the error was swallowed and the attributes
  were silently missing. A detector failure now omits attributes instead of
  emitting blanks.

- **`browser.mobile` is now a boolean**, which is how the registry types it.
  It was emitted as the string `'true'`/`'false'`, so a backend filtering
  `browser.mobile = true` matched nothing.

- **`browser.languages` is now a string array, and its key comes from the
  API.** It was a comma-joined string under a key this package declared
  privately. The naming rules say an attribute that can represent multiple
  entities "SHOULD be pluralized and the value type SHOULD be an array",
  which is also how the registry shapes the neighbouring `browser.brands`.
  The key is now `BrowserCandidate.browserLanguages`, staged in the API as an
  upstream candidate, so the name and the argument for it live in one place.
  It is set only when the browser reports languages: an empty array is a real
  value on the wire and would claim the browser accepts none.

- **`browser.vendor` is no longer emitted.** `navigator.vendor` is a frozen
  legacy API that returns a hardcoded vendor string rather than the real
  vendor, and the registry's `browser.brands` is the structured answer to
  the same question.

- **`browser.mobile` is now correct on iPad.** Since iPadOS 13 an iPad
  requests desktop sites by default and reports a `Macintosh` user agent,
  so a user-agent test alone reported every iPad as a desktop. The
  detector now also consults `navigator.maxTouchPoints`, which
  distinguishes a touch device from a Mac. A touchscreen laptop is still
  not mobile — both signals have to agree.

- **`OtlpHttpMetricExporter.forceFlush()` and `shutdown()` now await
  in-flight exports** (#262). Both returned immediately, and `shutdown()`
  closed the HTTP client under the live request — failing an export that
  was about to succeed. Now matches the span and log HTTP exporters.

- `Tracer.enabled` now returns `false` when `TracerProvider` has no span
  processor(s) registered, per the Trace SDK spec, sparing span-creation cost
  when nothing is listening. Thanks to @abidiahmedcom (#138, #175).

- **OTLP/gRPC exporters now default to port 4317, not 4318.** The OTLP spec
  defaults the endpoint to `http://localhost:4317` for OTLP/gRPC and
  `http://localhost:4318` for the two HTTP protocols. Previously a single
  4318 default was applied before the protocol was known, so gRPC-only
  deployments silently exported to the wrong port (#220).

- **An empty environment variable value is treated as unset.** Per the spec,
  an empty value of an environment variable MUST be interpreted the same way
  as when the variable is unset. `EnvironmentService.getValue` now normalizes
  empty strings to `null`, so every consumer (endpoint, protocol, service
  name, log level, …) reads an empty value as unset (#213).

  Thanks to @abidiahmedcom; reported by @yuzurihaaa (#213, #220, #228).

- **`service.name` in `OTEL_RESOURCE_ATTRIBUTES` no longer overrides an
  explicit `serviceName:` argument or `OTEL_SERVICE_NAME`** (#103).
  Precedence is now, highest first: explicit argument, `OTEL_SERVICE_NAME`,
  `OTEL_RESOURCE_ATTRIBUTES`, default. `service.version` follows the same
  order.

- `OTEL_LOG_LEVEL` now takes effect at the start of `OTel.initialize`, so
  debug logging covers the environment parsing itself.

- **Baggage values containing `=` (e.g. base64 padding) are no longer
  dropped** on extract, and an unparsable `baggage` header leaves existing
  baggage untouched instead of clearing it. Thanks to @abidiahmedcom
  (#199, #200, #261).

## [0.10.0] - 2026-08-23
Stable-channel republication of `1.1.0-beta.14`. Depends on
`dartastic_opentelemetry_api: ^0.10.0`.

The minor bump from `0.9.8` carries three **breaking** spec-compliance
changes:

- **Sampler decisions are honored end to end** (#120–#123, #129): dropped
  spans reach no processor, `RecordOnly` no longer sets the W3C `Sampled`
  flag, and exporters receive only sampled spans. Adjust your sampler
  configuration if you relied on unsampled spans being exported.
- **The default sampler is `ParentBased(root: AlwaysOn)`** (#126): child
  spans now respect an unsampled parent. Pass
  `sampler: const AlwaysOnSampler()` to restore the old behavior.
- **`OTelEnv` configuration functions return typed Dart Records** instead
  of `Map<String, dynamic>` (`config['endpoint'] as String?` →
  `config.endpoint`).

Also notable: OTLP/gRPC exporters default to port 4317 per the OTLP spec
(#220), OTLP requests carry an identifying `User-Agent` (#228), empty
environment variables read as unset (#213), `service.name` precedence is
fixed (#103), `browser.*` resource attributes are populated on web (#190)
with `browser.mobile` as a boolean, and baggage values containing `=`
survive extraction (#199). Full detail in the `1.1.0-beta.14` entry.

- **BREAKING: W3C Baggage now percent-encodes per the W3C grammar instead of
  form-style encoding** (#198, #197, #264). Values encode every byte outside
  the W3C `baggage-octet` allowlist (`%` → `%25`, space → `%20`,
  `,`/`;`/`"`/`\`/`:` escaped, controls and non-ASCII UTF-8 percent-encoded)
  instead of sending space as `+`; keys travel as raw RFC 7230 tokens, and
  keys that are not valid tokens are dropped on inject and ignored on
  extract; metadata is encoded too, so it can no longer forge additional
  header entries; extract ignores unparsable list members instead of
  throwing into the caller (which also blocked `traceparent` parsing).
  Migration hint: the previous release decoded `+` as space — during a
  rolling deploy against it, entries with spaces or `+` in values (e.g.
  `key+with+spaces`) can be lost or misread at the version boundary; use
  token keys and expect literal `+` in values on mixed fleets.

## [1.1.0-beta.13] - 2026-08-13

### Security

- **OTLP header values are no longer written to the debug log.** Two leaks are fixed:
  - Debug logging logged the raw values of all `OTEL_EXPORTER_OTLP_HEADERS` and the 
    signal-specific `OTEL_EXPORTER_OTLP_{TRACES,METRICS,LOGS}_HEADERS`. The message was
    emitted above the per-header loop that redacts `Authorization`, so the credential
    reached the log regardless of that redaction. Thanks to @arpitjain099 (#100).
  - `OtlpHttpSpanExporter` and `OtlpHttpLogRecordExporter` printed every header value
    except `Authorization`, at construction and on each export request — including
    headers configured in code, which never pass through an environment variable.

  **Who is affected:** applications running with `OTEL_LOG_LEVEL=DEBUG` (or `OTelLog` at
  debug) and a credential in an OTLP header, from the environment or from exporter
  config. Treat any debug logs collected from an affected build as containing that
  credential and rotate it.

  Tracked as [GHSA-4rh6-c2v5-374w](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/security/advisories/GHSA-4rh6-c2v5-374w)
  (CWE-532). Affects `>= 1.0.0-alpha` on this line and `>= 0.9.0` on the stable
  channel; see the 0.9.8 entry.

### Added

- **`OTEL_DART_HEADER_LOG_ALLOWLIST`**, and `OTel.initialize(otlpHeaderLogAllowlist:)`,
  name the OTLP headers whose values may appear in the debug log (#96). 
  Names match exactly, case insensitively; the code parameter replaces
  the environment variable rather than adding to it; `authorization` and
  `proxy-authorization` are never logged even when listed. Thanks to @arpitjain099 (#101).

### Changed

- Debug logs now print `name: [REDACTED]` for any header value not on the allowlist,
  replacing `Authorization: [REDACTED - length: N]` — the length is dropped on purpose,
  since it narrows the search space for the token. Header names and the header count are
  still logged. A header value you relied on seeing at debug level now has to be listed
  in `OTEL_DART_HEADER_LOG_ALLOWLIST`.

## [1.1.0-beta.12] - 2026-07-20

### Changed
- **Internal attribute keys now come from the generated registry enums**
  (`Service.*`, `ExceptionAttributes.*`, `Otel.*`) instead of string
  literals, across resource creation, exception recording, the
  `package:logging` bridge, the OTLP span/log transformers, the sampler,
  and the env resource-attribute parsing. A mistyped key is now a compile
  error — the same hardening applied to the resource detector after #90.
  No wire change: `Enum.key` resolves to the identical registry string.
  
### Fixed
- **`host.arch` no longer reports the hostname** (#90). The IO resource
  detector copy-pasted `Platform.localHostname` into `host.arch`; it now
  resolves the real CPU architecture (`amd64`/`arm64`/`arm32`/`x86`/…)
  from `Platform.version`, mapped to registry values, and omits the
  attribute when it can't be parsed. Fixes downstream consumers that
  select per-architecture artifacts (e.g. debug symbols) off the resource.
- The IO detector now keys every attribute from the generated registry
  enums (`Host.*`, `Os.*`, `ProcessAttributes.*`) instead of string
  literals, so a mistyped key is a compile error — the class of bug that
  caused #90. The malformed `host.os.name` is corrected to `os.name`.

### Removed
- The IO resource detector no longer emits `host.processors`,
  `host.locale`, or `process.num_threads` — none are OpenTelemetry
  registry attributes.

## [1.1.0-beta.11] - 2026-07-20
### Changed
- Doc only, README.md platform updates and clarity.

## [1.1.0-beta.10] - 2026-07-20

### Fixed
- **`W3CBaggagePropagator.extract` no longer discards the incoming
  context when the `baggage` header is absent** (#87). It returned a
  fresh context instead of the passed one, so in the spec-default
  composite (tracecontext, then baggage) any request carrying
  `traceparent` but no `baggage` header lost its just-extracted span
  context — breaking traces at every service boundary unless callers
  hand-ordered extraction. Per the Propagators API spec, extract now
  returns the passed context unchanged when there is nothing to extract.
- **OTLP endpoint schemes now determine TLS per the OTLP spec** (#88).
  `http://` endpoints connect insecure and `https://` secure;
  `OTEL_EXPORTER_OTLP_INSECURE` (and per-signal variants) applies only
  to scheme-less endpoints, and an explicit programmatic `secure` still
  wins. Previously `OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4317`
  attempted TLS and failed with a HandshakeException unless the
  insecure flag was also set. Resolution is shared across all three
  signals via `OTelEnv.resolveOtlpSecure`; metrics additionally now
  honor `OTEL_EXPORTER_OTLP_METRICS_INSECURE`, which was parsed but
  ignored.

### Fixed
- **OTLP/JSON enum fields are now encoded as integers per the OTLP spec**,
  not proto3-JSON's default enum names: span `kind`, status `code`, log
  `severityNumber`, metric `aggregationTemporality`. Same origin story as
  the 1.1.0-beta.7 hex-id fix — `toProto3Json()`'s defaults deviate from
  the OTLP spec, lenient receivers masked it, and a strict
  cross-implementation check (the Dartastic engine wire-parity harness)
  caught it. Conversion is field-keyed and prefix-guarded, so attribute
  string values that merely resemble enum names are never touched.

### Added
- **Public `MetricTransformer.transformMetrics` one-shot** — the metrics
  analogue of `OtlpLogRecordTransformer.transformLogRecords`: converts a
  whole `MetricData` batch to a ready-to-serialize OTLP
  `ExportMetricsServiceRequest` (`transformMetrics(data).writeToBuffer()`),
  so alternative exporters and sinks can reuse the transform instead of
  re-implementing the per-metric mapping. Both bundled OTLP metric
  exporters (HTTP and gRPC) now build their requests through it, removing
  two hand-rolled copies of the same assembly; wire output is unchanged
  (same instrumentation-scope constant, same `OTel.resource(null)`
  fallback, resolved by the caller so the transformer stays a pure leaf).

### Changed
- **OTEL_BLRP_* env var validation now warns on invalid values** — previously,
  invalid `OTEL_BLRP_SCHEDULE_DELAY` and `OTEL_BLRP_EXPORT_TIMEOUT` values
  were silently ignored; they now emit `OTelLog.warn` diagnostics consistent
  with BSP behavior. `OTEL_BLRP_SCHEDULE_DELAY=0` is now accepted as valid
  (meaning "export as fast as possible"), and `OTEL_BLRP_EXPORT_TIMEOUT=0`
  means "no limit", mirroring BSP semantics.
- **`OTelEnv._getPositiveIntEnv` now warns on unusable values** — non-numeric,
  below-minimum, and above-maximum values all emit `OTelLog.warn`, giving
  consistent diagnostics to every caller without per-site bookkeeping.
- **`OTelEnv.getBlrpConfig()` simplified to raw env reading** — domain-level
  defaults, validation, and batch-to-queue clamping moved to
  `BatchLogRecordProcessorConfig.fromEnvironment()`.

## [1.1.0-beta.9] - 2026-07-18

### Changed
- Adopt `dartastic_opentelemetry_api` 1.0.0-rc.1 (constraint
  `^1.0.0-rc.1`). No SDK code changes were needed: the SDK never used
  the removed vendor/RUM enums, and it implements the now-abstract
  `APIObservableResult` interface.
- CI: self-hosted coverage badge built from lcov.info and published to
  the `badges` branch; Codecov upload removed (uploads had failed since
  branch protection was enabled). The README coverage badge is now live
  data instead of a hardcoded percentage.

## [1.1.0-beta.8] - 2026-07-18

### Added
- **`OTEL_PROPAGATORS` support and global propagator wiring.**
  `OTel.initialize()` now installs the API's global `TextMapPropagator`
  per the spec ("Global Propagators"): the default is the W3C
  `tracecontext,baggage` composite; `none` (or no supported values)
  leaves the API's spec-mandated no-op in place; unsupported names emit
  an `OTelLog.warn` and are ignored. Supported values: `tracecontext`,
  `baggage`, `none`. Instrumentation libraries can now obtain "the"
  propagator via `OTelAPI.textMapPropagator` instead of being handed one
  explicitly.
- **`OTEL_BSP_*` environment variables** for configuring `BatchSpanProcessor`
  (`OTEL_BSP_SCHEDULE_DELAY`, `OTEL_BSP_EXPORT_TIMEOUT`, `OTEL_BSP_MAX_QUEUE_SIZE`,
  `OTEL_BSP_MAX_EXPORT_BATCH_SIZE`). Values are read by
  `BatchSpanProcessorConfig.fromEnvironment()` which `OTel.initialize()` uses
  by default. Invalid or out-of-range values now emit `OTelLog.warn` diagnostics.
  `OTEL_BSP_EXPORT_TIMEOUT=0` is honored as "no limit" per spec.
- **Comma-separated `OTEL_*_EXPORTER` lists.** The spec's "implementation
  MAY accept a comma-separated list to enable setting multiple exporters"
  is now supported for all three signals: `OTEL_TRACES_EXPORTER=otlp,console`
  installs a `CompositeExporter`, metrics use a `CompositeMetricExporter`,
  and logs install one processor per exporter. `none` in a list wins;
  unsupported values (`zipkin`, the deprecated `logging`) emit an
  `OTelLog.warn` and are ignored; a list with no usable values falls back
  to the spec default `otlp`. Previously a list value silently installed
  no exporter at all.
- Unknown `OTEL_METRICS_EXPORTER` values now warn and are ignored
  instead of silently becoming `otlp`; `prometheus` gets a dedicated
  warning pointing at programmatic `PrometheusExporter` use and the
  planned scrape server (#82) — auto-wiring it today would be a silent
  no-op since the env-created exporter is unreachable by the app.

### Removed

- **Breaking: `OTel.initialize` no longer accepts `dartasticApiKey` or
  `tenantId`, and the `OTel.dartasticApiKey` static is gone.** Both were
  non-standard, vendor-specific parameters that predate the platform
  layering: API keys belong in OTLP exporter headers
  (`OTEL_EXPORTER_OTLP_HEADERS`) and tenant identity is platform-layer
  context, not an SDK concern. The `tenant_id` resource-attribute
  stamping and its debug-log special-casing are removed with them.
- **Breaking: the non-standard `OTEL_*`-namespace extensions are renamed
  or removed.** The per-signal diagnostic vars squatted the spec's core
  namespace and are renamed to the spec's language-specific convention
  (`OTEL_{LANGUAGE}_{FEATURE}`): `OTEL_LOG_SPANS` → `OTEL_DART_LOG_SPANS`,
  `OTEL_LOG_METRICS` → `OTEL_DART_LOG_METRICS`, `OTEL_LOG_EXPORT` →
  `OTEL_DART_LOG_EXPORT` (same semantics: enable the `OTelLog` per-signal
  diagnostic sinks; programmatic setters unchanged). The
  `OTEL_CONSOLE_EXPORTER` dart-define is removed — console output of the
  telemetry itself uses the standard `OTEL_*_EXPORTER=console` (or the
  comma-list form, e.g. `otlp,console`).

### Changed
- **Depends on `dartastic_opentelemetry_api` 1.0.0-beta.10** and re-exports
  its surface: the Weaver-generated semantic-convention enums (90 registry
  namespaces incl. entities/metrics/events), `NonRecordingSpan`, and the
  global `TextMapPropagator`. SDK consumers referencing renamed semconv
  enums through this package inherit the API's breaking renames — the
  complete old→new tables are in the API package's 1.0.0-beta.10
  CHANGELOG. SDK span creation is unaffected (the API's no-SDK span
  behavior only applies without an SDK factory installed).
- Examples and tests migrated to the new names (`Db`, `Server`, `Code`,
  `Http.httpRequestMethod`/`httpResponseStatusCode`/`httpResponseBodySize`)
  and off registry-deprecated keys: the database examples now emit
  `db.system.name`, `db.namespace`, `db.operation.name`, and
  `db.query.text` instead of the deprecated `db.system`/`db.name`/
  `db.operation`/`db.statement`, and drop the deprecated `db.user`.
- `CompositePropagator` is constructed via `OTelAPI.compositePropagator`
  (its constructor is factory-only as of the API's beta.10).
- **Default span batch schedule delay changed from 1 s to 5 s** (spec default).
  The previous hard-coded `BatchSpanProcessorConfig(scheduleDelay: Duration(seconds: 1))`
  in `OTel.initialize()` has been replaced by `BatchSpanProcessorConfig.fromEnvironment()`,
  whose fallback is the spec-mandated 5000 ms. To restore the old behavior, set
  `OTEL_BSP_SCHEDULE_DELAY=1000`.

## [1.1.0-beta.7] - 2026-07-11

### Fixed
- **`OtlpGrpcSpanExporter.export()` gains a Dart-level timeout backstop.**
  Previously the configured `timeout` was applied only via gRPC's `CallOptions`
  deadline. A Dart-level `.timeout()` now also bounds the RPC and tears down the
  channel on expiry, as defense-in-depth for real-world hangs where a collector
  accepts a connection then stops responding. **Note (under review):** this does
  NOT fix the concurrency test hang that prompted it — that was event-loop
  starvation from the gRPC client's reconnect churn, which no Timer-based bound
  can fix (see the PR discussion). Reviewers are deciding whether to keep this
  backstop; if dropped, this entry goes with it.
- **Debug logging no longer adds a `ConsoleExporter` to the trace pipeline.**
  `OTel.initialize()` used to append a `ConsoleExporter` to the span exporters
  whenever debug logging was enabled (e.g. `OTEL_LOG_LEVEL=debug`/`trace`),
  silently changing the export pipeline shape. Per the OTel spec the default
  exporter is `otlp` only — the same cleanup #49 applied to metrics. Console
  output remains available explicitly: `OTEL_TRACES_EXPORTER=console`
  (replaces the exporter) or the `OTEL_CONSOLE_EXPORTER` `--dart-define`
  (adds one alongside). For span logging use `OTEL_LOG_SPANS=true`.

### Added
- **Configurable exception handling for `Tracer.withSpan` / `withSpanAsync`.** A new `SpanExceptionOptions` (with `recordException`, `setStatusOnException`, and an `exceptionSanitizer` callback returning a `SanitizedSpanException`) lets callers customize how a thrown exception is recorded and whether the span status is set. The defaults preserve the existing behavior (record the exception + set `SpanStatusCode.Error`), and the original exception is always rethrown. Configure globally via `OTel.initialize(spanExceptionOptions: ...)` (also available per `TracerProvider` and `OTel.addTracerProvider`) and override per call via the new `exceptionOptions:` parameter on `withSpan` / `withSpanAsync` / `startActiveSpan` / `startActiveSpanAsync` and `OTel.withSpan` / `OTel.withSpanAsync`. Per-call options are merged field-by-field over the global config (via `SpanExceptionOptions.mergeWith`), so overriding a single flag preserves a globally configured sanitizer. When a sanitizer is provided, only its returned type/message/stacktrace are recorded — the raw exception's details never leak — and if the sanitizer itself throws, the span is marked failed with a generic description. This enables SDKs and applications to redact PII before it is recorded. ([#51](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/51))

### Fixed
- **API-first usage no longer wedges SDK initialization (#50).** The API
  package auto-installs its no-op `OTelAPIFactory` when API-only code runs
  before the SDK initializes (per the OTel spec). Previously
  `OTel.initialize()` then failed with "can only be initialized once", and
  `OTel.tracerProvider()` crashed with an opaque
  `APITracerProvider is not a subtype of TracerProvider` cast error.
  `OTel.initialize()` now replaces exactly the auto-installed no-op API
  factory — identified via `OTelFactory.isAPIFactory` (API ≥ beta.8), so real
  factories are never silently replaced — and the SDK accessors
  (`tracerProvider()`/`meterProvider()`/`loggerProvider()`/`addTracerProvider()`)
  throw a clear `OTel.initialize() must be called first.` `StateError` before
  initialization instead of the cast error. `OTelSDKFactory` now overrides
  `isAPIFactory` to `false` per the API ≥ beta.8 contract. Note: API objects
  handed out before `initialize()` remain no-ops — capture tracers after
  initialize. Thanks @robert-northmind for the investigation in #53 and the
  regression test suite adapted from it.

### Changed
- **Bumped `dartastic_opentelemetry_api` to `^1.0.0-beta.9`.** Beta.8 adds
  `OTelFactory.isAPIFactory` (used by the fix above) and replaces the no-op
  factory in `OTelAPI.initialize()`; beta.9 fixes pre-initialization lazy
  no-op installs (`tracer()`, `logger()`, `instrumentationScope()`,
  `TraceState.fromString`, the `fromJson`s) and makes `Context` re-read the
  global factory so an SDK factory installed later actually takes effect.


## [1.1.0-beta.6] - 2026-05-18
- **Bumped `dartastic_opentelemetry_api` to `^1.0.0-beta.7`.** Beta.7 fixes observable metrics and standard env var defaults.

### Fixed
- **Default metrics pipeline no longer prints to stdout.** `OTel.initialize()` used to wrap the default OTLP metric exporter in a `CompositeMetricExporter` with `ConsoleMetricExporter`, so every server using the SDK with zero env vars dumped metric payloads to the console. The default is now OTLP-only, matching traces and logs (and the OTel spec, which specifies `otlp` as the default for all three signals — never `console`). To opt back into stdout output set `OTEL_METRICS_EXPORTER=console` (or pass an explicit `metricExporter`/`metricReader` to `OTel.initialize`).

### Added
- **`OTEL_TRACES_EXPORTER` / `OTEL_METRICS_EXPORTER` / `OTEL_LOGS_EXPORTER` now honored end-to-end.** Each accepts `otlp` (default), `console`, or `none`; `none` skips processor/reader installation for that signal entirely. Previously only `OTEL_TRACES_EXPORTER` and `OTEL_LOGS_EXPORTER` were partially read and `OTEL_METRICS_EXPORTER` was ignored.
- **`OTEL_SDK_DISABLED=true` global off-switch.** When set, `OTel.initialize()` installs no span processors, metric readers, or log record processors — the SDK becomes a no-op for all three signals. Implemented via the new `OTelEnv.isSdkDisabled()` helper.

## [1.1.0-beta.5] - 2026-05-13

### Added
- **`package:dartastic_opentelemetry/testing.dart`** — opt-in library with the in-memory test harness used by the dart-otel-reference-demo and every OTel-Dart wrapper. Exports `InMemorySpanExporter` (with `findSpanByName` / `findSpansByName` / `findSpansStartingWith` / `clear`), `InMemoryLogExporter`, `InMemoryMetricExporter`, `OnDemandMetricReader` (timer-free; tests call `collect()` explicitly via `TestHarness.collectMetrics`), `TestHarness` aggregator, and `maybeInitializeOtelForTest()` (singleton initializer for `setUpAll`). Deliberately *not* re-exported from the main barrel so production bundles don't carry the test classes — import the `/testing.dart` path explicitly. Unifies the test scaffolding across the SDK, the reference demo, and the `otel_*` wrapper packages; previously each wrapper had its own near-identical copy.

### Removed
- **Breaking: `Tracer.startSpanWithContext` is removed.** Deprecated since 1.1.0-beta (released 2026-05-07), four betas ago. Migration is a 1:1 rename — `tracer.startSpanWithContext(name: x, context: ctx, kind: k, attributes: a)` → `tracer.startSpan(x, context: ctx, kind: k, attributes: a)`. To make the returned span active for a scope, wrap the work with `tracer.withSpan` (sync) or `tracer.withSpanAsync` (async); the deprecated method had stopped activating the span as of 1.1.0-beta anyway, so call sites that relied on activation already needed updating. Test suites that exercised `startSpanWithContext` were migrated in this release.

## [1.1.0-beta.4] - 2026-05-11

### Changed
- **Bumped `dartastic_opentelemetry_api` to `^1.0.0-beta.6`.** Beta.6 is a comprehensive OTel semantic-convention update — see the API CHANGELOG. Headline-level breaking changes consumers will feel:
  - The `Resource` suffix was dropped from ~60 attribute-key enums (`HttpResource.requestMethod` → `Http.requestMethod`, `UrlResource.urlFull` → `Url.urlFull`, etc.). Suffix is kept on six enums that conflict with common Dart / Flutter / library types: `ErrorResource`, `ExceptionResource`, `FileResource`, `ProcessResource`, `ServerResource` (`package:grpc`), `EventResource` (`package:web`).
  - `UserSemantics` → new `User` enum; `SessionViewSemantics` is split — OTel-spec keys (`session.id`, `session.previous_id`) → `Session`, non-spec RUM-style keys → `RumSessionView`.
  - Two new files in the API: `semantic_metrics.dart` (15 enums, ~280 metric instrument names with name + instrument kind + unit) and `semantic_events.dart` (16 spec event names). Plus a `semantic_values.dart` with typed value-set enums (`DbSystem.postgresql`, `CloudProvider.gcp`, `HttpRequestMethod.get`, etc.).
  - New `OTelAPI.attributesOf<E extends OTelSemantic>(Map<E, Object>)` helper for Dart 3.10 static dot-shorthand.
- **Breaking (web only):** `WebResourceDetector` now emits the user-agent string under `user_agent.original` (the current OTel semconv key, via `UserAgent.userAgentOriginal`) instead of `browser.user_agent`. The browser semconv namespace removed `browser.user_agent` in favor of the top-level `user_agent.*` registry — see https://opentelemetry.io/docs/specs/semconv/registry/attributes/user-agent/. Backends and dashboards that filter on the old key will need to update.

## [1.1.0-beta.3] - 2026-05-11

### Added
- **OTLP/HTTP-JSON wire format on all three signals.** `OtlpHttpSpanExporter`, `OtlpHttpMetricExporter`, and `OtlpHttpLogRecordExporter` now accept an `OtlpHttpProtocol` config option — defaults to `httpProtobuf` (unchanged behaviour), set to `httpJson` to send proto3-JSON-encoded payloads with `Content-Type: application/json`. The encoding follows the OTLP spec's proto3-to-JSON mapping (`request.toProto3Json()` on the generated protobuf classes), so no hand-rolled JSON marshaling lives in Dartastic. Wire-up via `OTEL_EXPORTER_OTLP_PROTOCOL=http/json` (or signal-specific `_TRACES_PROTOCOL` / `_METRICS_PROTOCOL` / `_LOGS_PROTOCOL`) flows through `OTel.initialize`. Per spec, `http/json` is `MAY`-support, not `MUST` — adding it lives up to Dartastic's "No skimping: if it's optional in the spec, it's included" promise. Unblocks integration with backends that prefer JSON (Genkit dev UI, browser-based viewers, lightweight collectors).

## [1.1.0-beta.2] - 2026-05-10

### Added
- **Pluggable `TimeProvider` for span timestamps.** Web targets (Dart-on-JS, Wasm) automatically get `WebTimeProvider` (sub-millisecond via `window.performance.now()` + `timeOrigin`); native targets keep `SystemTimeProvider` (`DateTime.now`, unchanged behaviour). No code change required to pick up the web precision — auto-selected via the API package's platform-aware `defaultTimeProvider`. Override via `OTel.initialize(timeProvider: customProvider)` for cases like a fake clock in tests.
  The abstraction lives in `dartastic_opentelemetry_api` (see API beta.5 changelog). The SDK's `TracerProvider.timeProvider` is now a delegate getter/setter that reads through to the underlying `APITracerProvider`, so SDK and API share a single source of truth.
- `OTel.attributesFromSemanticMap(Map<OTelSemantic, Object>)` — convenience passthrough to `OTelAPI.attributesFromSemanticMap`. Lets call sites that build attribute maps from typed semconv enums skip the `.key` accessor on every entry: `OTel.attributesFromSemanticMap({HttpResource.requestMethod: 'GET'})` instead of `OTel.attributesFromMap({HttpResource.requestMethod.key: 'GET'})`. Mixing different semconv enum types in one map is fine — the param type is the `OTelSemantic` interface that every semconv enum implements.

### Changed
- README and every example under `example/` now use `attributesFromSemanticMap` for typed-enum-keyed maps. The longer `attributesFromMap` form remains for raw-string-keyed maps (`{'foo.bar': value}`) and shows up in the README only as a counter-example for app-specific keys without a typed enum.
- Bumped `dartastic_opentelemetry_api` to `^1.0.0-beta.4`. Beta.4 adds `OTelAPI.loggerProviders()` parallel to the existing `tracerProviders()` / `meterProviders()`.

### Fixed
- **Named `LoggerProvider`s now shut down with `OTel.shutdown()`.** Closes the documented gap from beta.1's fix for issue #33. Beta.1 only shut down the default `LoggerProvider`; any provider created via `OTel.addLoggerProvider(name)` still kept its `BatchLogRecordProcessor.Timer.periodic` alive, parking the Dart isolate after `main()` returned for any consumer with multiple LoggerProviders. With API beta.4's new `loggerProviders()` enumerator, `OTel.shutdown()` now iterates all of them the same way it already does for tracer / meter providers.

## [1.1.0-beta.1] - 2026-05-10

### Changed
- Bumped `dartastic_opentelemetry_api` to `^1.0.0-beta.3`. Beta.3 fixes a `ServiceResource` semconv key that was mangled by an over-broad find/replace: the entry called `ServiceResource.serviceResourcepace` (with key `service.Resourcepace`) is restored to `ServiceResource.serviceNamespace` / `service.namespace`. If you used the misspelled name in your own code, replace it with `ServiceResource.serviceNamespace`.

### Fixed
- **`BatchSpanProcessor.shutdown()` no longer drops queued spans.** Two pre-existing bugs in the shutdown path: (1) `shutdown()` set `_isShutdown = true` before calling `forceFlush()`, but `forceFlush()` early-returns when `_isShutdown == true` — so spans queued at the moment shutdown was invoked were silently dropped. (2) `_exportBatch()` only exported up to `maxExportBatchSize` spans and returned, so even when the drain was reached it stopped after one batch. Brought in line with `BatchLogRecordProcessor`, which has always drained correctly: `shutdown()` now drains the queue *before* setting `_isShutdown`, and both `shutdown()` and `forceFlush()` loop until the queue is empty (or the exporter throws — bailing on persistent failure rather than spinning forever).
- **Process exits cleanly after `OTel.shutdown()` (#33):** short-lived Dart CLI binaries no longer hang after `await OTel.shutdown()` returns. `OTel.shutdown()` was iterating over tracer providers and meter providers but not over the default `LoggerProvider`. The default `BatchLogRecordProcessor`'s `Timer.periodic` therefore stayed alive after `main()` returned, parking the Dart isolate in `Dart_RunLoop` indefinitely (the symptom report described `await OTel.shutdown()` "never returning", but the actual symptom is that *process exit* hangs — `print` after `await` does run). `OTel.shutdown()` now also shuts down the default `LoggerProvider`. Named LoggerProviders (created via `OTel.addLoggerProvider`) still need to be shut down by the caller — a follow-up will add a `loggerProviders()` enumerator to the API so `OTel.shutdown()` can clean them up automatically.
- **Web compatibility:** `package:dartastic_opentelemetry/dartastic_opentelemetry.dart` is now safe to import on web targets (Flutter web, `dart compile js`, `dart compile wasm`). Previously the main library transitively pulled in `dart:io` via the OTLP/HTTP exporters, certificate utilities, and the platform resource detectors — `dart compile js` accepted these imports thanks to Dart 3 stubs, but the moment any of those classes ran (`HttpClient`, `SecurityContext`, `Platform.executable`, etc.) you got `UnsupportedError` at runtime. Split into platform-conditional facades:
  - `lib/src/resource/native_detectors.dart` — exports `ProcessResourceDetector` and `HostResourceDetector` from `_io.dart` on native, from `_stub.dart` on web (stubs throw with a clear migration message if instantiated; `PlatformResourceDetector.create()` skips them on web by design).
  - `lib/src/trace/export/otlp/certificate_utils.dart` — `_io.dart` keeps `validateCertificates` + `createSecurityContext`; `_stub.dart` keeps only `validateCertificates`. The IO-only `createSecurityContext` is reachable via the IO HTTP exporter path. gRPC exporters import `certificate_utils_io.dart` directly (gRPC is IO-only by nature).
  - `lib/src/trace/export/otlp/http/http_client_factory.dart` — new helper that returns `IOClient(HttpClient(...))` on native and `BrowserClient` on web. The three OTLP HTTP exporters (`OtlpHttpSpanExporter` / `OtlpHttpMetricExporter` / `OtlpHttpLogRecordExporter`) lost their direct `dart:io` imports and now delegate `_createHttpClient()` to this factory.

  Net effect on web: tracer/metrics/logs API works, OTLP/HTTP exporters work via the browser's fetch (browser owns TLS — custom CA / mTLS settings are ignored with a warning), `PlatformResourceDetector.create()` returns the env-var + web detector composite. `OtlpGrpcSpanExporter` and friends remain native-only — gRPC over HTTP/2 trailers isn't a thing in browsers regardless of dart:io.

  New regression test: `test/web/web_compile_smoke_test.dart` runs in Chrome, imports the main library, initializes the SDK, constructs all three HTTP exporters, and runs the platform resource detector.
- **dart2wasm:** `tool/web_tests.sh` (and CI) now runs the web suite under both dart2js (default) and dart2wasm. Caught and fixed a JS-interop bug in `gzip_web.dart` — the `ReadableStream` reader yielded a `JSUint8Array` that was being cast directly to `Uint8List`, which works on dart2js but fails with `TypeError: 'JSValue' is not a subtype of type 'Uint8List'` on dart2wasm. Now goes through `JSUint8Array.toDart` so it works on both compilers.

## [1.1.0-beta] - 2026-05-07

### Changed
- Bumped `dartastic_opentelemetry_api` to `^1.0.0-beta.2` (Zone-based context propagation, contributed to the API by Kevin Moore [@kevmoo](https://github.com/kevmoo); the cross-isolate `isRemote` fix in beta.1; new `DatabaseResource.dbCollectionName`, `DatabaseResource.dbResponseReturnedRows`, and `UserSemantics.userRoles` semconv enums in beta.2; and the breaking removal of the singular `UserSemantics.userRole` in beta.2).
- **Breaking:** `Tracer.withSpan` and `Tracer.withSpanAsync` now propagate context via Zones (`Context.runSync` / `Context.run`) instead of mutating the static `Context.current`. Async callbacks within a spanned scope now correctly observe the active span across `await` boundaries; concurrent `withSpanAsync` calls no longer race on the global static.
- **Breaking:** `Tracer.startSpan` no longer auto-activates the returned span (matching the new API contract and the OpenTelemetry specification). Use `OTel.withSpan` / `OTel.withSpanAsync` (or the equivalent on `Tracer`, or the `startActiveSpan` / `startActiveSpanAsync` convenience methods) to make a span active for a scope.
- **Breaking:** removed `Tracer.recordSpan` and `Tracer.recordSpanAsync`. They were redundant with `startActiveSpan`/`Async` (which expose the span to `fn`) and the name was unclear ("record what?"). Migration: a one-liner `tracer.recordSpan(name: x, fn: f)` becomes `OTel.tracer().startActiveSpan(name: x, fn: (_) => f())`. For the explicit lifecycle, use `tracer.startSpan(...)` + `OTel.withSpan(span, fn)` + `try/catch/finally` with `span.end()` in `finally`.
- Added `OTel.withSpan(span, fn)` and `OTel.withSpanAsync(span, fn)` static convenience methods that delegate to the default tracer — saves callers from threading a `Tracer` reference for the common activation case. Both accept `APISpan` (matching the API contract for cross-implementation interop).
- **Breaking:** renamed the SDK `Logger` class to `OTelLogger` to avoid clashing with `package:logging`'s `Logger`. Migration: replace `Logger` (the SDK type) with `OTelLogger` in your code. `OTel.logger(...)` and `OTel.loggerProvider().getLogger(...)` continue to return the same instances, only the type name changed. `LoggerProvider`, `APILogger`, and other `Logger*`-prefixed symbols are unchanged.
- **Breaking:** `Tracer.startSpanWithContext` no longer mutates `Context.current`. It is now a thin wrapper around `startSpan(name, context: ctx)` and is `@Deprecated`. Activate the returned span explicitly with `Tracer.withSpan` / `withSpanAsync`.
- `Tracer.startSpan`: when both `context` and `parentSpan` are provided with different traces, the explicit `parentSpan` now wins for `traceId` and `traceFlags` resolution. Previously the SDK would build an internally inconsistent SpanContext (context's traceId + parentSpan's spanId) which the new API validation correctly rejects.
- `Tracer.startSpan`: replaced the stale `effectiveContext != Context.root` identity-style check with a content-based check (`effectiveContext.span != null` + always read `effectiveContext.spanContext`). The old check skipped parent inheritance whenever `Context.current == Context.root`, which is the case inside an isolate spawned via `Context.runIsolate()` (the API attaches the propagated context as both the isolate's current and root). Combined with the API beta.1 `isRemote` fix, trace continuity now works end-to-end across `runIsolate`.

### Added
- `OTel.contextKey<T>(name)` now accepts an optional `isTransferable` flag (default `false`) which is forwarded to the API. Custom context keys must opt in to cross-isolate transfer; built-in `Baggage` and `SpanContext` always transfer.
- Re-exported `ServerResource` and `UrlResource` semantic enums from the API.
- New regression test (`tracer_methods_test.dart`) verifying that concurrent `withSpanAsync` operations isolate their active span — would catch any future regression of the Zone migration.

### Fixed
- `test/web/util/zip/gzip_web_test.dart`: replaced a corrupt hardcoded base64 gzip blob (CRC mismatch — the browser's `DecompressionStream`, Python's `gzip`, and Node all reject it) with a freshly-generated one (`mtime=0` for a deterministic header). Pre-existing bug; the test had never passed under a strict gzip decoder.
- Tooling: `Makefile` `test-safe` and `test-web` targets pointed at `tool/run_tests.sh` and `tool/web_tests.sh`, neither of which existed. Repointed `test-safe` at the existing `tool/test.sh` (used by CI). Added `tool/web_tests.sh` running `dart test -p chrome ./test/web`.
- CI: added a `test-web` job to `.github/workflows/dart.yml` that runs `tool/web_tests.sh` in Chrome on every push and PR — web tests previously only ran locally on demand.
- Documentation: every example file (and every code snippet in the SDK and API READMEs) now uses typed enum keys for span/log/baggage attributes — never raw strings. Examples without a matching OTel-semconv enum define a small local `ExampleAttribute` / `ExampleBaggage` / `DemoAttribute` enum at the top of the file to demonstrate the recommended pattern (the placeholder name is `ExampleAttribute`/`ExampleBaggage` rather than `AppAttribute` so readers rename it for their domain instead of copying it verbatim; the redundant `app.` prefix was also dropped from invented demo keys). Replaces deprecated `net.peer.*`, `client.ip`, `http.url`, `http.response_content_length` with their modern semconv equivalents (`ServerResource.serverAddress/Port`, `ClientResource.clientAddress`, `UrlResource.urlFull`, `HttpResource.responseBodySize`).
- Examples updated for spec-aligned behavior:
  - `example.dart`, `grafana_cloud_env_example.dart`, `grafana/grafana_cloud_env_example.dart`: replaced `'url.full'` / `'url.path'` / `'net.peer.name'` / `'net.peer.port'` string literals with the new `UrlResource` and `ServerResource` enums.
  - `isolate_context_example.dart`: rewritten to use `tracer.withSpanAsync` so the parent SpanContext propagates into `runIsolate`, and to avoid capturing non-sendable SDK objects in the isolate closure. Also dropped a private `src/` import.
  - `propagator_example.dart`: built the inject Context from `span.spanContext` directly instead of relying on the deprecated auto-activation; Step 5 now reports the child span's own ids (and parent linkage) rather than the active context's.

## [1.0.2-alpha] - 2026-04-19
### Fixed
- Fixed `OTel.defaultEndpoint` to use the OTLP/HTTP port `4318` instead of the gRPC port `4317`,
  matching the default `http/protobuf` protocol per the OpenTelemetry specification (#29).
  Removed the conditional port-swap workarounds in trace and logs configuration.
- Fixed `SimpleLogRecordProcessor.shutdown()` not flushing pending exports (#28).
- Fixed flaky `OtlpGrpcLogRecordExporter endpoint empty host defaults to 127.0.0.1`
  test that depended on no process listening on port 4317.

### Changed
- `MetricsConfiguration` now defaults to the HTTP/protobuf protocol (consistent with
  the trace and logs pipelines and with the OpenTelemetry specification). Set
  `OTEL_EXPORTER_OTLP_PROTOCOL=grpc` (or
  `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL=grpc`) to opt back into gRPC.

### Added
- Public `exporter` getter on `PeriodicExportingMetricReader` and `exporters`
  getter on `CompositeMetricExporter` for introspection and testability.

## [1.0.1-alpha] - 2026-04-05
- Added a BaggageSpanProcessor that adds Baggage as SpanAttributes

## [1.0.0-alpha] - 2026-04-02
### Added
- Log Signal SDK implementation
- Upgraded to dartastic_opentelemetry_api: ^1.0.0-alpha with Log Signal API

## The 0.9.x stable channel

`0.9.4` and up are not a separate line of development. Each one is the current
`1.1.0-beta.x` code republished under a `0.9.x` version so that users who have not
opted into prereleases still get the fixes before the v1 release. The code is
identical to the beta it names; only the version stamp and the
`dartastic_opentelemetry_api` constraint differ. Prefer the `1.1.0-beta.x` line if
your pubspec allows prereleases — it is what these entries point at.

## [0.9.8] - 2026-08-13
Stable-channel republication of `1.1.0-beta.13`. Depends on
`dartastic_opentelemetry_api: ^0.9.1`.

### Security

- **Fixes the OTLP debug-log credential leak,
  [GHSA-4rh6-c2v5-374w](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/security/advisories/GHSA-4rh6-c2v5-374w)
  (CWE-532).** Every `0.9.x` release from `0.9.0` through `0.9.7` is affected: with
  debug logging enabled, OTLP header values — including `Authorization`, `api-key`,
  and whatever name your backend uses — were written to the log. This is the first
  release on the stable channel that redacts them. See the `1.1.0-beta.13` entry
  above for the mechanism and for the `OTEL_DART_HEADER_LOG_ALLOWLIST` opt-in.

  **If you ran any 0.9.x release with debug logging enabled and a credential in an
  OTLP header, rotate that credential.** Upgrading alone does not undo the exposure.

### Also in this release

The `1.1.0-beta.12` changes, which never reached this channel: the `host.arch` fix
(#90), registry-enum attribute keys throughout, and the removal of the non-registry
`host.processors`, `host.locale`, and `process.num_threads` resource attributes.
Read the `1.1.0-beta.12` entry as well before upgrading from 0.9.7.

## [0.9.7] - 2026-07-20
Stable-channel republication of `1.1.0-beta.11` — docs only over 0.9.6. Depends on
`dartastic_opentelemetry_api: ^0.9.1`.

Adds the `1.1.0-beta.10` fixes over 0.9.6: baggage extraction preserving context and
endpoint scheme determining TLS (#89), OTLP/JSON enum fields encoded as integers per
spec (#86), and public `MetricTransformer.transformMetrics` (#85).

## [0.9.6] - 2026-07-18
Stable-channel republication of `1.1.0-beta.9`. Depends on
`dartastic_opentelemetry_api: ^0.9.1`, itself the republication of api `1.0.0-rc.1`
— note the api constraint moved off the `1.0.0-beta.x` range that 0.9.5 used.

Covers everything from `1.1.0-beta.1` through `1.1.0-beta.9`; see those entries for
the detail. Highlights for anyone coming from 0.9.5: `OTEL_PROPAGATORS` support (#42,
#76), BatchSpanProcessor environment variables (#59), comma-separated
`OTEL_*_EXPORTER` lists (#79), OTLP/HTTP-JSON wire format (#45), OTLP/JSON trace and
span ids encoded as hex per spec (#60), `LoggerProvider` shutdown fixes (#33, #41),
web/wasm safety (#36), and the removal of the non-standard `dartasticApiKey` and
`tenantId` (#78).

## [0.9.5] - 2026-05-09
Stable-channel republication of `1.1.0-beta` — the first of these. Depends on
`dartastic_opentelemetry_api: ^1.0.0-beta.2`. Covers `1.0.0-alpha` through
`1.1.0-beta` for users still on 0.9.3, most notably the Log signal SDK.

`0.9.4` was stamped in git a minute before 0.9.5 with the same code but never published to
pub.dev; there is no 0.9.4 release.

## [0.9.3] - 2025-10-25
### Added
- New W3CTracePropagator
- Defined all 74 env var constants
### Fixed
- Fixed env vars on Flutter web
- Fixed service.name, service.version, now from OTEL_RESOURCE_ATTRIBUTES
### Removed
- OTEL_SERVICE_VERSION, not in the spec

## [0.9.2] - 2025-10-12
- Default to INFO OTel logging.

## [0.9.1] - 2025-10-04
- Bumped API to 0.8.8 to fix logging.

## [0.9.0] - 2025-10-04
- Added support for `OTEL_EXPORTER_OTLP_HEADERS` for http and grpc exporters for trace and metrics
- Added support for all other exporter env vars
- Documented OTEL_* env var usage, added grafana examples
- Certificates env vars may not work yet tests skipped.  

## [0.8.7] - 2025-09-29
- Upgraded to api 0.8.7. Upgraded all dependencies including grpc to 4.1
- Respected all OTel env vars when no explicit values are specified, uses OTEL_CONSOLE_EXPORTER 
- Fixed default export, uses http/protobuf by default, not grpc
- Fixed issue with creation of the grpc exporter
- ConsoleExporter now only created on env vars or explicity
- Minor, doc, dart format, improved .gitignore, removed generated mistakenly committed 

## [0.8.6] - 2025-09-24
- Minor, cleaning, format, doc.

## [0.8.5] - 2025-06-14
- prep for wondrous otel demo, upgrade to api 0.8.3, span toString 

## [0.8.4] - 2025-06-06
- fix: Issue #3 - Fixed Metric generics for Histogram.
- chore: All 445 tests pass, 12 ignored, 0 fail, no crashes, thoroughly applied OTel.shutdown in test tearDowns.

## [0.8.3] - 2025-06-04
- fix: Issue 4, lack of span export

## [0.8.2] - 2025-05-06
- README.md updates

## [0.8.1] - 2025-05-06
- README.md updates

## [0.8.0] - 2025-05-01

### Added
- Initial public release of the OpenTelemetry SDK for Dart
- Complete implementation of the OpenTelemetry API
- Full tracing implementation with span processors
- Multiple exporters: OTLP (gRPC and HTTP), Console, Zipkin
- Resource providers for service information
- Sampler implementations: AlwaysOn, AlwaysOff, TraceIdRatio, ParentBased
- Context propagation: W3C Trace Context, W3C Baggage, Composite
- Batch processing with configurable parameters
- Comprehensive test suite
- Complete examples for various use cases

### Compatibility
- Implements OpenTelemetry SDK specification v1.0.0-rc3
- Requires opentelemetry_api: ^0.8.0
- Compatible with OpenTelemetry Protocol (OTLP) v0.18.0
