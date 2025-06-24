#!/bin/bash

# Drift Repository - Integration Tests Runner
# Assumes Drift environment is set up (code generation completed)

cd "$(dirname "$0")/.."

echo "🧪 Running Drift Repository Integration Tests..."

# Check if generated code exists
if [ ! -d "lib/src" ]; then
    echo "❌ Generated code not found"
    echo "💡 Run setup first with: ./scripts/start_emulator.sh"
    exit 1
fi

echo "✅ Drift environment detected"

# Run integration tests
echo "🚀 Running integration tests..."
dart test test/integration/all_integration_tests.dart
