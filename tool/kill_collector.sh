#!/bin/bash

# Function to kill processes
kill_proc() {
    local pattern=$1
    pids=$(ps aux | grep "$pattern" | grep -v "grep" | awk '{print $2}')
    if [ ! -z "$pids" ]; then
        echo "Killing process matching: $pattern"
        echo "$pids" | xargs kill -9
    else
        echo "No processes found matching: $pattern"
    fi
}

# Kill all collector instances
kill_proc "otelcol"

# Kill any processes using port 8888 (Prometheus)
lsof_out=$(lsof -i :8888 2>/dev/null)
if [ ! -z "$lsof_out" ]; then
    echo "Killing processes on port 8888:"
    echo "$lsof_out"
    lsof -i :8888 -t | xargs kill -9
fi

# Kill any processes using port 4317 (OTLP)
lsof_out=$(lsof -i :4317 2>/dev/null)
if [ ! -z "$lsof_out" ]; then
    echo "Killing processes on port 4317:"
    echo "$lsof_out"
    lsof -i :4317 -t | xargs kill -9
fi

# Kill any processes using port 4316 (Our test port)
lsof_out=$(lsof -i :4316 2>/dev/null)
if [ ! -z "$lsof_out" ]; then
    echo "Killing processes on port 4316:"
    echo "$lsof_out"
    lsof -i :4316 -t | xargs kill -9
fi