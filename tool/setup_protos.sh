#!/bin/bash
set -e

# Directory setup
PROTO_DIR="protos"
OUTPUT_DIR="lib/proto"
TEMP_DIR=".proto_gen_temp"
OPENTELEMETRY_PROTO_VERSION="v1.11.0"  # Update this to the version you want to use

PROTO_CHECKOUT="$PROTO_DIR/opentelemetry-proto"

# Create directories if they don't exist
mkdir -p "$PROTO_CHECKOUT"

# Download OpenTelemetry protos if they don't exist, otherwise move the
# existing checkout to the requested tag. A checkout left by an earlier run
# stays on the tag it was cloned with, so bumping OPENTELEMETRY_PROTO_VERSION
# alone would regenerate the old schema.
if [ ! -d "$PROTO_CHECKOUT/.git" ]; then
  echo "Downloading OpenTelemetry protos $OPENTELEMETRY_PROTO_VERSION..."
  rm -rf "$PROTO_CHECKOUT"
  git clone --depth 1 --branch "$OPENTELEMETRY_PROTO_VERSION" https://github.com/open-telemetry/opentelemetry-proto.git "$PROTO_CHECKOUT"
else
  echo "Checking out OpenTelemetry protos $OPENTELEMETRY_PROTO_VERSION..."
  # The clone is shallow, so the tag has to be fetched before it can be
  # checked out. Fetching a tag that is already present is a no-op.
  git -C "$PROTO_CHECKOUT" fetch --quiet --depth 1 origin \
    "refs/tags/$OPENTELEMETRY_PROTO_VERSION:refs/tags/$OPENTELEMETRY_PROTO_VERSION"
  git -C "$PROTO_CHECKOUT" checkout --quiet "$OPENTELEMETRY_PROTO_VERSION"
fi

CHECKED_OUT="$(git -C "$PROTO_CHECKOUT" describe --tags --exact-match 2>/dev/null || true)"
if [ "$CHECKED_OUT" != "$OPENTELEMETRY_PROTO_VERSION" ]; then
  echo "Error: $PROTO_CHECKOUT is at '${CHECKED_OUT:-an untagged commit}', expected $OPENTELEMETRY_PROTO_VERSION"
  exit 1
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