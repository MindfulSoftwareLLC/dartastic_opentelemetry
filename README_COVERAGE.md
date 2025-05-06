# Test Coverage Guide

This document explains how to run tests and collect coverage data for the Dartastic OpenTelemetry SDK.

## Running Tests with Coverage

### Standard Tests

For most tests, you can use the standard Dart test runner with coverage:

```bash
dart test --coverage=coverage
```

This will run all tests and collect coverage data in the `coverage` directory.

### Problematic Tests

Some tests may fail when run in parallel or as part of a larger test suite. For these tests, we provide specialized scripts to run them in isolation while still collecting coverage data.

## Coverage Scripts

### 1. Comprehensive Coverage Update

The simplest way to run all tests and collect complete coverage:

```bash
./tool/update_coverage.sh
```

This script:
1. Runs standard tests with coverage
2. Runs problematic tests in isolation
3. Combines coverage data
4. Generates an HTML report (if lcov is installed)

### 2. Running Individual Tests in Isolation

If specific tests are failing, you can run them in isolation:

```bash
./tool/run_problem_tests.sh
```

This script runs problematic tests one at a time in a controlled environment.

### 3. Running All Tests in Isolation

To run each test in complete isolation (useful for tracking down subtle test interactions):

```bash
./tool/isolate_coverage.sh
```

This is slower but helps identify issues with test interference.

## Setting Up Your Environment

### Installing Coverage Tools

```bash
# Install coverage package
dart pub add coverage --dev

# For HTML reports (macOS)
brew install lcov

# For HTML reports (Ubuntu/Debian)
apt-get install lcov
```

## Modifying Test Environments

The test scripts use environment variables to modify test behavior:

- `DART_OTEL_ISOLATED_TESTING=true`: Signals tests to use more resilient settings
