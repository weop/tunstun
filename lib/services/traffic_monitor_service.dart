import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service for monitoring network traffic through SSH tunnels
/// Provides traffic data for dynamic animation based on actual usage
class TrafficMonitorService extends ChangeNotifier {
  final Map<int, TrafficStats> _portTrafficStats = {};
  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  // Traffic monitoring configuration
  static const Duration _monitoringInterval = Duration(seconds: 2);
  static const int _historySize = 30; // Keep 30 readings for averaging

  /// Get traffic statistics for a specific port
  TrafficStats? getTrafficStats(int port) {
    return _portTrafficStats[port];
  }

  /// Start monitoring traffic for specified ports
  Future<void> startMonitoring(List<int> ports) async {
    if (_isMonitoring) return;

    _isMonitoring = true;

    // Initialize stats for all ports
    for (final port in ports) {
      _portTrafficStats[port] = TrafficStats();
    }

    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) {
      _updateTrafficStats(ports);
    });

    debugPrint('Traffic monitoring started for ports: $ports');
  }

  /// Stop traffic monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    _portTrafficStats.clear();
    notifyListeners();
    debugPrint('Traffic monitoring stopped');
  }

  /// Update traffic statistics for monitored ports
  Future<void> _updateTrafficStats(List<int> ports) async {
    try {
      // Monitor using netstat to get connection counts and states
      final result = await Process.run('netstat', ['-tn']);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        _parseNetstatOutput(output, ports);
      } else {
        debugPrint('netstat failed with exit code: ${result.exitCode}');
      }
    } catch (e) {
      debugPrint('Error monitoring traffic: $e');
    }
  }

  /// Parse netstat output to extract traffic information
  void _parseNetstatOutput(String output, List<int> ports) {
    final now = DateTime.now();

    for (final port in ports) {
      final stats = _portTrafficStats[port];
      if (stats == null) continue;

      // Count active connections on this port
      int activeConnections = 0;
      int establishedConnections = 0;

      final lines = output.split('\n');
      for (final line in lines) {
        if (line.contains(':$port ')) {
          activeConnections++;
          if (line.contains('ESTABLISHED')) {
            establishedConnections++;
          }
        }
      }

      // Update statistics
      stats._updateConnections(activeConnections, establishedConnections, now);

      // Debug output for traffic monitoring
      if (activeConnections > 0 || establishedConnections > 0) {
        debugPrint(
          'Port $port: active=$activeConnections, established=$establishedConnections',
        );
      }
    }

    notifyListeners();
  }

  /// Get animation intensity based on traffic (0.0 to 1.0)
  double getAnimationIntensity(int port) {
    final stats = getTrafficStats(port);
    if (stats == null) return 0.1; // Minimal animation if no stats

    return stats.getAnimationIntensity();
  }

  /// Check if a port has recent activity
  bool hasRecentActivity(int port) {
    final stats = getTrafficStats(port);
    if (stats == null) return false;

    return stats.hasRecentActivity();
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

/// Traffic statistics for a specific port
class TrafficStats {
  final List<TrafficReading> _readings = [];
  DateTime? _lastUpdate;

  /// Add a new traffic reading
  void _updateConnections(int active, int established, DateTime timestamp) {
    _readings.add(
      TrafficReading(
        timestamp: timestamp,
        activeConnections: active,
        establishedConnections: established,
      ),
    );

    // Keep only recent readings
    while (_readings.length > TrafficMonitorService._historySize) {
      _readings.removeAt(0);
    }

    _lastUpdate = timestamp;
  }

  /// Get average active connections over recent period
  double get averageActiveConnections {
    if (_readings.isEmpty) return 0.0;

    final sum = _readings.fold<int>(
      0,
      (sum, reading) => sum + reading.activeConnections,
    );
    return sum / _readings.length;
  }

  /// Get average established connections over recent period
  double get averageEstablishedConnections {
    if (_readings.isEmpty) return 0.0;

    final sum = _readings.fold<int>(
      0,
      (sum, reading) => sum + reading.establishedConnections,
    );
    return sum / _readings.length;
  }

  /// Get current active connections
  int get currentActiveConnections {
    return _readings.isEmpty ? 0 : _readings.last.activeConnections;
  }

  /// Get current established connections
  int get currentEstablishedConnections {
    return _readings.isEmpty ? 0 : _readings.last.establishedConnections;
  }

  /// Calculate animation intensity based on traffic patterns
  double getAnimationIntensity() {
    if (_readings.isEmpty) return 0.1; // Minimal animation

    // Base intensity on established connections
    final established = currentEstablishedConnections;
    final active = currentActiveConnections;

    if (established == 0 && active == 0) {
      return 0.1; // Minimal idle animation
    }

    // Calculate intensity: more connections = faster animation
    // Range from 0.1 (idle) to 1.0 (heavy traffic)
    final connectionFactor = (established * 0.7 + active * 0.3) / 10.0;
    return (0.1 + connectionFactor).clamp(0.1, 1.0);
  }

  /// Check if there's been recent activity (within last 10 seconds)
  bool hasRecentActivity() {
    if (_lastUpdate == null) return false;

    final timeSinceUpdate = DateTime.now().difference(_lastUpdate!);
    return timeSinceUpdate.inSeconds < 10 && currentEstablishedConnections > 0;
  }

  /// Get traffic trend (increasing, decreasing, stable)
  TrafficTrend getTrafficTrend() {
    if (_readings.length < 3) return TrafficTrend.stable;

    final recent = _readings.takeLast(3).toList();
    final oldest = recent.first.establishedConnections;
    final newest = recent.last.establishedConnections;

    if (newest > oldest + 1) return TrafficTrend.increasing;
    if (newest < oldest - 1) return TrafficTrend.decreasing;
    return TrafficTrend.stable;
  }
}

/// Individual traffic reading at a point in time
class TrafficReading {
  final DateTime timestamp;
  final int activeConnections;
  final int establishedConnections;

  TrafficReading({
    required this.timestamp,
    required this.activeConnections,
    required this.establishedConnections,
  });
}

/// Traffic trend indicators
enum TrafficTrend { increasing, decreasing, stable }

/// Extension to get last N elements from a list
extension ListExtensions<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}
