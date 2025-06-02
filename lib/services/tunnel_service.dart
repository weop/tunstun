import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import '../models/tunnel_config.dart';
import 'system_tray_service.dart';

class TunnelConnectionResult {
  final bool success;
  final String? errorMessage;

  TunnelConnectionResult({required this.success, this.errorMessage});
}

class ExistingTunnelInfo {
  final int pid;
  final String commandLine;
  final int localPort;

  ExistingTunnelInfo({
    required this.pid,
    required this.commandLine,
    required this.localPort,
  });
}

class PortStatus {
  final bool isAvailable;
  final ExistingTunnelInfo? existingTunnel;

  PortStatus({required this.isAvailable, this.existingTunnel});

  bool get hasExistingSSHTunnel => existingTunnel != null;
}

class TunnelService extends ChangeNotifier {
  final List<TunnelConfig> _tunnels = [];
  final Map<String, Process> _activeProcesses = {};
  final Map<String, Process> _pendingConnections = {};
  String? _currentConfigurationFile; // Track the currently loaded file

  List<TunnelConfig> get tunnels => List.unmodifiable(_tunnels);
  String? get currentConfigurationFile => _currentConfigurationFile;

  bool isConnecting(String tunnelId) =>
      _pendingConnections.containsKey(tunnelId);

  // Check if a tunnel has an active tracked SSH process
  bool hasActiveProcess(String tunnelId) {
    return _activeProcesses.containsKey(tunnelId);
  }

  // Get the status of a tunnel (connected, connecting, or disconnected)
  String getTunnelStatus(String tunnelId) {
    if (isConnecting(tunnelId)) {
      return 'connecting';
    } else if (hasActiveProcess(tunnelId)) {
      return 'connected';
    } else {
      final tunnel = _tunnels.firstWhere((t) => t.id == tunnelId);
      return tunnel.isConnected ? 'connected-untracked' : 'disconnected';
    }
  }

  Future<void> loadTunnels() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final yamlData = loadYaml(content);

