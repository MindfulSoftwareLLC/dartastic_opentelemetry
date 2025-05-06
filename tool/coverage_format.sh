#!/bin/bash
# Runs the report, used after running tests with coverage,

set -e  # Exit on any error

# Verify that the coverage directory contains data
if [ ! "$(ls -A coverage)" ]; then
   echo "Error: No coverage data generated."
   exit 1
fi

# List files found in coverage directory
echo "Files found in coverage directory:"
find coverage -type f | head -n 5
echo "(showing first 5 files only)"

# Format the coverage data into lcov format
echo "Formatting coverage data..."
dart run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --ignore-files='lib/proto/.*,**/*.pb.dart,**/*.pbenum.dart,**/*.pbserver.dart,**/*.pbgrpc.dart,**/*.pbjson.dart' \
  --out=coverage/lcov.info \
  --report-on=lib \
  --check-ignore

# Check if lcov.info was created successfully
if [ ! -f coverage/lcov.info ]; then
  echo "Error: coverage/lcov.info file was not created"
  ls -la coverage
  exit 1
fi

# Debug: Show first few lines of lcov.info to verify content
if [ -f coverage/lcov.info ]; then
  echo "Preview of coverage/lcov.info (first 10 lines):"
  head -n 10 coverage/lcov.info
fi

# Report the raw LCOV info file size for debugging
LCOV_SIZE=$(wc -c < coverage/lcov.info)
echo "LCOV info file size: $LCOV_SIZE bytes"

# Generate HTML report if lcov is available
if command -v genhtml >/dev/null 2>&1; then
  echo "Generating HTML report..."
  genhtml coverage/lcov.info -o coverage/html
  echo "Coverage report generated at coverage/html/index.html"
else
  echo "Warning: genhtml command not found, skipping HTML report generation"
  echo "To install lcov on macOS: brew install lcov"
  echo "To install lcov on Ubuntu: sudo apt-get install lcov"
fi

# Print summary
echo "Coverage collection complete"
if [ -f coverage/lcov.info ] && [ "$LCOV_SIZE" -gt 0 ]; then
  if command -v lcov >/dev/null 2>&1; then
    echo "LCOV summary:"
    lcov --summary coverage/lcov.info
  else
    # Fallback to basic calculation if lcov command is not available
    LINE_COVERAGE=$(grep -c 'LF:' coverage/lcov.info)
    LINE_HIT=$(grep -c 'LH:' coverage/lcov.info)

    if [ "$LINE_COVERAGE" -gt 0 ]; then
      echo "Found $LINE_COVERAGE coverage data points"
    else
      echo "Warning: Could not parse coverage data"
    fi
  fi
else
  echo "Warning: No coverage data available"
fi

# If all succeeded, inform the user
echo "Coverage process completed successfully"
exit 0

# Generate HTML report if lcov is available
if command -v genhtml >/dev/null 2>&1; then
  echo "Generating HTML report..."
  genhtml coverage/lcov.info -o coverage/html
  echo "Coverage report generated at coverage/html/index.html"
else
  echo "Warning: genhtml command not found, skipping HTML report generation"
  echo "To install lcov on macOS: brew install lcov"
  echo "To install lcov on Ubuntu: sudo apt-get install lcov"
fi

# Print summary
echo "Coverage collection complete"
if [ -f coverage/lcov.info ] && [ "$LCOV_SIZE" -gt 0 ]; then
  if command -v lcov >/dev/null 2>&1; then
    echo "LCOV summary:"
    lcov --summary coverage/lcov.info
  else
    # Fallback to basic calculation if lcov command is not available
    LINE_COVERAGE=$(grep -c 'LF:' coverage/lcov.info)
    LINE_HIT=$(grep -c 'LH:' coverage/lcov.info)

    if [ "$LINE_COVERAGE" -gt 0 ]; then
      echo "Found $LINE_COVERAGE coverage data points"
    else
      echo "Warning: Could not parse coverage data"
    fi
  fi
else
  echo "Warning: No coverage data available"
fi

# If all succeeded, inform the user
echo "Coverage process completed successfully"
exit 0
