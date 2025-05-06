#!/bin/bash

# Run tests with coverage
dart run test --coverage=coverage

# Generate LCOV coverage report, excluding certain directories
dart run coverage:format_coverage --packages=.packages --report-on=lib/ --lcov --out=coverage/lcov.info --check-ignore

# Filter out proto files from coverage report
lcov --remove coverage/lcov.info '**/proto/**' '**/test/**' -o coverage/lcov.info

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html
