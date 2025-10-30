#!/bin/bash
# Comprehensive integration test for ALL OTel environment variables
# Tests both POSIX environment variables and --define flags

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

READ_ALL_PROG="$PROJECT_DIR/tool/read_all_env_vars.dart"

PASSED=0
FAILED=0
FAILED_TESTS=()

# Ensure dependencies are installed
echo "Ensuring dependencies are installed..."
cd "$PROJECT_DIR"
if ! dart pub get > /dev/null 2>&1; then
  echo -e "${RED}Failed to run 'dart pub get'. Please install dependencies first.${NC}"
  exit 1
fi
echo "Dependencies OK"
echo ""

echo "=================================================="
echo "Comprehensive OTel Environment Variables Test"
echo "Testing ALL env vars from env_constants.dart"
echo "=================================================="
echo ""

# Helper function to verify environment variable value
verify_env_value() {
  local var_name="$1"
  local expected_value="$2"
  local output="$3"
  local test_mode="$4"

  # Extract the value from output (format: VAR_NAME=value)
  local actual_value=$(echo "$output" | grep "^${var_name}=" | cut -d'=' -f2-)

  if [ "$actual_value" = "$expected_value" ]; then
    echo -e "${GREEN}  ✓ [$test_mode] $var_name = $expected_value${NC}"
    ((PASSED++))
    return 0
  else
    echo -e "${RED}  ✗ [$test_mode] $var_name: expected '$expected_value', got '$actual_value'${NC}"
    FAILED_TESTS+=("[$test_mode] $var_name")
    ((FAILED++))
    return 1
  fi
}

# Test a single env var with both POSIX and --define
test_env_var() {
  local var_name="$1"
  local test_value="$2"

  echo -e "${BLUE}Testing: $var_name${NC}"

  # Test 1: POSIX environment variable
  OUTPUT=$(env "$var_name=$test_value" dart "$READ_ALL_PROG" text 2>&1)
  verify_env_value "$var_name" "$test_value" "$OUTPUT" "POSIX"

  # Test 2: --define (use semicolons for comma-separated values)
  local define_value="$test_value"
  case "$var_name" in
    OTEL_RESOURCE_ATTRIBUTES|OTEL_PROPAGATORS|OTEL_EXPORTER_OTLP_HEADERS|OTEL_EXPORTER_OTLP_TRACES_HEADERS|OTEL_EXPORTER_OTLP_METRICS_HEADERS|OTEL_EXPORTER_OTLP_LOGS_HEADERS)
      # Replace commas with semicolons for --define compatibility
      define_value="${test_value//,/;}"
      ;;
  esac

  local temp_exe="$PROJECT_DIR/.tmp_test_compiled"
  if COMPILE_OUTPUT=$(dart compile exe "--define=${var_name}=${define_value}" "$READ_ALL_PROG" -o "$temp_exe" 2>&1); then    OUTPUT=$("$temp_exe" text 2>&1)
    verify_env_value "$var_name" "$test_value" "$OUTPUT" "--define"
    rm -f "$temp_exe"
  else
    echo -e "${RED}  ✗ [--define] compilation failed for $var_name${NC}"
    echo -e "${RED}     Command: dart compile exe --define=\"${var_name}=${test_value}\" \"$READ_ALL_PROG\" -o \"$temp_exe\"${NC}"
    echo -e "${RED}     Error: $COMPILE_OUTPUT${NC}"
    FAILED_TESTS+=("[--define] $var_name - compilation failed")
    ((FAILED++))
  fi

  return 0
}

echo -e "${YELLOW}=== General SDK Configuration ===${NC}"
test_env_var "OTEL_SDK_DISABLED" "false"
test_env_var "OTEL_RESOURCE_ATTRIBUTES" "key1=value1,key2=value2"
test_env_var "OTEL_SERVICE_NAME" "test-service"
test_env_var "OTEL_LOG_LEVEL" "DEBUG"
test_env_var "OTEL_PROPAGATORS" "tracecontext,baggage"
test_env_var "OTEL_TRACES_SAMPLER" "always_on"
test_env_var "OTEL_TRACES_SAMPLER_ARG" "0.5"

echo ""
echo -e "${YELLOW}=== Dartastic-specific Logging ===${NC}"
test_env_var "OTEL_LOG_METRICS" "true"
test_env_var "OTEL_LOG_SPANS" "true"
test_env_var "OTEL_LOG_EXPORT" "true"

