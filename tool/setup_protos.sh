#!/bin/bash
set -e

# Directory setup
PROTO_DIR="protos"
OUTPUT_DIR="lib/proto"
TEMP_DIR=".proto_gen_temp"
OPENTELEMETRY_PROTO_VERSION="v1.1.0"  # Update this to the version you want to use

# Create directories if they don't exist
mkdir -p "$PROTO_DIR/opentelemetry-proto"

# Download OpenTelemetry protos if they don't exist
if [ ! -d "$PROTO_DIR/opentelemetry-proto/.git" ]; then
  echo "Downloading OpenTelemetry protos..."
  rm -rf "$PROTO_DIR/opentelemetry-proto"
  git clone --depth 1 --branch $OPENTELEMETRY_PROTO_VERSION https://github.com/open-telemetry/opentelemetry-proto.git "$PROTO_DIR/opentelemetry-proto"
fi

# Clean old generated files and temp dir
echo "Cleaning old generated files..."
rm -rf "$OUTPUT_DIR/common" "$OUTPUT_DIR/resource" "$OUTPUT_DIR/trace" "$OUTPUT_DIR/metrics" "$OUTPUT_DIR/logs" "$OUTPUT_DIR/collector"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

PROTO_PATH="$PROTO_DIR/opentelemetry-proto"

# Generate all Dart files to temp directory with full structure
echo "Generating Dart files..."

protoc --dart_out="grpc:$TEMP_DIR" \
  --proto_path="$PROTO_PATH" \
  "$PROTO_PATH/opentelemetry/proto/common/v1/common.proto" \
  "$PROTO_PATH/opentelemetry/proto/resource/v1/resource.proto" \
  "$PROTO_PATH/opentelemetry/proto/trace/v1/trace.proto" \
  "$PROTO_PATH/opentelemetry/proto/metrics/v1/metrics.proto" \
  "$PROTO_PATH/opentelemetry/proto/logs/v1/logs.proto" \
  "$PROTO_PATH/opentelemetry/proto/collector/trace/v1/trace_service.proto" \
  "$PROTO_PATH/opentelemetry/proto/collector/metrics/v1/metrics_service.proto" \
  "$PROTO_PATH/opentelemetry/proto/collector/logs/v1/logs_service.proto"

# Move from nested structure to flat structure
echo "Reorganizing generated files..."
mkdir -p "$OUTPUT_DIR"

# The generated structure is: $TEMP_DIR/opentelemetry/proto/...
# We want: $OUTPUT_DIR/...
if [ -d "$TEMP_DIR/opentelemetry/proto" ]; then
  cp -r "$TEMP_DIR/opentelemetry/proto/"* "$OUTPUT_DIR/"
fi

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Fix angle brackets in generated comments to avoid lint warnings
echo "Fixing angle brackets in comments..."
# Replace <signal> with the word "signal" to avoid HTML interpretation
find "$OUTPUT_DIR" -name "*.dart" -exec sed -i '' 's/<signal>/signal/g' {} \;

# Create barrel export file
echo "Creating barrel export file..."
cat > "$OUTPUT_DIR/opentelemetry_proto_dart.dart" << 'EOF'
/// OpenTelemetry Protocol Buffer definitions for Dart
///
/// This file exports all the generated protobuf classes for OpenTelemetry.
library opentelemetry_proto_dart;

// Common
export 'common/v1/common.pb.dart';
export 'common/v1/common.pbenum.dart';
export 'common/v1/common.pbjson.dart';

// Resource
export 'resource/v1/resource.pb.dart';
export 'resource/v1/resource.pbenum.dart';
export 'resource/v1/resource.pbjson.dart';

// Trace
export 'trace/v1/trace.pb.dart';
export 'trace/v1/trace.pbenum.dart';
export 'trace/v1/trace.pbjson.dart';

// Metrics
export 'metrics/v1/metrics.pb.dart';
export 'metrics/v1/metrics.pbenum.dart';
export 'metrics/v1/metrics.pbjson.dart';

// Logs
export 'logs/v1/logs.pb.dart';
export 'logs/v1/logs.pbenum.dart';
export 'logs/v1/logs.pbjson.dart';

// Collector Services
export 'collector/trace/v1/trace_service.pb.dart';
export 'collector/trace/v1/trace_service.pbenum.dart';
export 'collector/trace/v1/trace_service.pbgrpc.dart';
export 'collector/trace/v1/trace_service.pbjson.dart';

export 'collector/metrics/v1/metrics_service.pb.dart';
export 'collector/metrics/v1/metrics_service.pbenum.dart';
export 'collector/metrics/v1/metrics_service.pbgrpc.dart';
export 'collector/metrics/v1/metrics_service.pbjson.dart';

export 'collector/logs/v1/logs_service.pb.dart';
export 'collector/logs/v1/logs_service.pbenum.dart';
export 'collector/logs/v1/logs_service.pbgrpc.dart';
export 'collector/logs/v1/logs_service.pbjson.dart';
EOF

echo "Proto generation complete!"