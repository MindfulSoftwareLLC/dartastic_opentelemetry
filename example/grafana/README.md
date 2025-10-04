# Grafana Cloud OTLP Integration Example

This directory contains examples and diagnostic tools for testing the Dartastic OpenTelemetry SDK with Grafana Cloud.

## Files

### Smoke Tests
- **`grafana_smoke_test.dart`** - Simple test that sends a span to Grafana Cloud
- **`run_grafana_smoke_test.sh`** - Shell script to configure environment and run the smoke test

## Quick Start

### 1. Get Your Grafana Cloud Credentials

1. Log into [Grafana Cloud](https://grafana.com/products/cloud/)
2. Navigate to **Connections** → **Add new connection** → **OpenTelemetry**
3. Copy your OTLP endpoint and generate an access token

### 2. Update the Shell Script

Edit `run_grafana_smoke_test.sh` or `run_grafana_smoke_test_improved.sh`:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="https://otlp-gateway-prod-us-east-0.grafana.net/otlp"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <YOUR_BASE64_TOKEN>"
```

**To create the Authorization header:**
```bash
# Format: <instance_id>:<token>
# Example: echo -n "1234567:glc_your_token_here" | base64
echo -n "<instance_id>:<grafana_token>" | base64
```

### 3. Run the Smoke Test

```bash
chmod +x run_grafana_smoke_test_improved.sh
./run_grafana_smoke_test_improved.sh
```

**Success indicators:**
- ✅ `OTelEnv: Parsed 1 header(s)` - Header was parsed from environment
- ✅ `OtlpHttpSpanExporter: Request headers: Authorization: [REDACTED]` - Header is being sent
- ✅ `Export request completed successfully` - Got 2xx response (not 401!)

### 5. Verify in Grafana Cloud

1. Go to your Grafana Cloud instance
2. Navigate to **Explore** → **Traces**
3. Look for traces with service name `@dart/dartastic_opentelemetry`
4. You should see a span named `gc-smoke-span`

## Common Issues

### Issue: 401 Unauthorized Error

**Symptom:**
```
[ERROR] Export request failed with status code 401
```

**Causes:**
1. ❌ **Incorrect authorization token** - Double-check your instance ID and token
2. ❌ **Headers not parsed correctly** - The fix in this PR addresses this!
3. ❌ **Token expired** - Generate a new token in Grafana Cloud

**Diagnosis:**
Run the diagnostic tool to verify headers are parsed correctly:
```bash
dart run grafana_headers_diagnostic.dart
```

### Issue: Headers Not Being Parsed

**Symptom:**
```
OTelEnv: Parsed 0 header(s)
```

**Solution:**
Make sure you're setting the environment variable BEFORE running the test:
```bash
# ❌ WRONG - env var not set
dart run grafana_smoke_test.dart

# ✅ CORRECT - env var set
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic ..."
dart run grafana_smoke_test.dart
```

### Issue: Base64 Padding Corrupted

**Symptom:**
The diagnostic shows a different value than what you set.

**Cause:**
This was the original bug! The old code would split on ALL `=` characters, corrupting base64 values.

**Solution:**
The fix in this PR addresses this by only splitting on the FIRST `=` character in each header pair.

## Environment Variables Reference

According to the [OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otel/protocol/exporter/):

### General OTLP Configuration
- `OTEL_EXPORTER_OTLP_PROTOCOL` - Protocol to use (`grpc`, `http/protobuf`, `http/json`)
- `OTEL_EXPORTER_OTLP_ENDPOINT` - Base endpoint URL
- `OTEL_EXPORTER_OTLP_HEADERS` - Headers as comma-separated `key=value` pairs
- `OTEL_LOG_LEVEL` - Log level (`DEBUG`, `INFO`, `WARN`, `ERROR`)

### Signal-Specific Configuration
These override the general settings for specific signals:
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` - Traces endpoint
- `OTEL_EXPORTER_OTLP_TRACES_HEADERS` - Traces-specific headers
- `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL` - Traces protocol

## Header Format

Headers must follow the [W3C Baggage](https://www.w3.org/TR/baggage/#header-content) format:

```bash
# Single header
export OTEL_EXPORTER_OTLP_HEADERS="key=value"

# Multiple headers (comma-separated)
export OTEL_EXPORTER_OTLP_HEADERS="key1=value1,key2=value2"

# Header with base64 value (containing '=' padding)
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic YWJjMTIzPT0="
```

**Important:** Header values CAN contain `=` characters (common in base64). The parser only splits on the FIRST `=` in each pair.

## Testing Without Grafana Cloud

You can test the SDK locally using the [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/):

```bash
# Using local collector (no auth needed)
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
unset OTEL_EXPORTER_OTLP_HEADERS  # No headers needed for local

dart run grafana_smoke_test.dart
```

## Additional Resources

- [Grafana Cloud Documentation](https://grafana.com/docs/grafana-cloud/)
- [OpenTelemetry Protocol Specification](https://opentelemetry.io/docs/specs/otel/protocol/)
- [OTLP Exporter Configuration](https://opentelemetry.io/docs/specs/otel/protocol/exporter/)
- [Issue #9: OTEL_EXPORTER_OTLP_HEADERS Support](https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry/issues/9)
