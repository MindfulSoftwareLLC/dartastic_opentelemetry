#!/bin/bash
# Script to run all tests and combine coverage data
# Create coverage directory if it doesn't exist
mkdir -p coverage

# First run regular tests with coverage
echo "===== Running regular tests with coverage ====="
dart test --coverage=coverage --timeout=60s test/util test/performance test/integration

# Then run problematic tests in isolation
echo "===== Running problematic tests in isolation ====="
tool/run_problem_tests.sh

# Combine and format coverage data
echo "===== Generating final coverage report ====="
dart pub run coverage:format_coverage \
     --lcov \
     --in=coverage \
     --out=coverage/lcov.info \
     --report-on=lib \
     --check-ignore

# Generate HTML report if lcov is installed
if command -v genhtml >/dev/null 2>&1; then
  # Use ignore-errors to handle the range issue
  genhtml --ignore-errors range coverage/lcov.info -o coverage/html
  echo "HTML coverage report generated in coverage/html"

  # Try to open the report on macOS
  if [ "$(uname)" == "Darwin" ]; then
    open coverage/html/index.html
  fi
else
  echo "lcov not installed, skipping HTML report generation"
  echo "To install lcov:"
  echo "  Homebrew (macOS): brew install lcov"
  echo "  Ubuntu/Debian: apt-get install lcov"
fi

echo "===== Coverage collection complete ====="
