#!/bin/bash
# Improved coverage script for Dartastic OpenTelemetry SDK

echo "Starting test coverage collection..."

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

# Run tests with coverage
echo "Running tests with coverage..."
dart test --coverage=coverage

# Format the coverage data
echo "Formatting coverage data..."
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.packages --report-on=lib

# Check if lcov.info was created successfully
if [ ! -f coverage/lcov.info ]; then
  echo "Error: coverage/lcov.info file was not created"
  exit 1
fi

# Generate HTML report if lcov is available
if command -v genhtml >/dev/null 2>&1; then
  echo "Generating HTML report..."
  genhtml -o coverage/html coverage/lcov.info
  echo "Coverage report generated at coverage/html/index.html"
else
  echo "Warning: genhtml command not found, skipping HTML report generation"
  echo "To install lcov on macOS: brew install lcov"
  echo "To install lcov on Ubuntu: sudo apt-get install lcov"
fi

# Print summary
echo "Coverage collection complete"
if [ -f coverage/lcov.info ]; then
  LINE_COVERAGE=$(grep -oP 'LF:\K\d+' coverage/lcov.info | awk '{sum+=$1} END {print sum}')
  LINE_HIT=$(grep -oP 'LH:\K\d+' coverage/lcov.info | awk '{sum+=$1} END {print sum}')
  
  if [ "$LINE_COVERAGE" -gt 0 ]; then
    COVERAGE_PCT=$(( (LINE_HIT * 100) / LINE_COVERAGE ))
    echo "Overall coverage: $COVERAGE_PCT% ($LINE_HIT/$LINE_COVERAGE lines)"
  else
    echo "Unable to calculate coverage percentage"
  fi
fi

exit 0
