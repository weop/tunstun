# tunstun

<br>

<div align="center">
  <img src="assets/icons/icon.png" alt="Tunstun Logo" width="150" height="150">
</div>

<br>

A user friendly linux GUI tool that allows users to easily create and maintain remote ssh tunnels.



## Features

- **Easy Tunnel Management**: Create, edit, and manage SSH tunnels through a simple, intuitive interface
- **Multiple Configuration Files**: Save, open, and manage different sets of tunnel configurations in YAML files
- **Configuration Manager**: Centralized interface for managing multiple tunnel configuration files (Ctrl+O)
- **Import/Export**: Load configurations from files or export current tunnels to new files
- **Configuration Merging**: Combine tunnels from multiple configuration files
- **Persistent Configuration**: Tunnel configurations are saved to disk in YAML format
- **Real-time Status**: See which tunnels are connected or disconnected at a glance
- **Quick Connect/Disconnect**: Toggle tunnel connections with a single click
- **Enhanced Error Handling**: Port conflict detection and SSH connectivity testing
- **Connection Cancellation**: Cancel connection attempts that are taking too long
- **Custom Window Controls**: Native desktop experience with custom title bar
- **Keyboard Shortcuts**: Efficient navigation with keyboard shortcuts
- **System Tray Integration**: Run in background with system tray support
- **Linux-Optimized**: Native Linux desktop application with AppImage distribution

## 🎹 Keyboard Shortcuts

- **Ctrl+N**: Add new tunnel
- **Ctrl+O**: Open Configuration Manager
- **F5 / Ctrl+R**: Refresh tunnel list
- **Ctrl+Q**: Close application (with confirmation)
- **Ctrl+H**: Hide to system tray
- **?**: Show keyboard shortcuts help dialog

## Configuration Management

### Multiple Configuration Files

Tunstun now supports managing multiple YAML configuration files:

- **Save As**: Save current tunnels to a custom YAML file
- **Open**: Load tunnels from any YAML file
- **Export**: Export current configuration without changing the active file
- **Merge**: Combine tunnels from multiple files
- **New**: Create a new empty configuration

**✨ Built-in File Browser:** No system dependencies required - works without zenity, kdialog, or other external tools.

### Quick Access

Use the **folder icon** in the toolbar for quick access to:
- Configuration Manager (Ctrl+O)
- New Configuration
- Open Configuration File
- Save As...
- Export Current Configuration

### Configuration Manager (Ctrl+O)

The Configuration Manager provides:
- View all configuration files in your tunstun configuration directory
- File information (tunnel count, last modified, size)
- Load, merge, or delete configurations
- Create new configurations
- Browse for files anywhere on your system
- Built-in Flutter file browser with no external dependencies

## TODO
- Save and load tunnels


## Usage

1. **Add a Tunnel**: Click the "+" button to add a new tunnel configuration
2. **Connect/Disconnect**: Use the play/stop buttons to control individual tunnels
3. **Manage Configurations**: Press Ctrl+O to open the Configuration Manager
4. **Save/Load**: Use the folder menu to save current tunnels or load different configurations
5. **Connect All**: Use "Connect All" to start all tunnels at once

## Installation

### AppImage (Linux - Recommended)
Download the latest AppImage from the [Releases](https://github.com/weop/tunstun/releases) page:

```bash
# For Debian/Ubuntu 
apt install libayatana-appindicator3-1

# For Arch/Manjaro
pacman -S gtk3 libayatana-indicator libdbusmenu-glib

# Download and make executable
chmod +x tunstun-*.AppImage

# Run the application
./tunstun-*.AppImage
```

**AppImage Features:**
- ✅ Self-contained, no installation required
- ✅ System tray integration
- ✅ Works on most Linux distributions
- ✅ Bundled system dependencies (libayatana-appindicator3, etc.)

### Building AppImage Locally

```bash
./build-appimage.sh
```

This creates two optimized AppImage versions:
- **Release Version**: `tunstun-release-YYYYMMDD-HHMM-x86_64.AppImage` (~19MB, production-ready)
- **JIT Version**: `tunstun-jit-YYYYMMDD-HHMM-x86_64.AppImage` (~47MB, debug build)

Both versions include minimal system tray library bundling for maximum compatibility.

### From Source
```bash
git clone https://github.com/weop/tunstun.git
cd tunstun
flutter pub get
flutter run -d linux
```

## Requirements

### For Users
- SSH client installed on your system
- SSH access to the jump server
- Linux: glibc 2.31+ (Ubuntu 20.04+, equivalent for other distros)

### For Development
- Flutter 3.8.0 or higher
- Linux: `sudo apt install libayatana-appindicator3-dev` for system tray support

## Development

### Quick Start

```bash
# Get dependencies
flutter pub get

# Install system tray dependencies
sudo apt install libayatana-appindicator3-dev

# Run on Linux desktop
flutter run -d linux

# Build for release
flutter build linux --release
```


## Configuration Storage

Tunnel configurations are automatically saved to:
- **Primary:** `~/Documents/tunstun/tunnels.yaml`
- **Fallback:** `~/tunstun/tunnels.yaml` (if Documents directory is not accessible)

The tunstun directory is automatically created if it doesn't exist.

Example configuration format:
```yaml
tunnels:
  - id: "example-1"
    name: "Development Server"
    remoteHost: "192.168.2.1"
    remotePort: 80
    sshUser: "ssh-user"
    sshHost: "ssh-server"
    localPort: 8080
    isConnected: false
```