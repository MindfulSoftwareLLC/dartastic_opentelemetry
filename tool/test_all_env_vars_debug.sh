#!/bin/bash
# Debug version - shows errors instead of hiding them

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

READ_ALL_PROG="$PROJECT_DIR/tool/read_all_env_vars.dart"

echo "Testing read_all_env_vars.dart script..."
echo "Script location: $READ_ALL_PROG"
echo ""

# Test 1: Run without any env vars to see if script works
echo "Test 1: Running script without env vars (should show all as <null>)..."
dart "$READ_ALL_PROG" text

echo ""
echo "Test 2: Running script with one env var set..."
OTEL_SDK_DISABLED="false" dart "$READ_ALL_PROG" text | grep "OTEL_SDK_DISABLED="

echo ""
echo "Test 3: Running script with --dart-define..."
dart --dart-define=OTEL_SDK_DISABLED="false" "$READ_ALL_PROG" text | grep "OTEL_SDK_DISABLED="

echo ""
echo "All tests passed!"
