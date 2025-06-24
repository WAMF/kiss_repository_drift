#!/bin/bash

# Drift Repository - Local Database Setup Script
echo "🚀 Setting up Drift (SQLite) Database Environment..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📁 Project directory: $PROJECT_DIR"

# Create data directory for database files
mkdir -p "$PROJECT_DIR/data"

# SQLite doesn't require an external emulator, but we can prepare the environment
echo "✅ Drift uses SQLite which runs in-process"
echo "✅ No external emulator required"
echo "✅ Database files will be created in: $PROJECT_DIR/data/"

# Generate Drift code if needed
echo "🔧 Checking if code generation is needed..."
cd "$PROJECT_DIR"

if [ -f "pubspec.yaml" ]; then
    echo "📦 Running pub get..."
    dart pub get
    
    echo "🏗️  Running code generation..."
    dart run build_runner build --delete-conflicting-outputs
    
    echo "✅ Drift environment ready!"
    echo "💡 Database will be created automatically when first accessed"
    echo "💡 Run tests with: ./scripts/run_tests.sh"
else
    echo "❌ pubspec.yaml not found in $PROJECT_DIR"
    exit 1
fi
