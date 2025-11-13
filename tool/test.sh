#!/bin/bash

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
      echo "  --concurrency N    Set test concurrency (default: auto)"
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

# Set environment variables if specified
if [ -n "$LOG_LEVEL" ]; then
  export OTEL_LOG_LEVEL="$LOG_LEVEL"
  echo "Setting log level to: $LOG_LEVEL"
fi

# Build dart test command
TEST_CMD="dart test ./test/unit ./test/integration ./test/performance"

if [ -n "$CONCURRENCY" ]; then
  TEST_CMD="$TEST_CMD --concurrency=$CONCURRENCY"
  echo "Setting concurrency to: $CONCURRENCY"
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
