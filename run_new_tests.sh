#!/bin/bash
# Make script executable: chmod +x run_new_tests.sh
# Script to run just the new test files

set -e  # Exit on any error

echo "Running new tests..."
# Run just the new test files
dart test test/unit/metrics/view_test.dart test/unit/metrics/data/exemplar_test.dart test/unit/metrics/noop_meter_test.dart

echo "Tests completed successfully!"
