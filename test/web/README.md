# Web Platform Tests

This directory contains tests that specifically target web platform functionality in the OpenTelemetry SDK. These tests require a browser environment to run properly as they test features that depend on browser-specific APIs.

## Running Web Tests

To run the web tests, you need to have Chrome installed on your machine. You can run the tests with:

```bash
# Run all web tests
dart test -p chrome test/web/

# Run specific web tests
dart test -p chrome test/web/util/zip/gzip_web_test.dart

# Run web tests with full stack traces for debugging
dart test -p chrome --chain-stack-traces test/web/
```

## Testing Web-Specific Implementations

The web tests verify that browser-specific implementations of our SDK functionality work correctly. This is especially important for:

1. Code that interacts with browser-specific APIs (like Compression Streams)
2. JS interop code that converts between Dart and JavaScript objects
3. Functionality that uses different implementations between web and other platforms

## Adding New Web Tests

When adding new web platform implementations to the SDK:

1. Create corresponding tests in this directory
2. Make sure to add `@TestOn('browser')` annotation at the top of the test file
3. Focus on testing edge cases specific to browser behavior
4. Consider adding tests for different browsers if needed (Chrome, Firefox, Safari)

## Notes on JS Interop

When working with JS interop, remember these important points:

1. Always test with real browser environments, as the behavior can differ from what type checking expects
2. Be careful with type casting between JS and Dart types
3. Add specific tests for data conversions and boundary conditions
4. Where needed, use `// ignore: invalid_runtime_check_with_js_interop_types` but ensure tests verify behavior

## Test Coverage

To get coverage reports for web tests:

```bash
# Generate coverage for web tests
dart test --coverage="coverage" -p chrome test/web/

# Format the coverage report
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.packages --report-on=lib
```

Note that web test coverage might show differently than VM test coverage due to differences in how code is compiled for the browser.
