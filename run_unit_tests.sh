#!/bin/bash

# Run only unit tests, excluding problematic test files
dart test --tags=unit --exclude-tags=memory-intensive --no-run-skipped --coverage=coverage

# Generate LCOV coverage report
dart run coverage:format_coverage --packages=.packages --report-on=lib/ --lcov --out=coverage/lcov.info --check-ignore

# Filter out proto files from coverage report
lcov --remove coverage/lcov.info '**/proto/**' '**/test/**' -o coverage/lcov.info

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html