echo ""
echo -e "${YELLOW}=== General OTLP Exporter Configuration ===${NC}"
test_env_var "OTEL_EXPORTER_OTLP_ENDPOINT" "http://collector:4318"
test_env_var "OTEL_EXPORTER_OTLP_PROTOCOL" "http/protobuf"
test_env_var "OTEL_EXPORTER_OTLP_HEADERS" "api-key=secret123,tenant=acme"
test_env_var "OTEL_EXPORTER_OTLP_INSECURE" "false"
test_env_var "OTEL_EXPORTER_OTLP_TIMEOUT" "10000"
test_env_var "OTEL_EXPORTER_OTLP_COMPRESSION" "gzip"
test_env_var "OTEL_EXPORTER_OTLP_CERTIFICATE" "/path/to/cert.pem"
test_env_var "OTEL_EXPORTER_OTLP_CLIENT_KEY" "/path/to/key.pem"
test_env_var "OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE" "/path/to/client-cert.pem"

echo ""
echo -e "${YELLOW}=== Traces-specific OTLP Configuration ===${NC}"
test_env_var "OTEL_TRACES_EXPORTER" "otlp"
test_env_var "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT" "http://traces:4318"
test_env_var "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL" "grpc"
test_env_var "OTEL_EXPORTER_OTLP_TRACES_HEADERS" "trace-key=trace123"
test_env_var "OTEL_EXPORTER_OTLP_TRACES_INSECURE" "true"
test_env_var "OTEL_EXPORTER_OTLP_TRACES_TIMEOUT" "5000"
test_env_var "OTEL_EXPORTER_OTLP_TRACES_COMPRESSION" "none"
test_env_var "OTEL_EXPORTER_OTLP_TRACES_CERTIFICATE" "/path/to/traces-cert.pem"
test_env_var "OTEL_EXPORTER_OTLP_TRACES_CLIENT_KEY" "/path/to/traces-key.pem"
test_env_var "OTEL_EXPORTER_OTLP_TRACES_CLIENT_CERTIFICATE" "/path/to/traces-client.pem"

echo ""
echo -e "${YELLOW}=== Metrics-specific OTLP Configuration ===${NC}"
test_env_var "OTEL_METRICS_EXPORTER" "otlp"
test_env_var "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT" "http://metrics:4318"
test_env_var "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL" "http/json"
test_env_var "OTEL_EXPORTER_OTLP_METRICS_HEADERS" "metrics-key=metrics123"
test_env_var "OTEL_EXPORTER_OTLP_METRICS_INSECURE" "false"
test_env_var "OTEL_EXPORTER_OTLP_METRICS_TIMEOUT" "15000"
test_env_var "OTEL_EXPORTER_OTLP_METRICS_COMPRESSION" "gzip"
test_env_var "OTEL_EXPORTER_OTLP_METRICS_CERTIFICATE" "/path/to/metrics-cert.pem"
test_env_var "OTEL_EXPORTER_OTLP_METRICS_CLIENT_KEY" "/path/to/metrics-key.pem"
test_env_var "OTEL_EXPORTER_OTLP_METRICS_CLIENT_CERTIFICATE" "/path/to/metrics-client.pem"

echo ""
echo -e "${YELLOW}=== Logs-specific OTLP Configuration ===${NC}"
test_env_var "OTEL_LOGS_EXPORTER" "otlp"
test_env_var "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT" "http://logs:4318"
test_env_var "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL" "http/protobuf"
test_env_var "OTEL_EXPORTER_OTLP_LOGS_HEADERS" "logs-key=logs123"
test_env_var "OTEL_EXPORTER_OTLP_LOGS_INSECURE" "true"
test_env_var "OTEL_EXPORTER_OTLP_LOGS_TIMEOUT" "20000"
test_env_var "OTEL_EXPORTER_OTLP_LOGS_COMPRESSION" "none"
test_env_var "OTEL_EXPORTER_OTLP_LOGS_CERTIFICATE" "/path/to/logs-cert.pem"
test_env_var "OTEL_EXPORTER_OTLP_LOGS_CLIENT_KEY" "/path/to/logs-key.pem"
test_env_var "OTEL_EXPORTER_OTLP_LOGS_CLIENT_CERTIFICATE" "/path/to/logs-client.pem"

echo ""
echo -e "${YELLOW}=== Batch Span Processor ===${NC}"
test_env_var "OTEL_BSP_SCHEDULE_DELAY" "5000"
test_env_var "OTEL_BSP_EXPORT_TIMEOUT" "30000"
test_env_var "OTEL_BSP_MAX_QUEUE_SIZE" "2048"
test_env_var "OTEL_BSP_MAX_EXPORT_BATCH_SIZE" "512"

