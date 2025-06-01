import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class SystemTrayService {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;
  bool _isDisabled = false; // Track if system tray should be disabled

  bool get isAvailable => _isInitialized && !_isDisabled;

  Future<void> initSystemTray() async {
    if (_isInitialized || _isDisabled) return;

    try {
      debugPrint('Initializing system tray...');

      // Add progressive delays to ensure system stability
      await Future.delayed(const Duration(milliseconds: 500));

      // Check for system tray support before attempting initialization
      if (!await _checkSystemTraySupport()) {
        debugPrint('System tray support not available - marking as disabled');
        _isDisabled = true;
        return;
      }

      debugPrint(
        'System tray support confirmed, proceeding with initialization...',
      );
      await Future.delayed(const Duration(milliseconds: 300));

      // Initialize system tray with minimal configuration first
      debugPrint('Calling _systemTray.initSystemTray...');
      await _systemTray.initSystemTray(
        title: "Tunstun",
        iconPath: _getIconPath(),
        toolTip: "Tunstun SSH Tunnel Manager",
        isTemplate: false, // Better for Wayland systems
      );
      debugPrint('System tray base initialization completed');

      // Add another delay before setting up menu
      await Future.delayed(const Duration(milliseconds: 200));

      // Set up context menu
      debugPrint('Setting up context menu...');
      final Menu menu = Menu();

      await menu.buildFrom([
        MenuItemLabel(
          label: 'Show Tunstun',
          onClicked: (menuItem) => _showWindow(),
        ),
        MenuSeparator(),
        MenuItemLabel(label: 'Quit', onClicked: (menuItem) => _quitApp()),
      ]);

      await _systemTray.setContextMenu(menu);
      debugPrint('Context menu set successfully');

      // Add delay before event handler registration
      await Future.delayed(const Duration(milliseconds: 100));

      // Handle system tray click
      debugPrint('Registering event handler...');
      _systemTray.registerSystemTrayEventHandler((eventName) {
        debugPrint('System tray event: $eventName');
        if (eventName == kSystemTrayEventClick) {
          _showWindow();
        }
      });

      _isInitialized = true;
      debugPrint(
        'System tray initialized successfully with icon: ${_getIconPath()}',
      );
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize system tray: $e');
      debugPrint('Stack trace: $stackTrace');

      // Try fallback icon if primary fails
      try {
        debugPrint('Attempting fallback initialization...');
        await _systemTray.initSystemTray(
          title: "Tunstun",
          iconPath: _getFallbackIconPath(),
          toolTip: "Tunstun SSH Tunnel Manager",
          isTemplate: false,
        );

        // Set up context menu for fallback
        final Menu menu = Menu();
        await menu.buildFrom([
          MenuItemLabel(
            label: 'Show Tunstun',
            onClicked: (menuItem) => _showWindow(),
          ),
          MenuSeparator(),
          MenuItemLabel(label: 'Quit', onClicked: (menuItem) => _quitApp()),
        ]);
        await _systemTray.setContextMenu(menu);

        _systemTray.registerSystemTrayEventHandler((eventName) {
          if (eventName == kSystemTrayEventClick) {
            _showWindow();
          }
        });

        _isInitialized = true;
        debugPrint(
          'System tray initialized with fallback icon: ${_getFallbackIconPath()}',
        );
      } catch (fallbackError, fallbackStackTrace) {
        debugPrint(
          'Failed to initialize system tray with fallback: $fallbackError',
        );
        debugPrint('Fallback stack trace: $fallbackStackTrace');
        _isDisabled = true; // Disable system tray functionality
        debugPrint('System tray disabled due to initialization failures');
      }
    }
  }

  // Check if system tray support is available before attempting initialization
  Future<bool> _checkSystemTraySupport() async {
    try {
      // Check for required environment variables and processes on Linux
      final env = Platform.environment;

      // For X11 systems, check for notification area support
      if (env['DISPLAY'] != null) {
        debugPrint('X11 display detected: ${env['DISPLAY']}');
        return true; // Assume X11 has tray support
      }

      // For Wayland, check if status notifier is available
      if (env['WAYLAND_DISPLAY'] != null) {
        debugPrint('Wayland session detected: ${env['WAYLAND_DISPLAY']}');

        // Check if DBus is available (required for StatusNotifierItem)
        try {
          final result = await Process.run('which', [
            'dbus-daemon',
          ], runInShell: true);
          if (result.exitCode != 0) {
            debugPrint('DBus not available - system tray likely unsupported');
            return false;
          }
          debugPrint('DBus available - system tray should work');
          return true;
        } catch (e) {
          debugPrint('Error checking DBus availability: $e');
          return false;
        }
      }

      // No display server detected
      debugPrint('No display server detected - disabling system tray');
      return false;
    } catch (e) {
      debugPrint('Error checking system tray support: $e');
      return false; // Conservative approach - disable if check fails
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
      await _systemTray.setToolTip(tooltip);
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
      debugPrint(
        'System tray not available, hiding window without tray functionality',
      );
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
    // Linux (including Sway/Wayland) - use smaller icon optimized for system tray
    return 'assets/icons/tray_icon_22.png';
  }

  String _getFallbackIconPath() {
    // Linux fallback sequence: 16px -> 24px -> original
    return 'assets/icons/tray_icon_16.png';
  }

  Future<void> dispose() async {
    if (!_isInitialized || _isDisabled) return;
    try {
      // Destroy the system tray (this should automatically clean up event handlers)
      await _systemTray.destroy();
      _isInitialized = false;
      debugPrint('System tray disposed successfully');
    } catch (e) {
      debugPrint('Failed to dispose system tray: $e');
      // Force reset state even if dispose fails
      _isInitialized = false;
    }
  }
}
