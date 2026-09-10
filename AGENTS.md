# AGENTS.md

Instructions for AI agents (and their humans) working in
`dartastic_opentelemetry`. Read [CONTRIBUTING.md](CONTRIBUTING.md) first —
everything there applies, including the git hooks
(`./tool/setup-hooks.sh`), the CHANGELOG conventions, and the
OpenTelemetry
[Generative AI policy](https://github.com/open-telemetry/community/blob/main/policies/genai.md).

## Commit formatting

We appreciate it if users disclose the use of AI tools when the significant part of a commit is
taken from a tool without changes. When making a commit this should be disclosed through an
Assisted-by: commit message trailer.

Examples:

Assisted-by: ChatGPT 5.2
Assisted-by: Claude Opus 4.5

## CHANGELOG.md style

Entries should be tied to their PR's by full links so that they show up on pub.dev.
Example:
- `getTracer`/`getLogger`/`getMeter` no longer invent a scope version or
  schema URL when the caller omits them
  ([#108](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry_api/pull/108)).


Use - **BREAKING**: format for breaking changes.
Example: - **BREAKING**: Replaced the `enabled` getter with `isEnabled()` method on `APITracer`, `APILogger`, `APIInstrument` and all instrument subclasses. The `enabled` parameter has also been removed from all metric instrument creation API constructors and factories. This change allows SDKs to dynamically re-evaluate instrument enablement and enables adding parameters to `isEnabled()` in the future without breaking the API.


## Architecture: one entrypoint, everything through factories

This SDK is **not structured like most OpenTelemetry SDKs**. In most
language SDKs you construct providers, tracers, and exporters directly.
Here there is a single entrypoint — the `OTel` class — backed by a factory
layer, and all calls flow through them:

- **`OTel` is the front door.** `OTel.initialize()` configures the SDK, and
  every object — tracer providers, tracers, spans, attributes, resources,
  meters, baggage, context — is obtained from static methods on `OTel`,
  never by calling constructors. Most constructors are private; creation
  code lives in `*_create.dart` part files next to each class.
- **A global factory does the construction.** `OTel.initialize()` installs
  an `OTelSDKFactory` in `OTelFactory.otelFactory`. If API-only code runs
  before initialization, the API package auto-installs a no-op
  `OTelAPIFactory`; `initialize()` upgrades it to the SDK factory, per the
  OpenTelemetry spec. This factory swap is how no-op vs SDK behavior and
  platform (native vs web) variants are selected without user code
  changing.
- **Consequence for changes:** adding a creatable type means threading it
  through the factory, not just adding a public constructor. When tracing a
  call path, start at `OTel`, follow into the factory, then into the
  `*_create.dart` part file — not at the class's constructor.

The API package
([`dartastic_opentelemetry_api`](https://pub.dev/packages/dartastic_opentelemetry_api))
mirrors this with `OTelAPI` and `OTelAPIFactory`.
