import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'services/tunnel_service.dart';
import 'services/system_tray_service.dart';
import 'services/theme_service.dart';
import 'screens/tunnel_list_screen.dart';

void main() async {
  // Catch any Flutter engine errors early and log them
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorString = details.exception.toString();

    // Filter out known Flutter engine keyboard issues on Linux
    if (errorString.contains('keyboard') ||
        errorString.contains('KeyboardManager') ||
        errorString.contains('HardwareKeyboard') ||
        errorString.contains('KeyDownEvent') ||
        errorString.contains('_pressedKeys.containsKey')) {
      debugPrint(
        'Ignoring known Flutter keyboard engine issue: ${details.exception}',
      );
      return;
    }
    // Log other errors normally
    FlutterError.presentError(details);
  };

  // Also handle uncaught platform exceptions
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorString = error.toString();

    // Filter keyboard-related errors
    if (errorString.contains('keyboard') ||
        errorString.contains('KeyDown') ||
        errorString.contains('HardwareKeyboard')) {
      debugPrint('Ignoring platform keyboard error: $error');
      return true; // Mark as handled
    }

    debugPrint('Unhandled platform error: $error');
    debugPrint('Stack trace: $stack');
    return false; // Let Flutter handle other errors
  };

  WidgetsFlutterBinding.ensureInitialized();

  // Configure window manager for Linux desktop
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(720, 720),
    minimumSize: Size(720, 500),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Hide system title bar
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setPreventClose(true); // Prevent default close behavior

    // Initialize system tray - tray_manager is much more robust
    await _initializeSystemTray();
  });

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const TunstunApp(),
    ),
  );
}

// Simple system tray initialization using robust tray_manager
Future<void> _initializeSystemTray() async {
  try {
    // Small delay to ensure window is fully initialized
    debugPrint('Initializing system tray...');
    await Future.delayed(const Duration(milliseconds: 1000));

    await SystemTrayService().initSystemTray();

    if (SystemTrayService().isAvailable) {
      debugPrint('System tray initialization completed successfully');
    } else {
      debugPrint('System tray initialization failed - continuing without tray functionality');
    }
  } catch (e, stackTrace) {
    debugPrint('System tray initialization failed (this is non-fatal): $e');
    debugPrint('Initialization stack trace: $stackTrace');
    // Mark system tray as disabled so the app can continue without it
    SystemTrayService().markAsDisabled();
  }
}

class TunstunApp extends StatefulWidget {
  const TunstunApp({super.key});

  @override
  State<TunstunApp> createState() => _TunstunAppState();
}

class _TunstunAppState extends State<TunstunApp> {
  late final TunnelService tunnelService;

  @override
  void initState() {
    super.initState();
    tunnelService = TunnelService();
  }

  @override
  void dispose() {
    // Perform cleanup in proper order
    debugPrint('Starting app disposal...');

    // Disconnect all tunnels when app is closed
    tunnelService.disconnectAllTunnels();
    debugPrint('All tunnels disconnected during app dispose');

    // Clean up system tray
    SystemTrayService().dispose();
    debugPrint('System tray disposed during app dispose');

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Tunstun',
          themeMode: themeService.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo.shade700,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo.shade700,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          home: TunnelListScreen(tunnelService: tunnelService),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
