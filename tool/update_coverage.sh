#!/bin/bash
# Modern coverage script for Dartastic OpenTelemetry SDK 
# that only runs our four target test files with logging enabled

set -e  # Exit on any error

echo "Starting targeted test coverage collection..."

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

# Enable logging during tests via environment variables
export OTEL_LOG_LEVEL=debug
export OTEL_LOG_METRICS=true
export OTEL_LOG_SPANS=true
export OTEL_LOG_EXPORT=true

# Run only the specific test files needed to improve meter and metrics coverage
echo "Running targeted tests with coverage..."
dart test --coverage=coverage \
  test/unit/metrics/meter_coverage_test.dart \
  test/unit/metrics/meter_provider_test.dart \
  test/unit/util/otel_env_test.dart \
  test/unit/util/otel_log_test.dart

# Format coverage data
echo "Formatting coverage data..."
dart run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --ignore-files='lib/proto/.*,**/*.pb.dart,**/*.pbenum.dart,**/*.pbserver.dart,**/*.pbgrpc.dart,**/*.pbjson.dart' \
  --out=coverage/lcov.info \
  --report-on=lib \
  --check-ignore

# Generate HTML report
if command -v genhtml >/dev/null 2>&1; then
  echo "Generating HTML report..."
  genhtml coverage/lcov.info -o coverage/html
  echo "Coverage report generated at coverage/html/index.html"
else
  echo "Warning: genhtml command not found, skipping HTML report generation"
  echo "To install lcov on macOS: brew install lcov"
  echo "To install lcov on Ubuntu: sudo apt-get install lcov"
fi

# Print summary
echo "Target coverage collection complete"
if command -v lcov >/dev/null 2>&1; then
  echo "LCOV summary for target files:"
  lcov --summary coverage/lcov.info
fi

# If all succeeded, inform the user
echo "Coverage process completed successfully"
exit 0
