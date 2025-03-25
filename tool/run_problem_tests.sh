#!/bin/bash
# Script to run problematic tests in isolation with coverage

# Create output directory if it doesn't exist
mkdir -p coverage

# Environment variable to signal tests they are running in isolation
export DART_OTEL_ISOLATED_TESTING=true

# List of problematic tests
PROBLEM_TESTS=(
  "test/trace/context_propagation_test.dart"
  "test/unit-fail/context_propagation_test.dart"
)

for test_file in "${PROBLEM_TESTS[@]}"; do
  if [ -f "$test_file" ]; then
    echo "===== Running problematic test in isolation: $test_file ====="

    # Generate a unique output file
    test_name=$(basename "$test_file" .dart)
    output_file="coverage/isolate_${test_name}.json"

    # Run with long timeout and VM service
    TIMEOUT=60 dart --define=ISOLATED_RUN=true \
         --disable-service-auth-codes \
         --enable-vm-service=8989 \
         --pause-isolates-on-exit \
         "$test_file" &

    PID=$!

    # Wait for VM service to come up
    sleep 3

    # Collect coverage
    dart pub run coverage:collect_coverage \
         --uri=http://localhost:8989/ \
         --out="$output_file" \
         --wait-paused \
         --resume-isolates

    # Wait for process to complete
    wait $PID

    echo "===== Test complete, coverage data saved to $output_file ====="

    # Cleanup time
    sleep 2
  else
    echo "Test file not found: $test_file"
  fi
done

# Create directories for any missing test files
#mkdir -p test/unit/trace

# Consolidate the coverage data
if [ -f "coverage/lcov.info" ]; then
  # Backup existing lcov data
  cp coverage/lcov.info coverage/lcov.info.bak
fi

# Format coverage data
dart pub run coverage:format_coverage \
     --lcov \
     --in=coverage \
     --out=coverage/lcov.info \
     --report-on=lib \
     --check-ignore

echo "Coverage data consolidated to coverage/lcov.info"

# Generate HTML report if lcov is installed
if command -v genhtml >/dev/null 2>&1; then
  genhtml coverage/lcov.info -o coverage/html
  echo "HTML coverage report generated in coverage/html"
else
  echo "lcov not installed, skipping HTML report generation"
fi
