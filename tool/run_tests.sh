#!/bin/bash
# Licensed under the Apache License, Version 2.0
# Copyright 2025, Michael Bushe, All rights reserved.

# Kill any existing otelcol processes
echo "Cleaning up any existing processes..."
ps -ef | grep otelcol | grep -v grep | awk '{print $2}' | xargs -r kill -9
ps -ef | grep dart | grep test | awk '{print $2}' | xargs -r kill -9

# Wait for a moment
sleep 2

# Run the test runner
dart tool/run_tests.dart

# Return the exit code from the test runner
exit $?
