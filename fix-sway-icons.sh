#!/bin/bash

# Sway System Tray Icon Fix Script
echo "🔧 Fixing System Tray Icons for Sway/Waybar"
echo "============================================"

# Check if we have any image conversion tools
echo "Checking for available image tools..."

if command -v convert >/dev/null 2>&1; then
    echo "✓ ImageMagick convert found"
    CONVERT_CMD="convert"
elif command -v magick >/dev/null 2>&1; then
    echo "✓ ImageMagick magick found"
    CONVERT_CMD="magick"
elif command -v inkscape >/dev/null 2>&1; then
    echo "✓ Inkscape found"
    CONVERT_CMD="inkscape"
else
    echo "❌ No image conversion tools found"
    echo "Installing ImageMagick..."
    
    # Try to install ImageMagick
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y imagemagick
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y ImageMagick
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S imagemagick
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install ImageMagick
    else
        echo "❌ Could not install ImageMagick automatically"
        echo "Please install ImageMagick manually:"
        echo "  Ubuntu/Debian: sudo apt install imagemagick"
        echo "  Fedora: sudo dnf install ImageMagick"
        echo "  Arch: sudo pacman -S imagemagick"
        exit 1
    fi
    
    CONVERT_CMD="convert"
fi

# Create directory for optimized icons
mkdir -p assets/icons/tray

echo "Creating optimized tray icons..."

# Convert SVG to multiple PNG sizes optimized for system tray
if [ -f "assets/icon.svg" ]; then
    echo "Converting SVG icon to tray-optimized PNG files..."
    
    # Standard system tray sizes for Linux/Wayland
    for size in 16 22 24 32 48; do
        if [ "$CONVERT_CMD" = "inkscape" ]; then
            inkscape --export-width=$size --export-height=$size \
                --export-filename="assets/icons/tray/tray_${size}x${size}.png" \
                assets/icon.svg
        else
            $CONVERT_CMD assets/icon.svg -resize ${size}x${size} \
                assets/icons/tray/tray_${size}x${size}.png
        fi
        echo "  ✓ Created ${size}x${size} tray icon"
    done
    
    # Create the main tray icon (22x22 is optimal for most Wayland trays)
    if [ "$CONVERT_CMD" = "inkscape" ]; then
        inkscape --export-width=22 --export-height=22 \
            --export-filename="assets/icons/tray_icon.png" \
            assets/icon.svg
    else
        $CONVERT_CMD assets/icon.svg -resize 22x22 \
            assets/icons/tray_icon.png
    fi
    echo "  ✓ Created main tray icon (22x22)"
    
elif [ -f "assets/icons/icon.png" ]; then
    echo "Using existing PNG icon..."
    
    # Resize existing PNG
    for size in 16 22 24 32 48; do
        $CONVERT_CMD assets/icons/icon.png -resize ${size}x${size} \
            assets/icons/tray/tray_${size}x${size}.png
        echo "  ✓ Created ${size}x${size} tray icon"
    done
    
    # Create optimized main tray icon
    $CONVERT_CMD assets/icons/icon.png -resize 22x22 \
        assets/icons/tray_icon.png
    echo "  ✓ Created main tray icon (22x22)"
else
    echo "❌ No source icon found (assets/icon.svg or assets/icons/icon.png)"
    exit 1
fi

# Set proper permissions
chmod 644 assets/icons/tray_icon.png
chmod 644 assets/icons/tray/*.png 2>/dev/null || true

echo ""
echo "✅ System tray icons created successfully!"
echo ""
echo "📁 Created files:"
ls -la assets/icons/tray_icon.png
ls -la assets/icons/tray/ 2>/dev/null || echo "  (tray directory files)"

echo ""
echo "🔧 Sway/Waybar Compatibility Tips:"
echo ""
echo "1. Icon Size: 22x22 is optimal for most Wayland system trays"
echo "2. Format: PNG with transparency support"
echo "3. Location: Icons should be in app bundle assets/"
echo "4. System Tray: Make sure waybar has 'tray' module enabled"
echo ""
echo "📋 Waybar tray configuration example:"
echo '   "tray": {'
echo '     "icon-size": 22,'
echo '     "spacing": 10'
echo '   }'
echo ""
echo "🚀 Rebuild the app and the tray icon should display correctly!"
echo "   flutter clean && flutter build linux"
