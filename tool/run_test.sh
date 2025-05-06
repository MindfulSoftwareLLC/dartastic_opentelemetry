#!/bin/bash
# Script to run an individual test with detailed output

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <test-file-path> [test-name]"
  echo "Example: $0 test-fail/unit/trace/context_propagation_test.dart"
  echo "Example with specific test: $0 test-fail/unit/trace/context_propagation_test.dart \"handles attributes across context boundaries\""
  exit 1
fi

TEST_FILE="$1"
TEST_NAME="$2"

# Ensure the test file exists
if [ ! -f "$TEST_FILE" ]; then
  echo "Error: Test file not found: $TEST_FILE"
  exit 1
fi

echo "Running test: $TEST_FILE"
if [ -n "$TEST_NAME" ]; then
  echo "Test name: $TEST_NAME"
  dart test "$TEST_FILE" --name="$TEST_NAME" --chain-stack-traces --verbose
else
  # Run the entire file
  dart test "$TEST_FILE" --chain-stack-traces --verbose
fi
