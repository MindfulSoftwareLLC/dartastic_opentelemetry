#!/bin/bash

# Run performance comparison tests
echo "Running performance comparison tests..."

# Set environment variables
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"

# Run the performance comparison
dart run test test/performance/*_test.dart --concurrency=1

# Generate performance report
echo "Generating performance report..."
dart run bin/generate_performance_report.dart