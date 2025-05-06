#!/bin/bash
# Script to run web-specific tests in Chrome

echo "Running OpenTelemetry SDK web tests in Chrome..."

# Make sure chrome is available
if ! command -v google-chrome &> /dev/null && ! command -v chrome &> /dev/null && ! command -v "Google Chrome" &> /dev/null; then
    echo "Error: Chrome browser not found. Please make sure Chrome is installed and in your PATH."
    exit 1
fi

# Clear any previous coverage data
mkdir -p coverage
rm -rf coverage/web

# Run the tests with coverage
echo "Running tests with coverage..."
dart test --coverage="coverage/web" -p chrome test/web/

# Check test results
RESULT=$?
if [ $RESULT -ne 0 ]; then
    echo "Web tests failed with exit code $RESULT"
    exit $RESULT
fi

echo "Web tests completed successfully."

# Format coverage report if coverage package is available
if dart pub global list | grep -q coverage; then
    echo "Formatting coverage report..."
    dart run coverage:format_coverage --lcov --in=coverage/web --out=coverage/web/lcov.info --packages=.packages --report-on=lib
    
    # Generate HTML report if lcov is available
    if command -v genhtml &> /dev/null; then
        echo "Generating HTML coverage report..."
        genhtml -o coverage/web/html coverage/web/lcov.info
        echo "HTML coverage report available at: coverage/web/html/index.html"
    fi
else
    echo "Note: Install the coverage package to generate coverage reports:"
    echo "  dart pub global activate coverage"
fi

echo "Web testing complete!"
