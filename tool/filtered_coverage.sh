#!/bin/bash
# Filtered coverage script for Dartastic OpenTelemetry SDK

# Default settings
FILTER=""
CONCURRENCY=10
EXCLUDE_FAIL=true
TIMEOUT_MULTIPLIER=1

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --filter=*)
      FILTER="${1#*=}"
      shift
      ;;
    --concurrency=*)
      CONCURRENCY="${1#*=}"
      shift
      ;;
    --include-fail)
      EXCLUDE_FAIL=false
      shift
      ;;
    --timeout=*)
      TIMEOUT_MULTIPLIER="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--filter=pattern] [--concurrency=N] [--include-fail] [--timeout=multiplier]"
      exit 1
      ;;
  esac
done

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

# Build the test command
TEST_CMD="dart test --chain-stack-traces --coverage=coverage --concurrency=$CONCURRENCY"

# Add timeout multiplier if specified
if [ "$TIMEOUT_MULTIPLIER" != "1" ]; then
  TEST_CMD="$TEST_CMD --timeout=${TIMEOUT_MULTIPLIER}x"
fi

# Add exclude-tags if enabled
if [ "$EXCLUDE_FAIL" = true ]; then
  TEST_CMD="$TEST_CMD --exclude-tags=fail"
fi

# Add filter if specified
if [ -n "$FILTER" ]; then
  TEST_CMD="$TEST_CMD -n \"$FILTER\""
  echo "Running tests matching: $FILTER"
else
  echo "Running all tests"
fi

# Run tests with coverage
echo "Running tests with coverage..."
echo "Command: $TEST_CMD"
eval $TEST_CMD

./tool/coverage_format.sh
echo "Coverage process completed successfully"
exit 0
