#!/bin/bash

# Drift Repository - Integration Tests Runner
# Drift uses embedded SQLite - no external emulator needed

cd "$(dirname "$0")/.."

echo "🧪 Running Drift Repository Integration Tests..."

# Ensure dependencies are installed
echo "📦 Installing dependencies..."
dart pub get

# Generate Drift code if needed
echo "🏗️  Generating Drift code..."
dart run build_runner build --delete-conflicting-outputs

echo "✅ Drift environment ready (uses embedded SQLite)"

# Run integration tests
echo "🚀 Running integration tests..."
dart test test/integration/all_integration_tests.dart
