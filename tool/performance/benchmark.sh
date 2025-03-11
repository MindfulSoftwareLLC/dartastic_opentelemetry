#!/bin/bash

# Set the number of iterations
ITERATIONS=1000000

# Set the batch sizes to test
BATCH_SIZES=(1 10 100 1000)

echo "Running OpenTelemetry SDK Performance Benchmarks"
echo "=============================================="

for batch_size in "${BATCH_SIZES[@]}"
do
    echo "Testing with batch size: $batch_size"
    dart run benchmark/span_creation_benchmark.dart --iterations=$ITERATIONS --batch-size=$batch_size
    echo "----------------------------------------"
done

echo "Benchmark complete. Results are in the benchmark/results directory."