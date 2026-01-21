import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'tunnel_service.dart';

class SystemTrayService with TrayListener {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  bool _isInitialized = false;
  bool _isDisabled = false;
  TunnelService? _tunnelService;

  bool get isAvailable => _isInitialized && !_isDisabled;

  Future<void> initSystemTray() async {
    if (_isInitialized || _isDisabled) return;

    try {
      debugPrint('Initializing system tray with tray_manager...');

      // Add tray listener
      trayManager.addListener(this);

      // Progressive delays for system stability
      await Future.delayed(const Duration(milliseconds: 500));

      // Check system tray support
      if (!await _checkSystemTraySupport()) {
        debugPrint('System tray support not available - marking as disabled');
        _isDisabled = true;
        return;
      }

      debugPrint('System tray support confirmed, proceeding with initialization...');
      await Future.delayed(const Duration(milliseconds: 300));

      // Set tray icon - tray_manager is much more robust
      await trayManager.setIcon(_getIconPath());
      debugPrint('Tray icon set successfully');

      // Set up context menu
      await _setupContextMenu();
      debugPrint('Context menu configured successfully');

      _isInitialized = true;
      debugPrint('System tray initialized successfully with tray_manager');
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize system tray: $e');
      debugPrint('Stack trace: $stackTrace');
      _isDisabled = true;
      debugPrint('System tray disabled due to initialization failures');
    }
  }

  /// Set the TunnelService reference and trigger initial menu rebuild
  void setTunnelService(TunnelService tunnelService) {
    _tunnelService = tunnelService;
    if (_isInitialized && !_isDisabled) {
      rebuildMenu();
    }
  }

  /// Rebuild the entire context menu (called when tunnel state changes)
  Future<void> rebuildMenu() async {
    if (!isAvailable) return;
    try {
      await _setupContextMenu();
      debugPrint('System tray menu rebuilt');
    } catch (e) {
      debugPrint('Failed to rebuild system tray menu: $e');
    }
  }

  Future<void> _setupContextMenu() async {
    final menuItems = <MenuItem>[
      MenuItem(
        key: 'show_window',
        label: 'Show Tunstun',
      ),
    ];

    // Add Tunnels submenu if TunnelService is available and has tunnels
    if (_tunnelService != null && _tunnelService!.tunnels.isNotEmpty) {
      final tunnelMenuItems = <MenuItem>[];

      for (final tunnel in _tunnelService!.tunnels) {
        final isConnected = tunnel.isConnected ||
                           _tunnelService!.hasActiveProcess(tunnel.id);

        // Add checkmark to label for connected tunnels
        final label = isConnected ? '✔ ${tunnel.name}' : tunnel.name;

        tunnelMenuItems.add(
          MenuItem(
            key: 'tunnel_${tunnel.id}',
            label: label,
          ),
        );
      }

      menuItems.add(
        MenuItem.submenu(
          key: 'tunnels_submenu',
          label: 'Tunnels',
          submenu: Menu(items: tunnelMenuItems),
        ),
      );
    }

    menuItems.addAll([
      MenuItem.separator(),
      MenuItem(
        key: 'quit_app',
        label: 'Quit',
      ),
    ]);

    final menu = Menu(items: menuItems);
    await trayManager.setContextMenu(menu);
  }

  // Check if system tray support is available
  Future<bool> _checkSystemTraySupport() async {
    try {
      final env = Platform.environment;

      // Check for display server
      if (env['DISPLAY'] != null || env['WAYLAND_DISPLAY'] != null) {
        debugPrint('Display server detected - system tray should work');
        return true;
      }

      // For macOS, always assume tray support
      if (Platform.isMacOS) {
        debugPrint('macOS detected - system tray supported');
        return true;
      }

      // For Windows, always assume tray support
      if (Platform.isWindows) {
        debugPrint('Windows detected - system tray supported');
        return true;
      }

      debugPrint('No display server detected - disabling system tray');
      return false;
    } catch (e) {
      debugPrint('Error checking system tray support: $e');
      return false;
    }
  }

