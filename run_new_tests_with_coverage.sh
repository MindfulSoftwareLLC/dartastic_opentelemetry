#!/bin/bash
# Make script executable: chmod +x run_new_tests_with_coverage.sh
# Script to run the new test files with coverage

set -e  # Exit on any error

echo "Starting test coverage collection for new tests..."
# Set environment variables to enable logging during tests
export OTEL_LOG_LEVEL=debug
export OTEL_LOG_METRICS=true
export OTEL_LOG_SPANS=true
export OTEL_LOG_EXPORT=true

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

# Run just the new tests with coverage
echo "Running new tests with coverage..."
dart test --coverage=coverage test/unit/metrics/view_test.dart test/unit/metrics/data/exemplar_test.dart test/unit/metrics/noop_meter_test.dart

# Format coverage reports
dart pub global run coverage:format_coverage \
  --packages=.dart_tool/package_config.json \
  --lcov \
  --check-ignore \
  --in=coverage \
  --out=coverage/lcov.info \
  --report-on=lib

# Generate HTML report if lcov is installed
if command -v genhtml >/dev/null 2>&1; then
  echo "Generating HTML coverage report..."
  genhtml coverage/lcov.info -o coverage/html
  echo "HTML coverage report generated at coverage/html/index.html"
else
  echo "lcov not installed, skipping HTML report generation"
fi

echo "Coverage process completed successfully"