echo ""
echo -e "${YELLOW}=== Batch LogRecord Processor ===${NC}"
test_env_var "OTEL_BLRP_SCHEDULE_DELAY" "1000"
test_env_var "OTEL_BLRP_EXPORT_TIMEOUT" "30000"
test_env_var "OTEL_BLRP_MAX_QUEUE_SIZE" "2048"
test_env_var "OTEL_BLRP_MAX_EXPORT_BATCH_SIZE" "512"

echo ""
echo -e "${YELLOW}=== Attribute Limits ===${NC}"
test_env_var "OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT" "4096"
test_env_var "OTEL_ATTRIBUTE_COUNT_LIMIT" "128"

echo ""
echo -e "${YELLOW}=== Span Limits ===${NC}"
test_env_var "OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT" "8192"
test_env_var "OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT" "128"
test_env_var "OTEL_SPAN_EVENT_COUNT_LIMIT" "128"
test_env_var "OTEL_SPAN_LINK_COUNT_LIMIT" "128"
test_env_var "OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT" "128"
test_env_var "OTEL_LINK_ATTRIBUTE_COUNT_LIMIT" "128"

echo ""
echo -e "${YELLOW}=== LogRecord Limits ===${NC}"
test_env_var "OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT" "4096"
test_env_var "OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT" "128"

echo ""
echo -e "${YELLOW}=== Metrics SDK Configuration ===${NC}"
test_env_var "OTEL_METRICS_EXEMPLAR_FILTER" "trace_based"
test_env_var "OTEL_METRIC_EXPORT_INTERVAL" "60000"
test_env_var "OTEL_METRIC_EXPORT_TIMEOUT" "30000"

echo ""
echo -e "${YELLOW}=== Zipkin Exporter ===${NC}"
test_env_var "OTEL_EXPORTER_ZIPKIN_ENDPOINT" "http://zipkin:9411/api/v2/spans"
test_env_var "OTEL_EXPORTER_ZIPKIN_TIMEOUT" "10000"

echo ""
echo -e "${YELLOW}=== Prometheus Exporter ===${NC}"
test_env_var "OTEL_EXPORTER_PROMETHEUS_HOST" "localhost"
test_env_var "OTEL_EXPORTER_PROMETHEUS_PORT" "9464"

echo ""
echo -e "${YELLOW}=== Unsupported Environment Variables ===${NC}"
echo -e "${BLUE}Testing: OTEL_FOO (should be ignored)${NC}"

# POSIX test - unsupported var should return empty string or null
OUTPUT=$(env "OTEL_FOO=bar" dart "$READ_ALL_PROG" text 2>&1)
ACTUAL=$(echo "$OUTPUT" | grep "^OTEL_FOO=" | cut -d'=' -f2-)
if [ "$ACTUAL" = "<null>" ] || [ "$ACTUAL" = "" ]; then
  echo -e "${GREEN}  ✓ [POSIX] OTEL_FOO correctly ignored${NC}"
  ((PASSED++))
else
  echo -e "${RED}  ✗ [POSIX] OTEL_FOO should be ignored, got '$ACTUAL'${NC}"
  FAILED_TESTS+=("[POSIX] OTEL_FOO not ignored")
  ((FAILED++))
fi

# --define test - unsupported var should return empty string or null
temp_exe="$PROJECT_DIR/.tmp_test_compiled"
if dart compile exe "--define=OTEL_FOO=bar" "$READ_ALL_PROG" -o "$temp_exe" >/dev/null 2>&1; then
  OUTPUT=$("$temp_exe" text 2>&1)
  ACTUAL=$(echo "$OUTPUT" | grep "^OTEL_FOO=" | cut -d'=' -f2-)
  if [ "$ACTUAL" = "<null>" ] || [ "$ACTUAL" = "" ]; then
    echo -e "${GREEN}  ✓ [--define] OTEL_FOO correctly ignored${NC}"
    ((PASSED++))
  else
    echo -e "${RED}  ✗ [--define] OTEL_FOO should be ignored, got '$ACTUAL'${NC}"
    FAILED_TESTS+=("[--define] OTEL_FOO not ignored")
    ((FAILED++))
  fi
  rm -f "$temp_exe"
fi

echo ""
echo "=================================================="
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
  echo -e "${GREEN}Total: $PASSED passed, $FAILED failed${NC}"
else
  echo -e "${RED}✗ SOME TESTS FAILED${NC}"
  echo -e "Total: $PASSED passed, ${RED}$FAILED failed${NC}"
  echo ""
  echo -e "${RED}Failed tests:${NC}"
  for test in "${FAILED_TESTS[@]}"; do
    echo -e "  ${RED}✗ $test${NC}"
  done
  exit 1
fi
echo "=================================================="