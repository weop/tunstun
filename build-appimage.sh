#!/bin/bash
# AppImage Build Script for Tunstun - Creates both JIT and Release versions

set -e  # Exit on any error

echo "🔧 Building Tunstun AppImages - JIT and Release versions"
echo "========================================================"

# Check dependencies
echo "📋 Checking dependencies..."
if ! command -v flutter >/dev/null 2>&1; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

if ! command -v convert >/dev/null 2>&1; then
    echo "⚠️  ImageMagick not found. Installing..."
    sudo apt-get update && sudo apt-get install -y imagemagick
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf AppDir-jit AppDir-release tunstun-jit-*.AppImage tunstun-release-*.AppImage

# Configure Flutter
flutter config --enable-linux-desktop
flutter pub get

# Download appimagetool if not available
if ! command -v appimagetool >/dev/null 2>&1; then
    echo "📥 Downloading AppImageTool..."
    wget -O appimagetool-x86_64.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
    sudo mv appimagetool-x86_64.AppImage /usr/local/bin/appimagetool
fi

# Function to create common AppDir structure
create_appdir_structure() {
    local appdir=$1
    echo "📁 Creating $appdir structure..."
    mkdir -p $appdir/usr/bin
    mkdir -p $appdir/usr/share/applications
    mkdir -p $appdir/usr/share/icons/hicolor/{512x512,128x128,64x64,32x32,16x16}/apps
    mkdir -p $appdir/usr/lib
}

# Function to setup common files (desktop, icons, etc.)
setup_common_files() {
    local appdir=$1
    local app_name=$2
    
    echo "🎨 Setting up icons for $app_name..."
    convert assets/icons/icon.png -resize 512x512 $appdir/usr/share/icons/hicolor/512x512/apps/tunstun.png
    convert assets/icons/icon.png -resize 128x128 $appdir/usr/share/icons/hicolor/128x128/apps/tunstun.png
    convert assets/icons/icon.png -resize 64x64 $appdir/usr/share/icons/hicolor/64x64/apps/tunstun.png
    convert assets/icons/icon.png -resize 32x32 $appdir/usr/share/icons/hicolor/32x32/apps/tunstun.png
    convert assets/icons/icon.png -resize 16x16 $appdir/usr/share/icons/hicolor/16x16/apps/tunstun.png
    
    # Copy main icon for AppImage
    cp assets/icons/icon.png $appdir/tunstun.png
    
    # Create desktop file
    cat > $appdir/usr/share/applications/tunstun.desktop << EOF
[Desktop Entry]
Type=Application
Name=$app_name
Comment=A user-friendly developer tool for managing SSH tunnels
Exec=tunstun-wrapper.sh
Icon=tunstun
Categories=Network;Development;Utility;
Terminal=false
StartupWMClass=tunstun
Keywords=SSH;Tunnel;Network;Port;Forwarding;
EOF
    
    # Copy desktop file to AppDir root
    cp $appdir/usr/share/applications/tunstun.desktop $appdir/
}

# Function to bundle minimal system tray libraries
bundle_system_tray_libs() {
    local appdir=$1
    
    echo "📦 Bundling minimal system tray dependencies..."
    echo "   Strategy: Minimal bundling - only core system tray libraries"
    
    # Only the most essential system tray libraries
    ESSENTIAL_LIBS=(
        "libayatana-appindicator3.so.1"
        "libdbusmenu-gtk3.so.4"
    )
    
    echo "🔗 Bundling minimal system tray libraries..."
    for lib in "${ESSENTIAL_LIBS[@]}"; do
        echo "  - Looking for $lib..."
        lib_path=$(ldconfig -p | grep "$lib" | awk '{print $4}' | head -1)
        
        if [[ -n "$lib_path" && -f "$lib_path" ]]; then
            echo "    ✅ Found at $lib_path"
            cp "$lib_path" $appdir/usr/lib/
            
            # If it's a symlink, also copy the actual file
            if [[ -L "$lib_path" ]]; then
                real_path=$(readlink -f "$lib_path")
                if [[ -f "$real_path" && "$real_path" != "$lib_path" ]]; then
                    echo "    📎 Also copying real file: $real_path"
                    real_name=$(basename "$real_path")
                    cp "$real_path" "$appdir/usr/lib/$real_name"
                fi
            fi
        else
            echo "    ⚠️  Warning: Could not find $lib"
        fi
    done
}

