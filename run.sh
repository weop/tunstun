#!/bin/bash

# Tunstun Launcher Script

echo "🚀 Starting Tunstun SSH Tunnel Manager..."

# Check if Linux build exists
if [[ -f "./build/linux/x64/release/bundle/tunstun" ]]; then
    echo "🐧 Running Linux desktop version..."
    ./build/linux/x64/release/bundle/tunstun
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🔨 Linux build not found, running with flutter..."
    if ! command -v flutter &> /dev/null; then
        echo "❌ Flutter not found. Please install Flutter first."
        exit 1
    fi
    
    # Get dependencies if needed
    if [ ! -d ".dart_tool" ]; then
        echo "📦 Installing dependencies..."
        flutter pub get
    fi
    
    echo "🐧 Running on Linux desktop..."
    flutter run -d linux
else
    echo "🌐 Running on web browser..."
    if ! command -v flutter &> /dev/null; then
        echo "❌ Flutter not found. Please install Flutter first."
        exit 1
    fi
    flutter run -d chrome
fi
