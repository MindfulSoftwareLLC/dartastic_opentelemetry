#!/bin/bash
# Coverage script for Dartastic OpenTelemetry SDK

set -e  # Exit on any error

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the otelcol download script
source "$SCRIPT_DIR/download_otelcol.sh"

# Download otelcol if needed
download_otelcol

echo "Starting test coverage collection..."
# Set environment variables to enable logging during tests
# Need trace logging for coverage of debug and trace logs
export OTEL_LOG_LEVEL=trace
export OTEL_LOG_METRICS=true
export OTEL_LOG_SPANS=true
export OTEL_LOG_EXPORT=true
# Environment variable to signal tests they are running in isolation
export DART_OTEL_ISOLATED_TESTING=true

# Ensure the coverage directory exists and is clean
rm -rf coverage
echo "Starting test coverage collection..."

mkdir -p coverage

# Run tests with coverage
echo "Running tests with coverage..."
dart test --chain-stack-traces --coverage=coverage --concurrency=10 --exclude-tags="fail" ./test/unit ./test/integration ./test/performance

# Generate LCOV coverage report, excluding certain directories
dart run coverage:format_coverage  --in=./coverage --package=./lib --report-on=lib/ --lcov --out=coverage/lcov.info --check-ignore

# Filter out proto files from coverage report
lcov --remove coverage/lcov.info '**/proto/**' '**/test/**' --ignore-errors unused -o coverage/lcov.info

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

echo "Coverage process completed successfully"
exit 0
