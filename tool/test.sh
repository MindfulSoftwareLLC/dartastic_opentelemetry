#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the otelcol download script
source "$SCRIPT_DIR/download_otelcol.sh"

# Download otelcol if needed
download_otelcol

# Run all tests
echo "Running all tests..."
dart test ./test/unit ./test/integration ./test/performance

# Check exit code
if [ $? -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
