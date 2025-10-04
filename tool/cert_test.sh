#!/bin/bash

# Certificate Testing Script for Dartastic OpenTelemetry
# Uses the existing otelcol binary from tool/test.sh

set -e

CERT_DIR="test/testing_utils/certs"

echo "=== Dartastic OpenTelemetry Certificate Testing ==="
echo ""

# Step 1: Ensure otelcol is downloaded
echo "📦 Step 1: Ensuring OpenTelemetry Collector is available..."
if [ ! -f "test/testing_utils/otelcol" ]; then
    echo "   Collector not found, running tool/test.sh to download..."
    # Just source the download function from test.sh
    source tool/test.sh download_otelcol
else
    echo "   ✅ Collector found at test/testing_utils/otelcol"
fi
echo ""

# Step 2: Generate test certificates
echo "📜 Step 2: Generating test certificates..."
if [ -d "$CERT_DIR" ] && [ -f "$CERT_DIR/ca-cert.pem" ]; then
    read -p "   Certificates already exist. Regenerate? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "   ✅ Using existing certificates"
        echo ""
    else
        rm -rf "$CERT_DIR"
        mkdir -p "$CERT_DIR"
    fi
fi

if [ ! -d "$CERT_DIR" ] || [ ! -f "$CERT_DIR/ca-cert.pem" ]; then
    echo "   Generating new certificates..."
    mkdir -p "$CERT_DIR"
    
    # Generate CA
    openssl genrsa -out "$CERT_DIR/ca-key.pem" 4096 2>/dev/null
    openssl req -new -x509 -days 365 -key "$CERT_DIR/ca-key.pem" \
        -out "$CERT_DIR/ca-cert.pem" \
        -subj "/C=US/ST=Test/L=Test/O=TestCA/CN=TestCA" 2>/dev/null
    
    # Generate server certificate
    openssl genrsa -out "$CERT_DIR/server-key.pem" 4096 2>/dev/null
    openssl req -new -key "$CERT_DIR/server-key.pem" \
        -out "$CERT_DIR/server-csr.pem" \
        -subj "/C=US/ST=Test/L=Test/O=TestServer/CN=localhost" 2>/dev/null
    
    # Create extensions for server cert (SAN)
    cat > "$CERT_DIR/server-ext.cnf" << EOF
subjectAltName = DNS:localhost,IP:127.0.0.1
EOF
    
    openssl x509 -req -in "$CERT_DIR/server-csr.pem" \
        -CA "$CERT_DIR/ca-cert.pem" \
        -CAkey "$CERT_DIR/ca-key.pem" \
        -CAcreateserial \
        -out "$CERT_DIR/server-cert.pem" \
        -days 365 \
        -extfile "$CERT_DIR/server-ext.cnf" 2>/dev/null
    
    # Generate client certificate (for mTLS)
    openssl genrsa -out "$CERT_DIR/client-key.pem" 4096 2>/dev/null
    openssl req -new -key "$CERT_DIR/client-key.pem" \
        -out "$CERT_DIR/client-csr.pem" \
        -subj "/C=US/ST=Test/L=Test/O=TestClient/CN=client" 2>/dev/null
    openssl x509 -req -in "$CERT_DIR/client-csr.pem" \
        -CA "$CERT_DIR/ca-cert.pem" \
        -CAkey "$CERT_DIR/ca-key.pem" \
        -CAcreateserial \
        -out "$CERT_DIR/client-cert.pem" \
        -days 365 2>/dev/null
    
    # Cleanup
    rm -f "$CERT_DIR"/*.csr "$CERT_DIR"/*.srl "$CERT_DIR/server-ext.cnf"
    
    echo "   ✅ Certificates generated in $CERT_DIR"
fi
echo ""

# Step 3: Run tests
echo "🧪 Step 3: Running certificate tests..."
echo ""
echo "Choose a test scenario:"
echo "  1) TLS with custom CA certificate (server cert verification)"
echo "  2) Mutual TLS (mTLS - client certificate authentication)"
echo "  3) Both"
echo ""
read -p "Enter choice (1-3): " -n 1 -r
echo ""
echo ""

# Function to kill all collector processes
kill_collectors() {
    echo "Cleaning up any running collectors..."
    pkill -9 otelcol 2>/dev/null || true
    sleep 2
}

run_tls_test() {
    echo "=== Running TLS Test (Custom CA) ==="
    echo ""
    
    # Ensure no collectors are running
    kill_collectors
    
    # Start collector with TLS config
    echo "Starting collector with TLS..."
    test/testing_utils/otelcol --config test/testing_utils/otelcol-config-tls.yaml &
    COLLECTOR_PID=$!
    
    # Wait for collector to start
    echo "Waiting for collector to start..."
    sleep 3
    
    # Run Dart test
    echo "Running Dart test..."
    export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
    export OTEL_EXPORTER_OTLP_ENDPOINT="https://localhost:4318"
    export OTEL_EXPORTER_OTLP_CERTIFICATE="$CERT_DIR/ca-cert.pem"
    export OTEL_LOG_LEVEL="DEBUG"
    
    dart test test/integration/cert_test.dart --name "TLS with CA cert"
    TEST_RESULT=$?
    
    # Stop collector
    echo "Stopping collector..."
    kill $COLLECTOR_PID 2>/dev/null || true
    wait $COLLECTOR_PID 2>/dev/null || true
    kill_collectors
    
    return $TEST_RESULT
}

run_mtls_test() {
    echo "=== Running mTLS Test (Mutual TLS) ==="
    echo ""
    
    # Ensure no collectors are running
    kill_collectors
    
    # Start collector with mTLS config
    echo "Starting collector with mTLS..."
    test/testing_utils/otelcol --config test/testing_utils/otelcol-config-mtls.yaml &
    COLLECTOR_PID=$!
    
    # Wait for collector to start
    echo "Waiting for collector to start..."
    sleep 3
    
    # Run Dart test
    echo "Running Dart test..."
    export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
    export OTEL_EXPORTER_OTLP_ENDPOINT="https://localhost:4318"
    export OTEL_EXPORTER_OTLP_CERTIFICATE="$CERT_DIR/ca-cert.pem"
    export OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE="$CERT_DIR/client-cert.pem"
    export OTEL_EXPORTER_OTLP_CLIENT_KEY="$CERT_DIR/client-key.pem"
    export OTEL_LOG_LEVEL="DEBUG"
    
    dart test test/integration/cert_test.dart --name "mTLS with client cert"
    TEST_RESULT=$?
    
    # Stop collector
    echo "Stopping collector..."
    kill $COLLECTOR_PID 2>/dev/null || true
    wait $COLLECTOR_PID 2>/dev/null || true
    kill_collectors
    
    return $TEST_RESULT
}

case $REPLY in
    1)
        run_tls_test
        ;;
    2)
        run_mtls_test
        ;;
    3)
        run_tls_test
        TLS_RESULT=$?
        echo ""
        echo "==========================================="
        echo ""
        run_mtls_test
        MTLS_RESULT=$?
        
        if [ $TLS_RESULT -eq 0 ] && [ $MTLS_RESULT -eq 0 ]; then
            echo ""
            echo "✅ All certificate tests passed!"
            exit 0
        else
            echo ""
            echo "❌ Some tests failed"
            exit 1
        fi
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
if [ $? -eq 0 ]; then
    echo "✅ Certificate test passed!"
else
    echo "❌ Certificate test failed"
    exit 1
fi
