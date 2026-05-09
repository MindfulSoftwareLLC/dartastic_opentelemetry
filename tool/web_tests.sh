#!/bin/bash
# Runs web-specific tests (those marked with `@TestOn('browser')`) in Chrome.
# CI also calls this script.
set -e

echo "Running web tests in Chrome..."
dart test -p chrome ./test/web
