#!/bin/bash

# Parse command line arguments
LOG_LEVEL="info"
CONCURRENCY="20"
FAIL_FAST="false"

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
    --fail-fast)
      FAIL_FAST="true"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--log LEVEL] [--concurrency N] [--fail-fast]"
      echo "  --log LEVEL        Set log level (trace, debug, info, warn, error, fatal)"
      echo "  --concurrency N    Set test concurrency (default: auto)"
      echo "  --fail-fast        Stop after the first failing test. Suites already"
      echo "                     in flight still report, so pair with"
      echo "                     --concurrency 1 to stop at exactly one failure."
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

#Consider using these log settings to diagnose test problem
#export OTEL_LOG_LEVEL=trace
#export OTEL_DART_LOG_METRICS=true
#export OTEL_DART_LOG_SPANS=true
#export OTEL_DART_LOG_EXPORT=true
# Environment variable to signal tests they are running in isolation
#export DART_OTEL_ISOLATED_TESTING=true

# Set environment variables if specified
if [ -n "$LOG_LEVEL" ]; then
  export OTEL_LOG_LEVEL="$LOG_LEVEL"
  echo "Setting log level to: $LOG_LEVEL"
fi

# Build dart test command. Use the whole `./test` tree so any new
# top-level test file gets picked up automatically (e.g. `test/basic_test.dart`
# was being silently skipped before this change). Browser-only tests under
# `test/web/` are tagged with `@TestOn('browser')` and are skipped on the VM
# target; the dedicated browser run lives in `tool/web_tests.sh`.
TEST_CMD="dart test ./test"

if [ -n "$CONCURRENCY" ]; then
  TEST_CMD="$TEST_CMD --concurrency=$CONCURRENCY"
  echo "Setting concurrency to: $CONCURRENCY"
fi

if [ "$FAIL_FAST" = "true" ]; then
  TEST_CMD="$TEST_CMD --fail-fast"
  echo "Stopping after the first failure"
fi

# Run all tests
echo "Running all tests..."
$TEST_CMD

# Check exit code
if [ $? -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
