#!/bin/bash
# Create the component labels that .github/labeler.yml matches by path. This
# file is the source of truth for them; .github/workflows/create-labels.yml
# runs it on push to main, so run it by hand only to bootstrap a fork.
#
# actions/labeler could create missing labels itself, but only if granted
# `issues: write`. Creating them here keeps that workflow narrower and gives
# the labels real colours and descriptions.
#
# Safe to re-run: --force updates an existing label rather than erroring.
#
# Usage: ./tool/create-labels.sh [owner/repo]

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "error: the GitHub CLI (gh) is required. See https://cli.github.com" >&2
  exit 1
fi

# With no argument, gh resolves the repository from the current checkout.
GH_ARGS=()
if [ -n "${1:-}" ]; then
  GH_ARGS=(--repo "$1")
fi

label() {
  local name="$1" color="$2" description="$3"
  echo "  $name"
  gh label create "$name" --color "$color" --description "$description" --force \
    ${GH_ARGS[@]+"${GH_ARGS[@]}"} >/dev/null
}

echo "Creating component labels..."

# Components, one per folder under lib/src/.
label trace       1d76db "Tracing: spans, tracers, samplers, propagation."
label metrics     0e8a16 "Metrics: meters, instruments, views, aggregation."
label logs        5319e7 "Logs: loggers, log records, the log bridge."
label baggage     d4c5f9 "Baggage and the W3C baggage propagator."
label context     bfd4f2 "Context and context propagation."
label resource    c5def5 "Resources and resource detectors."
label environment bfdadc "OTEL_* environment variables and configuration."
label export      fbca04 "OTLP exporters and the export pipeline."
label proto       e99695 "Generated OpenTelemetry protobuf code."
label core        0052cc "The OTel entrypoint, the factory layer, shared utilities."

# Everything that is not a signal.
label tests         c2e0c6 "Test suites and test utilities."
label ci            ededed "GitHub Actions workflows and repository configuration."
label tooling       d3d3d3 "Scripts under tool/, build and analysis configuration."
label documentation 0075ca "Improvements or additions to documentation"
label dependencies  f9d0c4 "Package dependencies and version constraints."

echo
echo "Done. .github/workflows/labeler.yml applies these by changed path."
