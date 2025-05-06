#!/bin/bash
# Coverage script for Dartastic OpenTelemetry SDK

set -e  # Exit on any error

echo "Starting test coverage collection..."
# Set environment variables to enable logging during tests
export OTEL_LOG_LEVEL=debug
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
dart test --chain-stack-traces --coverage=coverage --concurrency=10 --exclude-tags="fail"
./tool/coverage_format.sh
echo "Coverage process completed successfully"
exit 0
