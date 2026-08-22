#!/bin/bash
# Setup git hooks for local development
# Run this once after cloning the repository

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up git hooks..."

# Configure git to use our hooks directory
git config core.hooksPath "$SCRIPT_DIR/hooks"

# Make hooks executable
chmod +x "$SCRIPT_DIR/hooks/"*

echo "Git hooks installed successfully!"
echo "Hooks location: $SCRIPT_DIR/hooks"
echo ""
echo "Installed hooks:"
echo "  - pre-commit: Formats Dart files and restages them"
echo "  - pre-push: Blocks the push if the analyzer reports issues, tests"
echo "              fail, or coverage drops below the published badge"