        if (yamlData is Map && yamlData['tunnels'] is List) {
          _tunnels.clear();
          for (final tunnelData in yamlData['tunnels']) {
            if (tunnelData is Map) {
              final tunnel = TunnelConfig.fromJson(
                Map<String, dynamic>.from(tunnelData),
              );
              _tunnels.add(tunnel);
            }
          }

          // Validate connection states - check if SSH processes are actually running
          await _validateTunnelStates();

          notifyListeners();
          _updateSystemTray();
        }
      }
    } catch (e) {
      debugPrint('Error loading tunnels: $e');
    }
  }

  Future<void> saveTunnels() async {
    try {
      final file = await _getConfigFile();
      final data = {
        'tunnels': _tunnels.map((tunnel) => tunnel.toJson()).toList(),
      };

      final yamlString = _convertToYaml(data);
      await file.writeAsString(yamlString);
    } catch (e) {
      debugPrint('Error saving tunnels: $e');
    }
  }

  Future<void> addTunnel(TunnelConfig tunnel) async {
    _tunnels.add(tunnel);
    await saveTunnels();
    notifyListeners();
    _updateSystemTray();
  }

  Future<void> updateTunnel(TunnelConfig updatedTunnel) async {
    // Find the existing tunnel by ID
    final index = _tunnels.indexWhere(
      (tunnel) => tunnel.id == updatedTunnel.id,
    );
    if (index != -1) {
      // Disconnect tunnel if it's connected before updating
      if (_activeProcesses.containsKey(updatedTunnel.id)) {
        await disconnectTunnel(updatedTunnel.id);
      }

      // Update the tunnel configuration
      _tunnels[index] = updatedTunnel;
      await saveTunnels();
      notifyListeners();
      _updateSystemTray();
    }
  }

  Future<void> removeTunnel(String tunnelId) async {
    // Disconnect tunnel if connected
    if (_activeProcesses.containsKey(tunnelId)) {
      await disconnectTunnel(tunnelId);
    }

    _tunnels.removeWhere((tunnel) => tunnel.id == tunnelId);
    await saveTunnels();
    notifyListeners();
    _updateSystemTray();
  }

  Future<TunnelConnectionResult> connectTunnel(String tunnelId) async {
    final tunnel = _tunnels.firstWhere((t) => t.id == tunnelId);

    try {
      // Mark as connecting with placeholder
      final placeholderProcess = await Process.start('echo', ['connecting']);
      _pendingConnections[tunnelId] = placeholderProcess;
      notifyListeners();

      // Check if port is already in use and provide detailed information
      final portStatus = await checkPortStatus(tunnel.localPort);
      if (!portStatus.isAvailable) {
        _pendingConnections.remove(tunnelId);
        notifyListeners();

        String errorMessage;
        if (portStatus.hasExistingSSHTunnel) {
          final existing = portStatus.existingTunnel!;
          errorMessage =
              'Port ${tunnel.localPort} is already in use by an existing SSH tunnel (PID: ${existing.pid}).\n\n'
              'Command: ${existing.commandLine.trim()}\n\n'
              'You can:\n'
              '• Use the "Disconnect Existing" option to kill the existing tunnel\n'
              '• Choose a different local port\n'
              '• Manually kill the process: kill ${existing.pid}';
        } else {
          errorMessage =
              'Port ${tunnel.localPort} is already in use by another application.\n\n'
              'Please choose a different local port or close the application using this port.';
        }

        debugPrint(errorMessage);
        return TunnelConnectionResult(
          success: false,
          errorMessage: errorMessage,
        );
      }

      // Check if SSH host is localhost - use direct port forwarding
      Process process;
      if (tunnel.sshHost.toLowerCase() == 'localhost' ||
          tunnel.sshHost == '127.0.0.1') {
        debugPrint(
          'SSH host is localhost - using direct port forwarding: ${tunnel.localPort} -> ${tunnel.remoteHost}:${tunnel.remotePort}',
        );

        // Check if connection was cancelled during tests
        if (!_pendingConnections.containsKey(tunnelId)) {
          return TunnelConnectionResult(
            success: false,
            errorMessage: 'Connection cancelled',
          );
        }

        // Use socat for direct port forwarding to the actual remote host
        final forwardCommand = [
          'socat',
          'TCP-LISTEN:${tunnel.localPort},fork,reuseaddr',
          'TCP:${tunnel.remoteHost}:${tunnel.remotePort}',
        ];

        debugPrint(
          'Executing direct forwarding command: ${forwardCommand.join(' ')}',
        );

        process = await Process.start(
          forwardCommand.first,
          forwardCommand.skip(1).toList(),
          mode: ProcessStartMode.normal,
        );
      } else {
        // Regular SSH tunnel for remote hosts
        // Check if SSH host is reachable (basic connectivity test)
        final pingResult = await _testSSHConnection(tunnel);
        if (!pingResult.success) {
          _pendingConnections.remove(tunnelId);
          notifyListeners();
          return pingResult;
        }

        // Check if connection was cancelled during tests
        if (!_pendingConnections.containsKey(tunnelId)) {
          return TunnelConnectionResult(
            success: false,
            errorMessage: 'Connection cancelled',
          );
        }

        // Create SSH tunnel command
        final sshCommand = [
          'ssh',
          '-N', // Don't execute remote command
          '-o', 'ConnectTimeout=10', // 10 second timeout
          '-o',
          'StrictHostKeyChecking=no', // Don't prompt for host key verification
          '-L', '${tunnel.localPort}:${tunnel.remoteHost}:${tunnel.remotePort}',
          tunnel.connectionString,
        ];

        debugPrint('Executing SSH command: ${sshCommand.join(' ')}');

        process = await Process.start(
          sshCommand.first,
          sshCommand.skip(1).toList(),
          mode: ProcessStartMode.normal,
        );
      }

      // Store the actual process in pending connections
      _pendingConnections[tunnelId] = process;

      // Wait a moment to see if the process starts successfully
      await Future.delayed(Duration(milliseconds: 500));

      // Check if connection was cancelled while starting
      if (!_pendingConnections.containsKey(tunnelId)) {
        try {
          process.kill();
        } catch (e) {
          debugPrint('Error killing process during cancellation check: $e');
        }
        return TunnelConnectionResult(
          success: false,
          errorMessage: 'Connection cancelled',
        );
      }

      // Move from pending to active
      _pendingConnections.remove(tunnelId);
      _activeProcesses[tunnelId] = process;
      tunnel.isConnected = true;

      // Listen for process exit
      process.exitCode
          .then((exitCode) {
            if (_activeProcesses.containsKey(tunnelId)) {
              _activeProcesses.remove(tunnelId);
              tunnel.isConnected = false;
              debugPrint('SSH tunnel process exited with code: $exitCode');
              notifyListeners();
              _updateSystemTray();
            }
          })
          .catchError((error) {
            debugPrint('Error monitoring process exit code: $error');
            // Clean up if there's an error
            if (_activeProcesses.containsKey(tunnelId)) {
              _activeProcesses.remove(tunnelId);
              tunnel.isConnected = false;
              notifyListeners();
              _updateSystemTray();
            }
          });

      await saveTunnels();
      notifyListeners();
      _updateSystemTray();
      return TunnelConnectionResult(success: true);
    } catch (e) {
      _pendingConnections.remove(tunnelId);
      notifyListeners();
      final errorMessage = 'Failed to establish SSH tunnel: $e';
      debugPrint(errorMessage);
      return TunnelConnectionResult(success: false, errorMessage: errorMessage);
    }
  }

  void cancelConnection(String tunnelId) {
    if (_pendingConnections.containsKey(tunnelId)) {
      final process = _pendingConnections[tunnelId]!;
      try {
        process.kill();
      } catch (e) {
        debugPrint('Error killing process during cancellation: $e');
      }
      _pendingConnections.remove(tunnelId);
      debugPrint('Cancelled connection attempt for tunnel: $tunnelId');
      notifyListeners();
    }
  }

  Future<void> disconnectTunnel(String tunnelId) async {
    final process = _activeProcesses[tunnelId];
    if (process != null) {
      try {
        process.kill();
      } catch (e) {
        debugPrint('Error killing process during disconnection: $e');
      }
      _activeProcesses.remove(tunnelId);

      final tunnel = _tunnels.firstWhere((t) => t.id == tunnelId);
      tunnel.isConnected = false;

      await saveTunnels();
      notifyListeners();
      _updateSystemTray();
    }
  }

  Future<void> disconnectAllTunnels() async {
    for (final tunnelId in _activeProcesses.keys.toList()) {
      await disconnectTunnel(tunnelId);
    }
    _updateSystemTray();
  }

  // Connect all disconnected tunnels
  Future<Map<String, TunnelConnectionResult>> connectAllTunnels() async {
    final results = <String, TunnelConnectionResult>{};

    // Get all disconnected tunnels
    final disconnectedTunnels = _tunnels
        .where((tunnel) => !tunnel.isConnected && !isConnecting(tunnel.id))
        .toList();

    if (disconnectedTunnels.isEmpty) {
      debugPrint('No disconnected tunnels to connect');
      return results;
    }

    debugPrint('Connecting ${disconnectedTunnels.length} tunnels...');

    // Connect each tunnel sequentially to avoid port conflicts
    for (final tunnel in disconnectedTunnels) {
      try {
        final result = await connectTunnel(tunnel.id);
        results[tunnel.id] = result;

        if (result.success) {
          debugPrint('✓ Connected tunnel: ${tunnel.name}');
        } else {
          debugPrint(
            '✗ Failed to connect tunnel: ${tunnel.name} - ${result.errorMessage}',
          );
        }

        // Small delay between connections to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        results[tunnel.id] = TunnelConnectionResult(
          success: false,
          errorMessage: 'Error connecting tunnel: $e',
        );
        debugPrint('✗ Error connecting tunnel: ${tunnel.name} - $e');
      }
    }

    return results;
  }

  // Disconnect an existing SSH tunnel and connect a new one
  Future<TunnelConnectionResult> disconnectExistingAndConnect(
    String tunnelId,
  ) async {
    final tunnel = _tunnels.firstWhere((t) => t.id == tunnelId);

    try {
      // First, find and kill any existing SSH tunnel on this port
      final existingTunnel = await findExistingTunnelProcess(tunnel.localPort);
      if (existingTunnel != null) {
        debugPrint('Killing existing SSH tunnel (PID: ${existingTunnel.pid})');
        final killSuccess = await killExistingSSHTunnel(existingTunnel.pid);

        if (!killSuccess) {
          return TunnelConnectionResult(
            success: false,
            errorMessage:
                'Failed to kill existing SSH tunnel (PID: ${existingTunnel.pid}). You may need to kill it manually.',
          );
        }

        // Wait a moment for the port to become available
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify the port is now available
        final portStatus = await checkPortStatus(tunnel.localPort);
        if (!portStatus.isAvailable) {
          return TunnelConnectionResult(
            success: false,
            errorMessage:
                'Port ${tunnel.localPort} is still in use after killing existing tunnel. Please try again or choose a different port.',
          );
        }
      }

      // Now connect the new tunnel
      return await connectTunnel(tunnelId);
    } catch (e) {
      return TunnelConnectionResult(
        success: false,
        errorMessage: 'Error during disconnect and connect operation: $e',
      );
    }
  }

  Future<File> _getConfigFile() async {
    final configDir = await _getConfigDirectory();
    return File('${configDir.path}/tunnels.yaml');
  }

  /// Get the configuration directory, creating it if it doesn't exist
  Future<Directory> _getConfigDirectory() async {
    try {
      // First try ~/Documents/tunstun
      final documentsDir = await getApplicationDocumentsDirectory();
      final tunstunDir = Directory('${documentsDir.path}/tunstun');

      // Create the tunstun directory if it doesn't exist
      if (!await tunstunDir.exists()) {
        await tunstunDir.create(recursive: true);
        debugPrint('Created configuration directory: ${tunstunDir.path}');
      }

      return tunstunDir;
    } catch (e) {
      // Fallback to ~/tunstun if Documents directory is not accessible
      debugPrint(
        'Documents directory not accessible ($e), using home directory fallback',
      );

      final homeDir = Directory(Platform.environment['HOME'] ?? '/home');
      final tunstunDir = Directory('${homeDir.path}/tunstun');

      // Create the tunstun directory if it doesn't exist
      if (!await tunstunDir.exists()) {
        await tunstunDir.create(recursive: true);
        debugPrint(
          'Created fallback configuration directory: ${tunstunDir.path}',
        );
      }

      return tunstunDir;
    }
  }

  Future<bool> _isPortInUse(int port) async {
    try {
      final socket = await ServerSocket.bind('127.0.0.1', port);
      await socket.close();
      return false;
    } catch (e) {
      return true;
    }
  }

  // Public method to check if a port is in use (for UI indicators)
  Future<bool> isPortInUse(int port) async {
    return await _isPortInUse(port);
  }

  // Check if there's an existing tunnel process (SSH or socat) using the port
  Future<ExistingTunnelInfo?> findExistingTunnelProcess(int localPort) async {
    try {
      // Look for SSH processes with port forwarding to this local port
      final result = await Process.run('ps', ['aux']);

      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          // Look for SSH processes with -L port forwarding
          if (line.contains('ssh') &&
              line.contains('-L') &&
              line.contains('$localPort:')) {
            // Extract PID from ps output (second column)
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final pid = int.tryParse(parts[1]);
              if (pid != null) {
                return ExistingTunnelInfo(
                  pid: pid,
                  commandLine: line,
                  localPort: localPort,
                );
              }
            }
          }
          // Also look for socat processes listening on this port (for localhost SSH hosts)
          else if (line.contains('socat') &&
              line.contains('TCP-LISTEN:$localPort')) {
            // Extract PID from ps output (second column)
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final pid = int.tryParse(parts[1]);
              if (pid != null) {
                return ExistingTunnelInfo(
                  pid: pid,
                  commandLine: line,
                  localPort: localPort,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for existing SSH tunnels: $e');
    }

    return null;
  }

  // Kill an existing SSH tunnel by PID
  Future<bool> killExistingSSHTunnel(int pid) async {
    try {
      final result = await Process.run('kill', [pid.toString()]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Error killing existing SSH tunnel (PID: $pid): $e');
      return false;
    }
  }

  // Enhanced port check that provides detailed information
  Future<PortStatus> checkPortStatus(int port) async {
    // First check if port is available
    final isInUse = await _isPortInUse(port);
    if (!isInUse) {
      return PortStatus(isAvailable: true, existingTunnel: null);
    }

    // Port is in use, check if it's an SSH tunnel or socat process
    final existingTunnel = await findExistingTunnelProcess(port);

    return PortStatus(isAvailable: false, existingTunnel: existingTunnel);
  }

  Future<TunnelConnectionResult> _testSSHConnection(TunnelConfig tunnel) async {
    try {
      // Test basic SSH connectivity with a quick command
      final testCommand = [
        'ssh',
        '-o', 'ConnectTimeout=5',
        '-o', 'BatchMode=yes', // Don't prompt for passwords
        '-o', 'StrictHostKeyChecking=no',
        tunnel.connectionString,
        'exit', // Just exit immediately
      ];

      final result = await Process.run(
        testCommand.first,
        testCommand.skip(1).toList(),
      ).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0) {
        return TunnelConnectionResult(success: true);
      } else {
        final errorMessage = 'SSH connection failed: ${result.stderr}';
        return TunnelConnectionResult(
          success: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      final errorMessage = 'SSH connection test failed: $e';
      return TunnelConnectionResult(success: false, errorMessage: errorMessage);
    }
  }

  String _convertToYaml(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('tunnels:');

    final tunnelsList = data['tunnels'] as List;
    if (tunnelsList.isEmpty) {
      // For empty lists, just leave the line empty but properly formatted
      return buffer.toString();
    }

    for (final tunnel in tunnelsList) {
      buffer.writeln('  - id: "${tunnel['id']}"');
      buffer.writeln('    name: "${tunnel['name']}"');
      buffer.writeln('    remoteHost: "${tunnel['remoteHost']}"');
      buffer.writeln('    remotePort: ${tunnel['remotePort']}');
      buffer.writeln('    sshUser: "${tunnel['sshUser']}"');
      buffer.writeln('    sshHost: "${tunnel['sshHost']}"');
      buffer.writeln('    localPort: ${tunnel['localPort']}');
      buffer.writeln('    isConnected: ${tunnel['isConnected']}');
    }

    return buffer.toString();
  }

  void _updateSystemTray() {
    final activeTunnels = _tunnels.where((t) => t.isConnected).length;
    final tooltip = activeTunnels > 0
        ? 'Tunstun - $activeTunnels active tunnel${activeTunnels == 1 ? '' : 's'}'
        : 'Tunstun - No active tunnels';

    SystemTrayService().updateTooltip(tooltip);
  }

  // Validate that tunnels marked as connected actually have running SSH processes
  Future<void> _validateTunnelStates() async {
    bool stateChanged = false;

    for (final tunnel in _tunnels) {
      if (tunnel.isConnected) {
        // Check if there's actually a tunnel process for this tunnel
        final existingTunnel = await findExistingTunnelProcess(
          tunnel.localPort,
        );

        if (existingTunnel == null) {
          // No tunnel process found, mark as disconnected
          debugPrint(
            'Tunnel "${tunnel.name}" was marked connected but no tunnel process found. Marking as disconnected.',
          );
          tunnel.isConnected = false;
          stateChanged = true;
        } else {
          // SSH process found, verify it matches our expected configuration
          debugPrint(
            'Validated tunnel "${tunnel.name}" - SSH process found (PID: ${existingTunnel.pid})',
          );
        }
      }
    }

    // Save the corrected states if any changes were made
    if (stateChanged) {
      await saveTunnels();
      debugPrint('Updated tunnel states after validation');
    }
  }

  /// Export current tunnels to a custom YAML file
  Future<bool> exportToFile(String filePath) async {
    try {
      final file = File(filePath);
      final data = {
        'tunnels': _tunnels.map((tunnel) => tunnel.toJson()).toList(),
      };

      final yamlString = _convertToYaml(data);
      await file.writeAsString(yamlString);

      debugPrint('Exported ${_tunnels.length} tunnels to: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error exporting tunnels to file: $e');
      return false;
    }
  }

  /// Load tunnels from a custom YAML file (replaces current tunnels)
  Future<bool> loadFromFile(
    String filePath, {
    bool mergeWithCurrent = false,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('Configuration file does not exist: $filePath');
        return false;
      }

      final content = await file.readAsString();
      final yamlData = loadYaml(content);

      // Accept files with 'tunnels' key, even if the value is null or empty list
      if (yamlData is Map && yamlData.containsKey('tunnels')) {
        final tunnelsData = yamlData['tunnels'];
        final loadedTunnels = <TunnelConfig>[];

        // Handle the case where tunnels is a list (including empty list)
        if (tunnelsData is List) {
          for (final tunnelData in tunnelsData) {
            if (tunnelData is Map) {
              final tunnel = TunnelConfig.fromJson(
                Map<String, dynamic>.from(tunnelData),
              );
              loadedTunnels.add(tunnel);
            }
          }
        } else if (tunnelsData == null) {
          // Handle case where tunnels: with no value (treated as empty list)
          debugPrint(
            'Found tunnels key with null value, treating as empty list',
          );
        } else {
          // Invalid format - tunnels should be a list or null
          debugPrint(
            'Invalid YAML format in file: $filePath - tunnels must be a list',
          );
          return false;
        }

        if (!mergeWithCurrent) {
          // Disconnect all current tunnels before replacing
          await disconnectAllTunnels();
          _tunnels.clear();
        }

        // Add loaded tunnels (may be empty)
        _tunnels.addAll(loadedTunnels);
        _currentConfigurationFile = filePath;

        // Validate connection states
        await _validateTunnelStates();

        notifyListeners();
        _updateSystemTray();

        debugPrint('Loaded ${loadedTunnels.length} tunnels from: $filePath');
        return true;
      } else {
        debugPrint(
          'Invalid YAML format in file: $filePath - missing tunnels key',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error loading tunnels from file: $e');
      return false;
    }
  }

  /// Save current tunnels to a custom file (updates current configuration file)
  Future<bool> saveToFile(String filePath) async {
    try {
      final success = await exportToFile(filePath);
      if (success) {
        _currentConfigurationFile = filePath;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error saving to file: $e');
      return false;
    }
  }

  /// Clear current configuration (disconnect all tunnels and clear list)
  Future<void> clearCurrentConfiguration() async {
    await disconnectAllTunnels();
    _tunnels.clear();
    _currentConfigurationFile = null;
    notifyListeners();
    _updateSystemTray();
    debugPrint('Cleared current configuration');
  }

  /// Create a new configuration (clear current and reset to default file)
  Future<void> newConfiguration() async {
    await clearCurrentConfiguration();
    _currentConfigurationFile = null;
    await saveTunnels(); // Save empty configuration to default file
    debugPrint('Created new configuration');
  }

  /// Get a list of tunnel configuration files in the configuration directory
  Future<List<String>> getAvailableConfigurationFiles() async {
    try {
      final configDir = await _getConfigDirectory();

      if (!await configDir.exists()) {
        return [];
      }

      final files = await configDir
          .list()
          .where(
            (entity) =>
                entity is File && entity.path.toLowerCase().endsWith('.yaml') ||
                entity.path.toLowerCase().endsWith('.yml'),
          )
          .cast<File>()
          .map((file) => file.path)
          .toList();

      return files;
    } catch (e) {
      debugPrint('Error getting configuration files: $e');
      return [];
    }
  }

  /// Validate if a file contains valid tunnel configuration
  Future<bool> isValidConfigurationFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final content = await file.readAsString();
      final yamlData = loadYaml(content);

      // Accept files with 'tunnels' key, even if the value is null or empty list
      if (yamlData is Map && yamlData.containsKey('tunnels')) {
        final tunnelsData = yamlData['tunnels'];
        // Valid if tunnels is null, empty list, or non-empty list
        return tunnelsData == null || tunnelsData is List;
      }

      return false;
    } catch (e) {
      debugPrint('Error validating configuration file: $e');
      return false;
    }
  }

  /// Get information about a configuration file without loading it
  Future<Map<String, dynamic>?> getConfigurationFileInfo(
    String filePath,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final yamlData = loadYaml(content);

      if (yamlData is Map && yamlData.containsKey('tunnels')) {
        final tunnelsData = yamlData['tunnels'];
        final tunnelCount = (tunnelsData is List) ? tunnelsData.length : 0;
        final stat = await file.stat();

        return {
          'fileName': file.path.split('/').last,
          'filePath': filePath,
          'tunnelCount': tunnelCount,
          'lastModified': stat.modified,
          'size': stat.size,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting configuration file info: $e');
      return null;
    }
  }
}
