#!/bin/bash
# Licensed under the Apache License, Version 2.0
# Copyright 2025, Michael Bushe, All rights reserved.

# Set memory limits for the Dart VM
export DART_VM_OPTIONS="--old-gen-heap-size=256"

echo "======================================================"
echo "Running tests with memory limits and process isolation"
echo "======================================================"

# Kill any existing otelcol processes
echo "Cleaning up any existing processes..."
ps -ef | grep otelcol | grep -v grep | awk '{print $2}' | xargs -r kill -9
ps -ef | grep dart | grep test | awk '{print $2}' | xargs -r kill -9

# Wait for a moment
sleep 2

# Create array of problematic test files
problem_tests=(
  "test/trace/export/otlp/otlp_grpc_span_exporter_test.dart"
  "test/trace/sampling/sampling_integration_test.dart"
)

# Run problem tests one by one
for test_file in "${problem_tests[@]}"; do
  echo ""
  echo "========================================"
  echo "Running isolated test: $test_file"
  echo "========================================"
  
  # Clean up before each test
  ps -ef | grep otelcol | grep -v grep | awk '{print $2}' | xargs -r kill -9
  
  # Run with one process and memory limits
  dart --old-gen-heap-size=256 test -j 1 "$test_file"
  
  # Capture result
  result=$?
  
  # Clean up after test
  ps -ef | grep otelcol | grep -v grep | awk '{print $2}' | xargs -r kill -9
  
  echo "Test completed with exit code: $result"
  
  # Wait for resources to be freed
  sleep 3
  
  # Exit if test failed
  if [ $result -ne 0 ]; then
    echo "Test failed: $test_file"
    exit $result
  fi
done

# Create a list of tests to skip (the ones we already ran)
skip_args=""
for test_file in "${problem_tests[@]}"; do
  skip_args="$skip_args --exclude-tags=$test_file"
done

# Run other tests with normal settings
echo ""
echo "========================================"
echo "Running remaining tests"
echo "========================================"
dart test $skip_args

# Return final result
exit $?
