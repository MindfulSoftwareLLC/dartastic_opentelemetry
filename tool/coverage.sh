#!/bin/bash

# Ensure the coverage directory exists
mkdir -p coverage

# Run tests with coverage
echo "Running tests with coverage..."
dart run coverage:test_addcoverage

# Generate LCOV report
echo "Generating coverage report..."
genhtml coverage/lcov.info -o coverage/html

# Open coverage report in default browser (works on macOS)
echo "Opening coverage report..."
open coverage/html/index.html

# Print coverage statistics
echo "Coverage statistics:"
lcov --summary coverage/lcov.info
