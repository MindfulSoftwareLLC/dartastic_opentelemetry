# Makefile for Dartastic OpenTelemetry SDK

.PHONY: clean test test-safe test-web coverage analyze format check

default: test-safe

# Clean project
clean:
	rm -rf .dart_tool/
	rm -rf build/
	rm -rf coverage/
	rm -f test.txt
	dart pub get

# Run all tests (may encounter memory issues)
test:
	dart test

# Run web-specific tests in Chrome
test-web:
	chmod +x tool/web_tests.sh
	./tool/web_tests.sh

# Run unit + integration + performance tests with managed concurrency
# (avoids memory issues seen with plain `dart test`).
# Same script CI uses.
test-safe:
	chmod +x tool/test.sh
	./tool/test.sh

# Run tests with coverage
coverage:
	chmod +x tool/coverage.sh
	./tool/coverage.sh

# Run Dart analyzer
analyze:
	dart analyze > analyze.txt

# Format Dart code
format:
	dart format --fix lib test

# Run all checks
check: clean format analyze test test-web coverage