  void markAsDisabled() {
    _isDisabled = true;
    _isInitialized = false;
    debugPrint('System tray marked as disabled');
  }

  Future<void> updateTooltip(String tooltip) async {
    if (!isAvailable) return;
    try {
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      debugPrint('Failed to update system tray tooltip: $e');
    }
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setSkipTaskbar(false);
    } catch (e) {
      debugPrint('Failed to show window: $e');
    }
  }

  Future<void> _quitApp() async {
    try {
      await windowManager.destroy();
    } catch (e) {
      debugPrint('Failed to quit app: $e');
    }
  }

  Future<void> hideToTray() async {
    if (!isAvailable) {
      debugPrint('System tray not available, hiding window without tray functionality');
      try {
        await windowManager.hide();
        await windowManager.setSkipTaskbar(true);
      } catch (e) {
        debugPrint('Failed to hide window: $e');
      }
      return;
    }

    try {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    } catch (e) {
      debugPrint('Failed to hide to tray: $e');
    }
  }

  String _getIconPath() {
    if (Platform.isWindows) {
      return 'assets/icons/icon.png'; // Windows can use PNG with tray_manager
    } else if (Platform.isMacOS) {
      return 'assets/icons/icon.png'; // macOS
    } else {
      // Linux - try different sizes for better compatibility
      return 'assets/icons/icon.png';
    }
  }

  Future<void> dispose() async {
    if (!_isInitialized || _isDisabled) return;
    try {
      trayManager.removeListener(this);
      await trayManager.destroy();
      _isInitialized = false;
      debugPrint('System tray disposed successfully');
    } catch (e) {
      debugPrint('Failed to dispose system tray: $e');
      _isInitialized = false;
    }
  }

  // TrayListener implementations
  @override
  void onTrayIconMouseDown() {
    debugPrint('Tray icon clicked');
    if (Platform.isWindows) {
      _showWindow();
    } else {
      // On macOS and Linux, show context menu on left click
      trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    debugPrint('Tray icon right-clicked');
    if (Platform.isWindows) {
      trayManager.popUpContextMenu();
    } else {
      _showWindow();
    }
  }

  @override
  void onTrayIconRightMouseUp() {
    // Optional: handle right mouse up if needed
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('Tray menu item clicked: ${menuItem.key}');

    // Check if it's a tunnel menu item
    if (menuItem.key?.startsWith('tunnel_') ?? false) {
      _handleTunnelToggle(menuItem.key!);
      return;
    }

    switch (menuItem.key) {
      case 'show_window':
        _showWindow();
        break;
      case 'quit_app':
        _quitApp();
        break;
    }
  }

  /// Handle tunnel toggle from tray menu
  void _handleTunnelToggle(String menuKey) async {
    if (_tunnelService == null) {
      debugPrint('TunnelService not available');
      return;
    }

    try {
      // Extract tunnel ID from key format 'tunnel_<id>'
      final tunnelId = menuKey.substring('tunnel_'.length);

      // Check if tunnel is currently connected
      final isConnected = _tunnelService!.hasActiveProcess(tunnelId);

      if (isConnected) {
        debugPrint('Disconnecting tunnel from tray: $tunnelId');
        await _tunnelService!.disconnectTunnel(tunnelId);
      } else {
        debugPrint('Connecting tunnel from tray: $tunnelId');
        final result = await _tunnelService!.connectTunnel(tunnelId);

        if (!result.success) {
          debugPrint('Failed to connect tunnel from tray: ${result.errorMessage}');
          // Note: We can't show dialog from tray, errors are logged to console
          // User can open main window for detailed error information
        }
      }
    } catch (e) {
      debugPrint('Error toggling tunnel from tray: $e');
    }
  }
}