# Function to create AppRun script
create_apprun() {
    local appdir=$1
    local app_type=$2
    
    cat > $appdir/AppRun << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
export APPDIR="\$SCRIPT_DIR"
export PATH="\$SCRIPT_DIR/usr/bin:\$PATH"

# Minimal bundling: Only essential system tray libraries bundled, rest from system
export LD_LIBRARY_PATH="\$SCRIPT_DIR/usr/lib:\$LD_LIBRARY_PATH"

# Set data directories
export XDG_DATA_DIRS="\$SCRIPT_DIR/usr/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Handle system tray support for both X11 and Wayland
export GDK_BACKEND=x11,wayland

# Flutter optimizations and compatibility settings
export FLUTTER_ENGINE_SWITCH_UI_THREAD_PRIORITY=false

# GLib compatibility settings to avoid symbol issues
export G_SLICE=always-malloc
export G_DEBUG=gc-friendly
export G_MESSAGES_DEBUG=""

cd "\$SCRIPT_DIR/usr/bin"

echo "Starting Tunstun ($app_type) with minimal bundled libraries..." >&2
exec "\$SCRIPT_DIR/usr/bin/tunstun" "\$@"
EOF
    chmod +x $appdir/AppRun
}

# Function to create wrapper script
create_wrapper() {
    local appdir=$1
    
    cat > $appdir/usr/bin/tunstun-wrapper.sh << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Minimal bundling approach: only essential system tray libraries bundled
export LD_LIBRARY_PATH="$SCRIPT_DIR/../lib:$LD_LIBRARY_PATH"

# Disable problematic GLib features that cause symbol issues
export G_SLICE=always-malloc
export G_DEBUG=gc-friendly

# Set environment for better system tray compatibility
export GDK_BACKEND=x11,wayland
export QT_QPA_PLATFORMTHEME=gtk3

cd "$SCRIPT_DIR"
exec "$SCRIPT_DIR/tunstun" "$@"
EOF
    chmod +x $appdir/usr/bin/tunstun-wrapper.sh
}

# BUILD JIT VERSION (Debug)
echo ""
echo "🚀 Building JIT (Debug) version..."
echo "=================================="

flutter build linux --debug

create_appdir_structure "AppDir-jit"
echo "📦 Copying JIT application files..."
cp -r build/linux/x64/debug/bundle/* AppDir-jit/usr/bin/

setup_common_files "AppDir-jit" "Tunstun (JIT)"
bundle_system_tray_libs "AppDir-jit"
create_wrapper "AppDir-jit"
create_apprun "AppDir-jit" "JIT"

# BUILD RELEASE VERSION (Non-JIT)
echo ""
echo "🚀 Building Release (Non-JIT) version..."
echo "======================================="

flutter build linux --release

create_appdir_structure "AppDir-release"
echo "📦 Copying Release application files..."
cp -r build/linux/x64/release/bundle/* AppDir-release/usr/bin/

setup_common_files "AppDir-release" "Tunstun"
bundle_system_tray_libs "AppDir-release"
create_wrapper "AppDir-release"
create_apprun "AppDir-release" "Release"

# CREATE APPIMAGES
echo ""
echo "🔨 Building AppImages..."
echo "========================"

export ARCH=x86_64
# Use VERSION from environment if set (for CI), otherwise generate local version
if [ -z "$VERSION" ]; then
    export VERSION="$(date +%Y%m%d-%H%M)"
fi
echo "📦 Using version: $VERSION"

echo "📦 Creating JIT AppImage..."
appimagetool AppDir-jit tunstun-jit-${VERSION}-x86_64.AppImage

echo "📦 Creating Release AppImage..."
appimagetool AppDir-release tunstun-release-${VERSION}-x86_64.AppImage

# Make AppImages executable
chmod +x tunstun-*.AppImage

echo ""
echo "✅ AppImage build complete!"
echo "================================"
echo ""
echo "📄 JIT Version (Debug):     $(ls tunstun-jit-*-x86_64.AppImage)"
echo "📊 Size:                    $(du -h tunstun-jit-*-x86_64.AppImage | cut -f1)"
echo ""
echo "📄 Release Version:         $(ls tunstun-release-*-x86_64.AppImage)"  
echo "📊 Size:                    $(du -h tunstun-release-*-x86_64.AppImage | cut -f1)"
echo ""
echo "🔗 Both versions include:"
echo "  - Minimal system tray libraries (libayatana-appindicator3, libdbusmenu-gtk3)"
echo "  - System compatibility (uses system glib/GTK to prevent conflicts)"
echo ""
echo "🚀 To test:"
echo "   JIT:     ./$(ls tunstun-jit-*-x86_64.AppImage)"
echo "   Release: ./$(ls tunstun-release-*-x86_64.AppImage)"
echo ""
echo "💡 Differences:"
echo "   - JIT: Debug symbols, larger size, development features"
echo "   - Release: Optimized, smaller size, production ready"
