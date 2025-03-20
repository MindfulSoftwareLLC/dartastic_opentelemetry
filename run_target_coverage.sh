#!/bin/bash
# Run coverage for our metrics implementation

# Set environment variables to enable logging during tests
export OTEL_LOG_LEVEL=debug
export OTEL_LOG_METRICS=true
export OTEL_LOG_SPANS=true
export OTEL_LOG_EXPORT=true

# Run the coverage script
dart test --coverage=coverage test/unit/metrics/meter_coverage_test.dart test/unit/metrics/meter_provider_test.dart test/unit/util/otel_env_test.dart test/unit/util/otel_log_test.dart

# Format the coverage data
dart run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --report-on=lib \
  --check-ignore \
  --verbose

# Generate HTML report if lcov is available
if command -v genhtml >/dev/null 2>&1; then
  echo "Generating HTML report..."
  genhtml coverage/lcov.info -o coverage/html
  echo "Coverage report generated at coverage/html/index.html"
else
  echo "Warning: genhtml command not found, skipping HTML report generation"
  echo "To install lcov on macOS: brew install lcov"
  echo "To install lcov on Ubuntu: sudo apt-get install lcov"
fi

echo "Coverage testing completed"
