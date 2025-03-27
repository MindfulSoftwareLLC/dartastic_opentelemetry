#!/bin/bash
# Modern coverage script for Dartastic OpenTelemetry SDK

set -e  # Exit on any error

echo "Starting test coverage collection..."

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

# Run tests with coverage
echo "Running tests with coverage..."
dart test --coverage=coverage --concurrency=1 --exclude-tags="fail" --exclude="test/unit/metrics/export/otlp/metric_transformer_test.dart"
./tool/coverage_format.sh
# If all succeeded, inform the user
echo "Coverage process completed successfully"
exit 0
