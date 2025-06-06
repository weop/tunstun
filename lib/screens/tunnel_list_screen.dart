import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import '../models/tunnel_config.dart';
import '../services/tunnel_service.dart';
import '../services/system_tray_service.dart';
import '../services/traffic_monitor_service.dart';
import '../services/theme_service.dart';
import '../widgets/flutter_file_picker.dart';
import 'add_tunnel_screen.dart';
import 'edit_tunnel_screen.dart';
import 'config_manager_screen.dart';

// Custom Intent classes for keyboard shortcuts
class AddTunnelIntent extends Intent {
  const AddTunnelIntent();
}

class RefreshIntent extends Intent {
  const RefreshIntent();
}

class CloseAppIntent extends Intent {
  const CloseAppIntent();
}

class HideToTrayIntent extends Intent {
  const HideToTrayIntent();
}

class ConfigManagerIntent extends Intent {
  const ConfigManagerIntent();
}

class TunnelListScreen extends StatefulWidget {
  final TunnelService tunnelService;

  const TunnelListScreen({super.key, required this.tunnelService});

  @override
  State<TunnelListScreen> createState() => _TunnelListScreenState();
}

class _TunnelListScreenState extends State<TunnelListScreen>
    with WindowListener, TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late TrafficMonitorService _trafficMonitor;
  bool _isWindowVisible = true;
  Timer? _visibilityCheckTimer;

  @override
  void initState() {
    super.initState();
    widget.tunnelService.addListener(_onTunnelsChanged);
    _loadTunnels();

    // Initialize traffic monitoring service
    _trafficMonitor = TrafficMonitorService();
    _trafficMonitor.addListener(_onTrafficChanged);

    // Initialize animation controller for flowing dots
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Add window listener to handle close events and visibility changes
    windowManager.addListener(this);
    _startVisibilityMonitoring();

    // Add observer for app lifecycle changes (helps detect when hidden/shown)
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _visibilityCheckTimer?.cancel();
    widget.tunnelService.removeListener(_onTunnelsChanged);
    _trafficMonitor.removeListener(_onTrafficChanged);
    _trafficMonitor.dispose();
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTunnelsChanged() {
    if (mounted) {
      setState(() {});
      _updateTrafficMonitoring();
    }
  }

  void _onTrafficChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Start periodic visibility monitoring to detect window state changes
  void _startVisibilityMonitoring() {
    _visibilityCheckTimer = Timer.periodic(const Duration(seconds: 5), (
      _,
    ) async {
      try {
        bool isVisible = await windowManager.isVisible();
        if (isVisible != _isWindowVisible) {
          debugPrint(
            'Window visibility changed: $_isWindowVisible -> $isVisible',
          );
          _isWindowVisible = isVisible;
          _updateTrafficMonitoring();
        }
      } catch (e) {
        debugPrint('Error checking window visibility: $e');
      }
    });
  }

  /// Update traffic monitoring based on connected tunnels and window visibility
  void _updateTrafficMonitoring() {
    final connectedPorts = widget.tunnelService.tunnels
        .where((tunnel) => tunnel.isConnected)
        .map((tunnel) => tunnel.localPort)
        .toList();

    // Only monitor traffic when window is visible (not in system tray)
    if (connectedPorts.isNotEmpty && _isWindowVisible) {
      debugPrint(
        'Starting traffic monitoring for ports: $connectedPorts (window visible)',
      );
      _trafficMonitor.startMonitoring(connectedPorts);
    } else {
      if (connectedPorts.isNotEmpty && !_isWindowVisible) {
        debugPrint('Stopping traffic monitoring (window hidden/minimized)');
      }
      _trafficMonitor.stopMonitoring();
    }
  }

  /// Handle app lifecycle changes (helps detect when app is backgrounded)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('App resumed - enabling traffic monitoring');
        _isWindowVisible = true;
        _updateTrafficMonitoring();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        debugPrint('App backgrounded/hidden - disabling traffic monitoring');
        _isWindowVisible = false;
        _updateTrafficMonitoring();
        break;
      case AppLifecycleState.inactive:
        // Window is inactive but might still be visible
        break;
    }
  }

  /// Handle window events like minimize, hide, etc.
  @override
  void onWindowEvent(String eventName) {
    super.onWindowEvent(eventName);
    debugPrint('Window event: $eventName');

    switch (eventName) {
      case 'hide':
      case 'minimize':
        debugPrint('Window hidden/minimized - pausing traffic monitoring');
        _isWindowVisible = false;
        _updateTrafficMonitoring();
        break;
      case 'show':
      case 'restore':
        debugPrint('Window shown/restored - resuming traffic monitoring');
        _isWindowVisible = true;
        _updateTrafficMonitoring();
        break;
    }
  }

  Future<void> _loadTunnels() async {
    await widget.tunnelService.loadTunnels();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            const AddTunnelIntent(),
        LogicalKeySet(LogicalKeyboardKey.f5): const RefreshIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR):
            const RefreshIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyQ):
            const CloseAppIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyH):
            const HideToTrayIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyO):
            const ConfigManagerIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          AddTunnelIntent: CallbackAction<AddTunnelIntent>(
            onInvoke: (AddTunnelIntent intent) => _addTunnel(),
          ),
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (RefreshIntent intent) => _loadTunnels(),
          ),
          CloseAppIntent: CallbackAction<CloseAppIntent>(
            onInvoke: (CloseAppIntent intent) => _handleAppClose(),
          ),
          HideToTrayIntent: CallbackAction<HideToTrayIntent>(
            onInvoke: (HideToTrayIntent intent) => _hideToTray(),
          ),
          ConfigManagerIntent: CallbackAction<ConfigManagerIntent>(
            onInvoke: (ConfigManagerIntent intent) => _openConfigManager(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: GestureDetector(
                behavior: HitTestBehavior
                    .opaque, // Ensures the GestureDetector is tappable in its entire area
                onPanStart: (details) {
                  // Added for dragging the window
                  windowManager.startDragging();
                },
                onDoubleTap: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
                child: Container(
                  // This Container helps define the tappable area and center the text
                  width: double
                      .infinity, // Expand to fill the horizontal space allocated by AppBar for the title
                  alignment: Alignment
                      .centerLeft, // Center the Text widget within this Container
                  child: Text(
                    'tunstun',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              centerTitle: true,
              automaticallyImplyLeading: false, // Remove back button
              actions: [
                // Dark mode toggle button
                Consumer<ThemeService>(
                  builder: (context, themeService, child) {
                    IconData iconData;
                    String tooltip;

                    if (themeService.themeMode == ThemeMode.light) {
                      iconData = Icons.dark_mode_outlined;
                      tooltip = 'Switch to Dark Mode';
                    } else if (themeService.themeMode == ThemeMode.dark) {
                      iconData = Icons.light_mode_outlined;
                      tooltip = 'Switch to System Mode';
                    } else {
                      iconData = Icons.brightness_auto_outlined;
                      tooltip = 'Switch to Light Mode';
                    }

                    return IconButton(
                      icon: Icon(iconData),
                      onPressed: () {
                        themeService.toggleTheme();
                      },
                      tooltip: tooltip,
                    );
                  },
                ),
                // Configuration management menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.folder),
                  tooltip: 'Configuration Files',
                  onSelected: _handleConfigMenu,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'manager',
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Configuration Manager'),
                        subtitle: Text('Ctrl+O'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'new',
                      child: ListTile(
                        leading: Icon(Icons.add),
                        title: Text('New Configuration'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'open',
                      child: ListTile(
                        leading: Icon(Icons.folder_open),
                        title: Text('Open Configuration'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'save',
                      child: ListTile(
                        leading: Icon(Icons.save),
                        title: Text('Save As...'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: ListTile(
                        leading: Icon(Icons.file_download),
                        title: Text('Export Current'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                // Window control buttons for desktop
                IconButton(
                  icon: const Icon(Icons.keyboard),
                  onPressed: _showKeyboardShortcuts,
                  tooltip: 'Keyboard Shortcuts',
                ),
                IconButton(
                  icon: const Icon(Icons.minimize),
                  onPressed: _hideToTray,
                  tooltip: 'Hide to System Tray',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _handleAppClose,
                  tooltip: 'Close Application (Ctrl+Q)',
                ),
              ],
            ),
            body: Column(
              children: [
                // Button bar at the top
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _addTunnel,
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Add Tunnel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _connectAllTunnels,
                          icon: const Icon(Icons.play_circle_fill),
                          label: const Text('Connect All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _disconnectAllTunnels,
                          icon: const Icon(Icons.stop_circle),
                          label: const Text('Disconnect All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          onPressed: _loadTunnels,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh (F5)',
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.tunnelService.tunnels.length} tunnel${widget.tunnelService.tunnels.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Main content area
                Expanded(
                  child: widget.tunnelService.tunnels.isEmpty
                      ? _buildEmptyState()
                      : _buildTunnelList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.router_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No SSH Tunnels',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first tunnel to get started',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addTunnel,
            icon: const Icon(Icons.add),
            label: const Text('Add Tunnel'),
          ),
        ],
      ),
    );
  }

  Widget _buildTunnelList() {
    return RefreshIndicator(
      onRefresh: _loadTunnels,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: widget.tunnelService.tunnels.length,
        itemBuilder: (context, index) {
          final tunnel = widget.tunnelService.tunnels[index];
          return _buildTunnelCard(tunnel);
        },
      ),
    );
  }

  Widget _buildTunnelCard(TunnelConfig tunnel) {
    return Card(
      color: Theme.of(context).brightness == Brightness.light
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : Theme.of(context).colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tunnel.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _toggleTunnel(tunnel),
                            icon: Icon(
                              tunnel.isConnected
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              color: tunnel.isConnected
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            tooltip: tunnel.isConnected
                                ? 'Disconnect'
                                : 'Connect',
                          ),
                          if (tunnel.isConnected) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () =>
                                  _openLocalEndpoint(tunnel.localPort),
                              icon: const Icon(Icons.link, color: Colors.green),
                              tooltip: 'Open in Browser',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Animated tunnel connection display
                      _buildTunnelConnectionRow(tunnel),
                      // Port status indicator with detailed information
                      if (!tunnel.isConnected)
                        FutureBuilder(
                          future: widget.tunnelService.checkPortStatus(
                            tunnel.localPort,
                          ),
                          builder: (context, AsyncSnapshot snapshot) {
                            if (snapshot.hasData &&
                                !snapshot.data.isAvailable) {
                              final portStatus = snapshot.data;
                              final isSSHTunnel =
                                  portStatus.hasExistingSSHTunnel;

                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSSHTunnel
                                          ? Icons.warning_amber
                                          : Icons.warning,
                                      size: 16,
                                      color: isSSHTunnel
                                          ? Colors.red
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        isSSHTunnel
                                            ? 'Port ${tunnel.localPort} has existing SSH tunnel (PID: ${portStatus.existingTunnel.pid})'
                                            : 'Port ${tunnel.localPort} is in use',
                                        style: TextStyle(
                                          color: isSSHTunnel
                                              ? Colors.red
                                              : Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getTunnelStatusColor(tunnel),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _getTunnelStatusText(tunnel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.tunnelService.isConnecting(tunnel.id))
                          // Show cancel button when connecting
                          IconButton(
                            onPressed: () => _cancelConnection(tunnel),
                            icon: const Icon(
                              Icons.cancel,
                              color: Colors.orange,
                            ),
                            tooltip: 'Cancel Connection',
                          )
                        else
                          // Show connect/disconnect button
                          IconButton(
                            onPressed: () => _toggleTunnel(tunnel),
                            icon: Icon(
                              tunnel.isConnected
                                  ? Icons.stop_circle_rounded
                                  : Icons.play_circle_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            tooltip: tunnel.isConnected
                                ? 'Disconnect'
                                : 'Connect',
                          ),
                        IconButton(
                          onPressed: () => _editTunnel(tunnel),
                          icon: Icon(
                            Icons.edit,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () => _deleteTunnel(tunnel),
                          icon: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // const Divider(height: 16),
            // Container(
            //   padding: const EdgeInsets.all(8),
            //   decoration: BoxDecoration(
            //     color: Colors.green.shade50,
            //     borderRadius: BorderRadius.circular(4),
            //   ),
            //   child: Row(
            //     children: [
            //       const Icon(Icons.terminal, size: 16, color: Colors.black54),
            //       const SizedBox(width: 8),
            //       Expanded(
            //         child: Text(
            //           'ssh -N -L ${tunnel.localPort}:${tunnel.remoteHost}:${tunnel.remotePort} ${tunnel.connectionString}',
            //           style: const TextStyle(
            //             fontSize: 12,
            //             color: Colors.black54,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  // Build an animated connection display for the tunnel
  Widget _buildTunnelConnectionRow(TunnelConfig tunnel) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Local endpoint (clickable when connected)
          GestureDetector(
            onTap: tunnel.isConnected
                ? () => _openLocalEndpoint(tunnel.localPort)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tunnel.isConnected
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                border: Border.all(
                  color: tunnel.isConnected ? Colors.green : Colors.grey,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'localhost:${tunnel.localPort}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: tunnel.isConnected
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // Animated connection line
          Expanded(
            child: SizedBox(
              height: 24,
              child: tunnel.isConnected
                  ? _buildAnimatedConnectionLine(tunnel)
                  : _buildDisconnectedLine(),
            ),
          ),

          // Remote endpoint (clickable)
          GestureDetector(
            onTap: () => _openRemoteEndpoint(tunnel.remoteEndpoint),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue, width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tunnel.remoteEndpoint,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build animated connection line for connected tunnels
  Widget _buildAnimatedConnectionLine(TunnelConfig tunnel) {
    // Get traffic statistics for this tunnel's local port
    final trafficIntensity = _trafficMonitor.getAnimationIntensity(
      tunnel.localPort,
    );
    final hasActivity = _trafficMonitor.hasRecentActivity(tunnel.localPort);

    return Stack(
      children: [
        // Base line with traffic-responsive gradient
        Positioned.fill(
          child: Center(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasActivity
                      ? [Colors.green.shade400, Colors.blue.shade400]
                      : [Colors.green.shade300, Colors.blue.shade300],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ),
        // Animated flowing dots with traffic-based intensity
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                painter: FlowingDotsPainter(
                  progress: _animationController.value,
                  color: Theme.of(context).colorScheme.surface,
                  intensity: trafficIntensity,
                  hasActivity: hasActivity,
                ),
              );
            },
          ),
        ),
        // Arrow indicators with activity-based styling
        Positioned.fill(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(
                Icons.arrow_forward,
                size: hasActivity ? 18 : 16,
                color: hasActivity
                    ? Colors.green.shade700
                    : Colors.green.shade600,
              ),
              Icon(
                Icons.arrow_forward,
                size: hasActivity ? 18 : 16,
                color: hasActivity
                    ? Colors.blue.shade700
                    : Colors.blue.shade600,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build disconnected line
  Widget _buildDisconnectedLine() {
    return Center(
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(
              Icons.link_off,
              size: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  // Get the appropriate color for tunnel status
  Color _getTunnelStatusColor(TunnelConfig tunnel) {
    if (widget.tunnelService.isConnecting(tunnel.id)) {
      return Colors.orange.shade600;
    } else if (widget.tunnelService.hasActiveProcess(tunnel.id)) {
      return Colors.green.shade600;
    } else if (tunnel.isConnected) {
      // Marked as connected but no active process - show warning color
      return Colors.red.shade600;
    } else {
      return Theme.of(context).colorScheme.outline;
    }
  }

  // Get the appropriate text for tunnel status
  String _getTunnelStatusText(TunnelConfig tunnel) {
    if (widget.tunnelService.isConnecting(tunnel.id)) {
      return 'Connecting...';
    } else if (widget.tunnelService.hasActiveProcess(tunnel.id)) {
      return 'Connected';
    } else if (tunnel.isConnected) {
      // Marked as connected but no active process
      return 'Stale';
    } else {
      return 'Disconnected';
    }
  }

  void _addTunnel() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AddTunnelScreen(tunnelService: widget.tunnelService),
      ),
    );
  }

  void _editTunnel(TunnelConfig tunnel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditTunnelScreen(
          tunnelService: widget.tunnelService,
          tunnel: tunnel,
        ),
      ),
    );
  }

  Future<void> _toggleTunnel(TunnelConfig tunnel) async {
    try {
      if (tunnel.isConnected) {
        // Check if this is a stale connection (marked connected but no active process)
        if (!widget.tunnelService.hasActiveProcess(tunnel.id)) {
          // This is a stale connection, just mark it as disconnected
          debugPrint('Fixing stale connection for tunnel: ${tunnel.name}');
          tunnel.isConnected = false;
          await widget.tunnelService.saveTunnels();
          setState(() {});

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Fixed stale connection status for: ${tunnel.name}',
                ),
                backgroundColor: Colors.blue,
              ),
            );
          }
          return;
        }

        // Normal disconnection for actively tracked tunnels
        await widget.tunnelService.disconnectTunnel(tunnel.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Disconnected tunnel: ${tunnel.name}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        final result = await widget.tunnelService.connectTunnel(tunnel.id);
        if (mounted) {
          if (result.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connected tunnel: ${tunnel.name}'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // Check if the error is due to an existing SSH tunnel
            if (result.errorMessage?.contains('existing SSH tunnel') == true) {
              await _handleExistingTunnelConflict(tunnel, result.errorMessage!);
            } else {
              // Show detailed error message for other errors
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.errorMessage ??
                        'Failed to connect tunnel: ${tunnel.name}',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(
                    seconds: 6,
                  ), // Longer duration for error messages
                  action: SnackBarAction(
                    label: 'Dismiss',
                    textColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  ),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _handleExistingTunnelConflict(
    TunnelConfig tunnel,
    String errorMessage,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Port Conflict Detected'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cannot connect "${tunnel.name}" because port ${tunnel.localPort} is already in use by an existing SSH tunnel.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  errorMessage,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'What would you like to do?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('disconnect'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Disconnect Existing & Connect'),
          ),
        ],
      ),
    );

    if (action == 'disconnect') {
      await _disconnectExistingAndConnect(tunnel);
    }
  }

  Future<void> _disconnectExistingAndConnect(TunnelConfig tunnel) async {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text('Disconnecting existing tunnel and connecting...'),
            ],
          ),
          duration: Duration(seconds: 10),
          backgroundColor: Colors.blue,
        ),
      );
    }

    try {
      final result = await widget.tunnelService.disconnectExistingAndConnect(
        tunnel.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully connected tunnel: ${tunnel.name}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage ??
                    'Failed to disconnect existing tunnel and connect',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _deleteTunnel(TunnelConfig tunnel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Tunnel',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.00),
        ),
        content: Text('Are you sure you want to delete "${tunnel.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.tunnelService.removeTunnel(tunnel.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted tunnel: ${tunnel.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting tunnel: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _cancelConnection(TunnelConfig tunnel) {
    widget.tunnelService.cancelConnection(tunnel.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancelled connection to: ${tunnel.name}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Open the remote endpoint in a web browser
  Future<void> _openRemoteEndpoint(String remoteEndpoint) async {
    if (!mounted) return;

    try {
      // Create the URL for the local tunnel endpoint
      final localUrl =
          'http://127.0.0.1:${_extractPortFromEndpoint(remoteEndpoint)}';
      final uri = Uri.parse(localUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening $localUrl in browser'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open $localUrl - no browser available'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening URL: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Open the local endpoint in a web browser
  Future<void> _openLocalEndpoint(int localPort) async {
    if (!mounted) return;

    try {
      final localUrl = 'http://127.0.0.1:$localPort';
      final uri = Uri.parse(localUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening $localUrl in browser'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open $localUrl - no browser available'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening URL: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Extract the local port from a tunnel to create the correct local URL
  int _extractPortFromEndpoint(String remoteEndpoint) {
    // Find the tunnel that matches this remote endpoint
    final tunnel = widget.tunnelService.tunnels.firstWhere(
      (t) => t.remoteEndpoint == remoteEndpoint,
      orElse: () => widget.tunnelService.tunnels.first,
    );
    return tunnel.localPort;
  }

  // Handle window close event
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await _handleAppClose();
    }
  }

  // Handle window focus/blur events to detect when window becomes visible/invisible
  @override
  void onWindowFocus() {
    debugPrint('Window focused - resuming traffic monitoring');
    _isWindowVisible = true;
    _updateTrafficMonitoring();
  }

  @override
  void onWindowBlur() {
    debugPrint('Window lost focus - traffic monitoring may pause');
    // Don't immediately pause on blur as window might still be visible
    // Only pause on explicit hide/minimize
  }

  @override
  void onWindowMinimize() {
    debugPrint('Window minimized - pausing traffic monitoring');
    _isWindowVisible = false;
    _updateTrafficMonitoring();
  }

  @override
  void onWindowRestore() {
    debugPrint('Window restored - resuming traffic monitoring');
    _isWindowVisible = true;
    _updateTrafficMonitoring();
  }

  Future<void> _handleAppClose() async {
    // Show confirmation if there are active tunnels
    final activeTunnels = widget.tunnelService.tunnels
        .where((tunnel) => tunnel.isConnected)
        .toList();

    if (activeTunnels.isNotEmpty) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Close Application'),
          content: Text(
            'You have ${activeTunnels.length} active tunnel(s). What would you like to do?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Cancel'),
            ),
            if (SystemTrayService().isAvailable)
              TextButton(
                onPressed: () => Navigator.of(context).pop('hide'),
                child: const Text('Hide to Tray'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('close'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Close & Disconnect'),
            ),
          ],
        ),
      );

      switch (result) {
        case 'hide':
          await _hideToTray();
          break;
        case 'close':
          // Disconnect all tunnels before closing
          for (final tunnel in activeTunnels) {
            await widget.tunnelService.disconnectTunnel(tunnel.id);
          }
          await _gracefulClose();
          break;
        // 'cancel' or null - do nothing
      }
    } else {
      // No active tunnels, show simple close/hide dialog
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Close Application'),
          content: const Text('How would you like to close Tunstun?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Cancel'),
            ),
            if (SystemTrayService().isAvailable)
              TextButton(
                onPressed: () => Navigator.of(context).pop('hide'),
                child: const Text('Hide to Tray'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('close'),
              child: const Text('Close'),
            ),
          ],
        ),
      );

      switch (result) {
        case 'hide':
          await _hideToTray();
          break;
        case 'close':
          await _gracefulClose();
          break;
        // 'cancel' or null - do nothing
      }
    }
  }

  Future<void> _gracefulClose() async {
    try {
      debugPrint('Starting graceful shutdown sequence...');

      // 1. Disconnect all active tunnels first
      final tunnelService = TunnelService();
      await tunnelService.disconnectAllTunnels();
      debugPrint('All tunnels disconnected');

      // 2. Clean up system tray
      await SystemTrayService().dispose();
      debugPrint('System tray cleaned up');

      // 3. Remove window listener
      windowManager.removeListener(this);
      debugPrint('Window listener removed');

      // 4. Hide window before closing to avoid visual glitches
      await windowManager.hide();
      debugPrint('Window hidden');

      // 5. Allow some time for cleanup
      await Future.delayed(const Duration(milliseconds: 200));

      // 6. Close the window gracefully
      await windowManager.close();
      debugPrint('Window closed gracefully');
    } catch (e) {
      debugPrint('Error during graceful close: $e');
      // Fallback to destroy if close fails
      try {
        await windowManager.destroy();
        debugPrint('Window destroyed as fallback');
      } catch (e2) {
        debugPrint('Error during fallback destroy: $e2');
      }
    }
  }

  void _showKeyboardShortcuts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard),
            SizedBox(width: 8),
            Text('Keyboard Shortcuts'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShortcutRow('Ctrl + N', 'Add new tunnel'),
              _buildShortcutRow('F5 / Ctrl + R', 'Refresh tunnel list'),
              _buildShortcutRow('Ctrl + O', 'Open Configuration Manager'),
              if (SystemTrayService().isAvailable)
                _buildShortcutRow('Ctrl + H', 'Hide to system tray'),
              _buildShortcutRow('Ctrl + Q', 'Close application'),
              const SizedBox(height: 16),
              const Text(
                'Tip: Focus must be on the main window for shortcuts to work.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String shortcut, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }

  Future<void> _hideToTray() async {
    debugPrint('Hiding to system tray - pausing traffic monitoring');
    _isWindowVisible = false;
    _updateTrafficMonitoring();

    await SystemTrayService().hideToTray();

    if (mounted) {
      final systemTrayService = SystemTrayService();
      final message = systemTrayService.isAvailable
          ? 'Tunstun minimized to system tray'
          : 'Tunstun minimized (system tray not available)';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: systemTrayService.isAvailable ? 2 : 4),
          backgroundColor: systemTrayService.isAvailable ? null : Colors.orange,
        ),
      );
    }
  }

  Future<void> _connectAllTunnels() async {
    final disconnectedTunnels = widget.tunnelService.tunnels
        .where(
          (tunnel) =>
              !tunnel.isConnected &&
              !widget.tunnelService.isConnecting(tunnel.id),
        )
        .toList();

    if (disconnectedTunnels.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No disconnected tunnels to connect'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show progress indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Connecting ${disconnectedTunnels.length} tunnel${disconnectedTunnels.length == 1 ? '' : 's'}...',
              ),
            ],
          ),
          duration: const Duration(seconds: 30),
          backgroundColor: Colors.blue,
        ),
      );
    }

    try {
      final results = await widget.tunnelService.connectAllTunnels();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        int successCount = 0;
        int failureCount = 0;
        List<String> failedTunnels = [];

        for (final entry in results.entries) {
          final tunnelId = entry.key;
          final result = entry.value;
          final tunnel = widget.tunnelService.tunnels.firstWhere(
            (t) => t.id == tunnelId,
          );

          if (result.success) {
            successCount++;
          } else {
            failureCount++;
            failedTunnels.add(tunnel.name);
          }
        }

        // Show summary of results
        if (failureCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully connected all $successCount tunnel${successCount == 1 ? '' : 's'}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else if (successCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to connect all $failureCount tunnel${failureCount == 1 ? '' : 's'}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Connected $successCount tunnel${successCount == 1 ? '' : 's'}, failed $failureCount',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting tunnels: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _disconnectAllTunnels() async {
    final connectedTunnels = widget.tunnelService.tunnels
        .where((tunnel) => tunnel.isConnected)
        .toList();

    if (connectedTunnels.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No connected tunnels to disconnect'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Disconnect All Tunnels',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
        ),
        content: Text(
          'Are you sure you want to disconnect all ${connectedTunnels.length} connected tunnel${connectedTunnels.length == 1 ? '' : 's'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Disconnect All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Disconnecting ${connectedTunnels.length} tunnel${connectedTunnels.length == 1 ? '' : 's'}...',
              ),
            ],
          ),
          duration: const Duration(seconds: 10),
          backgroundColor: Colors.orange,
        ),
      );
    }

    try {
      await widget.tunnelService.disconnectAllTunnels();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Disconnected all ${connectedTunnels.length} tunnel${connectedTunnels.length == 1 ? '' : 's'}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disconnecting tunnels: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _openConfigManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ConfigManagerScreen(tunnelService: widget.tunnelService),
      ),
    );
  }

  void _handleConfigMenu(String value) async {
    // Handle configuration menu selection
    switch (value) {
      case 'manager':
        _openConfigManager();
        break;
      case 'new':
        await _newConfiguration();
        break;
      case 'open':
        await _openConfiguration();
        break;
      case 'save':
        await _saveConfiguration();
        break;
      case 'export':
        await _exportConfiguration();
        break;
    }
  }

  Future<void> _newConfiguration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Configuration'),
        content: const Text(
          'This will clear all current tunnels and create a new configuration. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Create New'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.tunnelService.newConfiguration();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New configuration created'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating new configuration: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _openConfiguration() async {
    try {
      final filePath = await FlutterFilePicker.pickFile(
        context: context,
        title: 'Open Tunnel Configuration',
        allowedExtensions: ['yaml', 'yml'],
      );

      if (filePath != null) {
        final success = await widget.tunnelService.loadFromFile(filePath);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Configuration loaded: ${filePath.split('/').last}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load configuration file'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _saveConfiguration() async {
    try {
      final filePath = await FlutterFilePicker.saveFile(
        context: context,
        title: 'Save Tunnel Configuration',
        fileName: 'tunnels.yaml',
        allowedExtensions: ['yaml', 'yml'],
      );

      if (filePath != null) {
        final success = await widget.tunnelService.saveToFile(filePath);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Configuration saved: ${filePath.split('/').last}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save configuration'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _exportConfiguration() async {
    try {
      final filePath = await FlutterFilePicker.saveFile(
        context: context,
        title: 'Export Tunnel Configuration',
        fileName: 'exported_tunnels.yaml',
        allowedExtensions: ['yaml', 'yml'],
      );

      if (filePath != null) {
        final success = await widget.tunnelService.exportToFile(filePath);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Configuration exported: ${filePath.split('/').last}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to export configuration'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting configuration: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// Custom painter for animated flowing dots with traffic-based intensity
class FlowingDotsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double intensity; // Traffic-based animation intensity (0.1 to 1.0)
  final bool hasActivity; // Whether there's recent traffic activity

  FlowingDotsPainter({
    required this.progress,
    required this.color,
    this.intensity = 0.5,
    this.hasActivity = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: hasActivity ? 1.0 : 0.7)
      ..style = PaintingStyle.fill;

    // Adjust dot count and speed based on traffic intensity
    final dotCount = hasActivity ? (4 + (intensity * 4).round()) : 4;
    final totalWidth = size.width;
    final baseRadius = 3.0;
    final radius =
        baseRadius * (0.7 + intensity * 0.3); // Scale dots with traffic

    for (int i = 0; i < dotCount; i++) {
      // Calculate base position across the width
      // Speed varies with intensity: higher traffic = faster dots
      final speedMultiplier = 0.5 + intensity * 1.5;
      final baseProgress = (progress * speedMultiplier + (i / dotCount)) % 1.0;
      final dx = baseProgress * totalWidth;
      final dy = size.height / 2;

      // Add a subtle wave effect, more pronounced with higher traffic
      final waveOffset =
          (progress * speedMultiplier * 2 * pi * 2 + i * pi / 2) % (2 * pi);
      final waveAmplitude = hasActivity ? (1.5 + intensity * 1.0) : 1.5;
      final dotY = dy + waveAmplitude * sin(waveOffset);

      // Only draw dots that are within the visible area
      if (dx >= radius && dx <= totalWidth - radius) {
        // Add a glow effect for high traffic
        if (hasActivity && intensity > 0.7) {
          final glowPaint = Paint()
            ..color = color.withValues(alpha: 0.3)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(dx, dotY), radius * 1.5, glowPaint);
        }

        canvas.drawCircle(Offset(dx, dotY), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is FlowingDotsPainter) {
      return oldDelegate.progress != progress ||
          oldDelegate.intensity != intensity ||
          oldDelegate.hasActivity != hasActivity;
    }
    return true;
  }
}
