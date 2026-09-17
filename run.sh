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
    
    # CMake caches absolute GTK include paths, which differ between distros
    # (Debian: /usr/lib/x86_64-linux-gnu, Arch: /usr/lib). Drop a cache that
    # was generated on another system, otherwise CMake fails to regenerate.
    cache="./build/linux/x64/debug/CMakeCache.txt"
    if [[ -f "$cache" ]]; then
        gtk_dirs=$(grep '^GTK_INCLUDE_DIRS:' "$cache" | cut -d= -f2- | tr ';' '\n')
        while IFS= read -r dir; do
            if [[ -n "$dir" && ! -d "$dir" ]]; then
                echo "🧹 Build cache is from another system ($dir missing), cleaning..."
                rm -rf ./build/linux/x64/debug
                break
            fi
        done <<< "$gtk_dirs"
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
