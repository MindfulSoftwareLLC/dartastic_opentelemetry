# Dartastic Performance Guide

This guide helps you understand, run, and interpret the Dartastic SDK performance tests.

## Performance Goals

### Core Operations (microseconds)
| Operation                    | Target (μs) | Acceptable Range |
|---------------------------- |-------------|------------------|
| Span Creation               | < 10        | 10-50           |
| Span End                    | < 5         | 5-20            |
| Context Switch              | < 1         | 1-5             |
| Attribute Set              | < 1         | 1-3             |

### Memory Impact (bytes)
| Measurement                 | Target      | Acceptable Range |
|--------------------------- |-------------|------------------|
| Base Span                  | < 200       | 200-500         |
| Per Attribute             | < 50        | 50-100          |
| Context Entry             | < 100       | 100-200         |

### Throughput (operations/second)
| Scenario                    | Target      | Acceptable Range |
|--------------------------- |-------------|------------------|
| Spans/sec (single thread)  | > 100,000   | 50,000-100,000  |
| Context Switches/sec       | > 500,000   | 250,000-500,000 |
| Concurrent Spans (10 threads) | > 50,000  | 25,000-50,000   |

### Baggage Performance
| Operation                    | Target (μs) | Acceptable Range |
|---------------------------- |-------------|------------------|
| Baggage Entry Access        | < 1         | 1-3             |
| Cross-Isolate Transfer     | < 100       | 100-500         |
| Large Baggage (100 entries) | < 10        | 10-50           |

## Running the Tests

### Basic Usage
```bash
# Run all performance tests
dart run test/performance/run_all_benchmarks.dart

# Run specific test suites
dart run test/performance/baggage/baggage_benchmarks.dart
dart run test/performance/core/api_benchmarks.dart
```

### Configuration Options
- Set DEBUG=1 for verbose output
- Set ITERATIONS=N to modify test iterations
- Set WARMUP=1 to include warmup phase

## Interpreting Results

### Span Operations
```
Running benchmark: Span Operations (depth: 1)
  Span nesting depth: 1
  Operations per run: 1000
Results:
  Average time: 8.45 μs  ✓ Within target range
```

What to look for:
- Base span creation should be under 10μs
- Linear scaling with depth
- Attribute impact should be minimal

### Context Propagation
```
Running benchmark: Context Propagation (10 values)
  Context values: 10
  Operations per run: 10000
Results:
  Average time: 0.75 μs  ✓ Excellent
```

What to look for:
- Sub-microsecond context switches
- Linear scaling with context size
- No memory leaks across async boundaries

### Common Issues and Solutions

1. High Span Creation Time
   - Check attribute creation overhead
   - Verify parent context lookup efficiency
   - Consider reducing default attributes

2. Context Switch Overhead
   - Minimize context value count
   - Use shallow context hierarchies
   - Cache frequently accessed values

3. Memory Growth
   - Monitor attribute pool usage
   - Check for context retention
   - Verify span cleanup

## Best Practices

### Span Management
```dart
// Good: Efficient span creation
final span = await Dartastic.startSpan('operation');
try {
  // Work
} finally {
  span.end();
}

// Avoid: Unnecessary attributes
span.setAttribute('timestamp', DateTime.now().toString()); // High cardinality!
```

### Context Usage
```dart
// Good: Efficient context propagation
await context.runWithContext(() async {
  // Work with context
});

// Avoid: Manual context management
final oldContext = DartasticContext.current;
// Work
// Risk: Context restoration might be missed
```

### Baggage Efficiency
```dart
// Good: Low cardinality baggage
baggage.put('service.name', 'payment-api');

// Avoid: High cardinality in baggage
baggage.put('request.id', uuid); // Use span attributes instead
```

## Performance Testing Your Application

1. Create Baseline
   ```dart
   final benchmark = EndToEndLatencyBenchmark(withTelemetry: false);
   benchmark.runAndPrint();
   ```

2. Measure with Telemetry
   ```dart
   final benchmark = EndToEndLatencyBenchmark(withTelemetry: true);
   benchmark.runAndPrint();
   ```

3. Compare Results
   - Acceptable overhead: < 10%
   - Investigate if higher

### Common Optimizations

1. Span Optimization
   - Batch attribute updates
   - Use appropriate sampling
   - Minimize span hierarchy depth

2. Context Optimization
   - Minimize context value count
   - Use context caching where appropriate
   - Clean up unused context values

3. Baggage Optimization
   - Keep baggage small
   - Use span attributes for high cardinality
   - Clear baggage when no longer needed

## Contributing Performance Improvements

1. Run Baseline
   ```bash
   dart run test/performance/run_all_benchmarks.dart > before.txt
   ```

2. Make Changes

3. Run Comparison
   ```bash
   dart run test/performance/run_all_benchmarks.dart > after.txt
   dart run test/performance/compare_results.dart before.txt after.txt
   ```

4. Document Impact
   - Include before/after metrics
   - Note any trade-offs
   - Explain optimization approach

## Questions and Support

If you encounter performance issues:
1. Run the relevant benchmarks
2. Compare with baseline metrics
3. Check the common issues section
4. Open an issue with benchmark results

Remember: Performance should be balanced with maintainability and reliability.
