#!/bin/bash
# Reusable script to download OpenTelemetry Collector binary
# Can be sourced by other scripts

# Function to detect OS and architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # Map OS names
    case "$OS" in
        darwin) OS="darwin" ;;
        linux) OS="linux" ;;
        msys*|mingw*|cygwin*) OS="windows" ;;
        *) echo "Unsupported OS: $OS"; exit 1 ;;
    esac
    
    # Map architecture names
    case "$ARCH" in
        x86_64|amd64) ARCH="amd64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        i386|i686) ARCH="386" ;;
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    echo "${OS}_${ARCH}"
}

# Function to download otelcol
download_otelcol() {
    OTEL_VERSION="0.98.0"  # Update this to the desired version
    PLATFORM=$(detect_platform)
    OTELCOL_PATH="test/testing_utils/otelcol"
    
    # Check if otelcol already exists
    if [ -f "$OTELCOL_PATH" ]; then
        echo "OpenTelemetry Collector already exists at $OTELCOL_PATH"
        return 0
    fi
    
    echo "Downloading OpenTelemetry Collector for platform: $PLATFORM"
    
    # Create the directory if it doesn't exist
    mkdir -p "$(dirname "$OTELCOL_PATH")"
    
    # Construct download URL
    DOWNLOAD_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol_${OTEL_VERSION}_${PLATFORM}.tar.gz"
    
    # For Windows, use .zip instead of .tar.gz
    if [[ "$PLATFORM" == "windows_"* ]]; then
        DOWNLOAD_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol_${OTEL_VERSION}_${PLATFORM}.zip"
    fi
    
    # Download and extract
    TEMP_DIR=$(mktemp -d)
    echo "Downloading from: $DOWNLOAD_URL"
    
    if command -v curl > /dev/null; then
        curl -L -o "$TEMP_DIR/otelcol.archive" "$DOWNLOAD_URL"
    elif command -v wget > /dev/null; then
        wget -O "$TEMP_DIR/otelcol.archive" "$DOWNLOAD_URL"
    else
        echo "Error: Neither curl nor wget is available"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Extract the archive
    cd "$TEMP_DIR"
    if [[ "$PLATFORM" == "windows_"* ]]; then
        unzip "otelcol.archive"
        BINARY_NAME="otelcol.exe"
    else
        tar -xzf "otelcol.archive"
        BINARY_NAME="otelcol"
    fi
    cd - > /dev/null
    
    # Move the binary to the correct location
    if [ -f "$TEMP_DIR/$BINARY_NAME" ]; then
        mv "$TEMP_DIR/$BINARY_NAME" "$OTELCOL_PATH"
        chmod +x "$OTELCOL_PATH"
        echo "OpenTelemetry Collector downloaded successfully to $OTELCOL_PATH"
    else
        echo "Error: Could not find otelcol binary after extraction"
        ls -la "$TEMP_DIR"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Clean up
    rm -rf "$TEMP_DIR"
}
