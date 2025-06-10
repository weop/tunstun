import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class SystemTrayService with TrayListener {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  bool _isInitialized = false;
  bool _isDisabled = false;

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

  Future<void> _setupContextMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Show Tunstun',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit_app',
          label: 'Quit',
        ),
      ],
    );

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
    switch (menuItem.key) {
      case 'show_window':
        _showWindow();
        break;
      case 'quit_app':
        _quitApp();
        break;
    }
  }
}
