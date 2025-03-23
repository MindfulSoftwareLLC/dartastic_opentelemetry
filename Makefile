# Makefile for Dartastic OpenTelemetry SDK

.PHONY: clean test coverage analyze format

default: test

# Clean project
clean:
	rm -rf .dart_tool/
	rm -rf build/
	rm -rf coverage/
	rm -f test.txt
	dart pub get

# Run all tests
test:
	dart test

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
check: clean format analyze test coverage
