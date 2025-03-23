#!/bin/bash
# Simple coverage script for Dartastic OpenTelemetry SDK

set -e  # Exit on any error

echo "Starting test coverage collection..."

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

# Run tests with coverage
echo "Running tests with coverage..."
dart test --coverage=coverage

# Format the coverage data
echo "Formatting coverage data..."
dart run coverage:format_coverage --lcov --check-ignore --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib

echo "Coverage collection complete"
exit 0
