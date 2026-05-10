#!/bin/bash
# Runs web-specific tests (those marked with `@TestOn('browser')`) in
# Chrome under both dart2js (default) and dart2wasm. CI also calls
# this script.
set -e

echo "Running web tests in Chrome (dart2js)..."
dart test -p chrome ./test/web

echo
echo "Running web tests in Chrome (dart2wasm)..."
dart test -p chrome -c dart2wasm ./test/web
