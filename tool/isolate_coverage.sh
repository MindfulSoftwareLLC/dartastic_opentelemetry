#!/bin/bash
# File: tool/isolate_coverage.sh

# Create a directory for individual coverage reports
mkdir -p coverage/isolate

# Get total test files count
total_files=$(find test -name "*_test.dart" | wc -l)
count=0

# Run each test in isolation and collect coverage
find test -name "*_test.dart" | while read test_file; do
  count=$((count + 1))
  echo "[$count/$total_files] Running test in isolation: $test_file"
  
  # Generate a unique filename for the coverage data
  test_name=$(basename "$test_file" .dart)
  output_file="coverage/isolate/$test_name.json"
  
  # Run the test with coverage
  dart --disable-service-auth-codes \
       --enable-vm-service=8181 \
       --pause-isolates-on-exit \
       "$test_file" &
  
  # Wait for VM service to become available
  sleep 2
  
  # Collect coverage
  dart pub run coverage:collect_coverage \
       --uri=http://localhost:8181/ \
       --out="$output_file" \
       --wait-paused \
       --resume-isolates
  
  # Add small delay to ensure resources are freed
  sleep 1
done

# Combine all the coverage reports
echo "Combining coverage reports..."
dart pub run coverage:format_coverage \
     --lcov \
     --in=coverage/isolate \
     --out=coverage/lcov.info \
     --report-on=lib \
     --check-ignore

# Generate HTML report
dart pub run coverage:format_coverage \
     --lcov \
     --in=coverage/isolate \
     --out=coverage/lcov.info \
     --report-on=lib \
     --check-ignore

# Convert to HTML if lcov is installed
if command -v genhtml >/dev/null 2>&1; then
  genhtml coverage/lcov.info -o coverage/html
  echo "HTML coverage report generated in coverage/html"
else
  echo "lcov not installed, skipping HTML report generation"
fi
