#!/bin/bash

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