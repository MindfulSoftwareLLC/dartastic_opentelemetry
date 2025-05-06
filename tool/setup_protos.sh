#!/bin/bash
set -e

# Directory setup
PROTO_DIR="protos"
OUTPUT_DIR="lib/src/gen"
OPENTELEMETRY_PROTO_VERSION="v1.1.0"  # Update this to the version you want to use

# Create directories if they don't exist
mkdir -p "$PROTO_DIR/opentelemetry-proto"
mkdir -p "$OUTPUT_DIR"

# Download OpenTelemetry protos if they don't exist
if [ ! -d "$PROTO_DIR/opentelemetry-proto/.git" ]; then
  echo "Downloading OpenTelemetry protos..."
  rm -rf "$PROTO_DIR/opentelemetry-proto"
  git clone --depth 1 --branch $OPENTELEMETRY_PROTO_VERSION https://github.com/open-telemetry/opentelemetry-proto.git "$PROTO_DIR/opentelemetry-proto"
fi

# Generate Dart files
echo "Generating Dart files..."
protoc \
  --dart_out="grpc:$OUTPUT_DIR" \
  --proto_path="$PROTO_DIR/opentelemetry-proto" \
  "$PROTO_DIR/opentelemetry-proto/opentelemetry/proto/common/v1/common.proto" \
  "$PROTO_DIR/opentelemetry-proto/opentelemetry/proto/resource/v1/resource.proto" \
  "$PROTO_DIR/opentelemetry-proto/opentelemetry/proto/trace/v1/trace.proto" \
  "$PROTO_DIR/opentelemetry-proto/opentelemetry/proto/collector/trace/v1/trace_service.proto"

echo "Proto generation complete!"