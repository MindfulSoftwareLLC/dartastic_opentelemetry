#!/bin/bash
# Coverage script for Dartastic OpenTelemetry SDK

set -e  # Exit on any error

# Parse command line arguments
LOG_LEVEL="info"
CONCURRENCY="20"

while [[ $# -gt 0 ]]; do
  case $1 in
    --log)
      LOG_LEVEL="$2"
      shift 2
      ;;
    --concurrency)
      CONCURRENCY="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--log LEVEL] [--concurrency N]"
      echo "  --log LEVEL        Set log level (trace, debug, info, warn, error, fatal)"
      echo "  --concurrency N    Set test concurrency (default: 10 for coverage)"
      exit 1
      ;;
  esac
done

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the otelcol download script
source "$SCRIPT_DIR/download_otelcol.sh"

# Download otelcol if needed
download_otelcol

echo "Starting test coverage collection..."
# Set environment variables to enable logging during tests
export OTEL_LOG_LEVEL="$LOG_LEVEL"
export OTEL_LOG_METRICS=true
export OTEL_LOG_SPANS=true
export OTEL_LOG_EXPORT=true
# Environment variable to signal tests they are running in isolation
export DART_OTEL_ISOLATED_TESTING=true

echo "Log level: $LOG_LEVEL"
echo "Concurrency: $CONCURRENCY"

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

# Run tests with coverage
echo "Running tests with coverage..."
dart test --chain-stack-traces --coverage=coverage --concurrency="$CONCURRENCY" --exclude-tags="fail"
# Generate LCOV coverage report, excluding certain directories
dart run coverage:format_coverage --package=. --report-on=lib/ --lcov -i coverage --out=coverage/lcov.info --check-ignore
# Filter out proto files from coverage report
lcov --remove coverage/lcov.info '**/proto/**' -o coverage/lcov.info
# Generate HTML report
genhtml coverage/lcov.info -o coverage/html
echo "Coverage process completed successfully"
exit 0
