#!/bin/bash
# Reads coverage percentage from coverage/lcov.info and updates the README badge.
# Run after tool/coverage.sh, before pushing.

set -e

LCOV_FILE="coverage/lcov.info"
README="README.md"

if [ ! -f "$LCOV_FILE" ]; then
  echo "Error: $LCOV_FILE not found. Run tool/coverage.sh first."
  exit 1
fi

# Extract coverage percentage from lcov summary
COVERAGE=$(lcov --summary "$LCOV_FILE" 2>&1 | grep "lines\.\.\.\.\.\.\." | head -1 | sed 's/.*:\s*//' | sed 's/%.*//')

if [ -z "$COVERAGE" ]; then
  echo "Error: Could not parse coverage percentage from $LCOV_FILE"
  exit 1
fi

# Round to integer
COVERAGE_INT=$(printf "%.0f" "$COVERAGE")

# Pick badge color based on coverage
if [ "$COVERAGE_INT" -ge 90 ]; then
  COLOR="brightgreen"
elif [ "$COVERAGE_INT" -ge 80 ]; then
  COLOR="green"
elif [ "$COVERAGE_INT" -ge 70 ]; then
  COLOR="yellowgreen"
elif [ "$COVERAGE_INT" -ge 60 ]; then
  COLOR="yellow"
else
  COLOR="red"
fi

# Build the new badge markdown
BADGE="[![Coverage](https://img.shields.io/badge/coverage-${COVERAGE_INT}%25-${COLOR}.svg)](https://mindfulsoftwarellc.github.io/dartastic_opentelemetry/)"

# Replace the existing coverage badge line in README
# Matches any line starting with [![Coverage
sed -i '' "s|^\[!\[Coverage.*|${BADGE}|" "$README"

echo "Updated README badge: ${COVERAGE_INT}% (${COLOR})"
