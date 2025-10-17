import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tunnel_config.dart';
import '../services/tunnel_service.dart';

class AddTunnelScreen extends StatefulWidget {
  final TunnelService tunnelService;

  const AddTunnelScreen({super.key, required this.tunnelService});

  @override
  State<AddTunnelScreen> createState() => _AddTunnelScreenState();
}

class _AddTunnelScreenState extends State<AddTunnelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _remoteHostController = TextEditingController();
  final _remotePortController = TextEditingController();
  final _sshUserController = TextEditingController();
  final _sshHostController = TextEditingController();
  final _localPortController = TextEditingController();
  String _selectedLocalHost = '127.0.0.1';
  List<String> _availableLocalHosts = ['127.0.0.1'];

  @override
  void initState() {
    super.initState();
    _loadAvailableLocalHosts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _remoteHostController.dispose();
    _remotePortController.dispose();
    _sshUserController.dispose();
    _sshHostController.dispose();
    _localPortController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableLocalHosts() async {
    try {
      final interfaces = await NetworkInterface.list();
      final hosts = <String>{'127.0.0.1', '0.0.0.0'};

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            hosts.add(addr.address);
          }
        }
      }

      setState(() {
        _availableLocalHosts = hosts.toList()..sort();
      });
    } catch (e) {
      // Fallback to defaults if error
      setState(() {
        _availableLocalHosts = ['127.0.0.1', '0.0.0.0'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Tunnel')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Tunnel Configuration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Section 1: Tunnel Name
                        _buildSectionHeader(
                          icon: Icons.label_outline,
                          title: 'Tunnel Name',
                          subtitle: 'Give this tunnel configuration a memorable name',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            labelStyle: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : null,
                            ),
                            hintText: 'My Development Server',
                            prefixIcon: Icon(Icons.label, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[900]
                                : Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a tunnel name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Section 2: Remote Destination
                        _buildSectionHeader(
                          icon: Icons.cloud_outlined,
                          title: 'Remote Destination',
                          subtitle: 'The service you want to reach (host:port)',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Focus(
                                onFocusChange: (hasFocus) {
                                  // Auto-fill with 127.0.0.1 when field loses focus and is empty
                                  if (!hasFocus && _remoteHostController.text.isEmpty) {
                                    _remoteHostController.text = '127.0.0.1';
                                  }
                                },
                                child: TextFormField(
                                  controller: _remoteHostController,
                                  decoration: InputDecoration(
                                    labelText: 'Remote Host',
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[400]
                                          : null,
                                    ),
                                    hintText: '127.0.0.1',
                                    prefixIcon: Icon(Icons.dns, size: 20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    filled: true,
                                    fillColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[900]
                                        : Colors.grey[50],
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter remote host';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Focus(
                                onFocusChange: (hasFocus) {
                                  // Auto-fill local port when remote port field loses focus
                                  if (!hasFocus &&
                                      _localPortController.text.isEmpty &&
                                      _remotePortController.text.isNotEmpty) {
                                    _localPortController.text = _remotePortController.text;
                                  }
                                },
                                child: TextFormField(
                                  controller: _remotePortController,
                                  decoration: InputDecoration(
                                    labelText: 'Remote Port',
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[400]
                                          : null,
                                    ),
                                    hintText: '80',
                                    prefixIcon: Icon(
                                      Icons.settings_ethernet,
                                      size: 20,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    filled: true,
                                    fillColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[900]
                                        : Colors.grey[50],
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    final port = int.tryParse(value);
                                    if (port == null ||
                                        port < 1 ||
                                        port > 65535) {
                                      return 'Invalid port';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildConnectionIndicator('VIA'),

                        // Section 3: SSH Jump Host
                        _buildSectionHeader(
                          icon: Icons.vpn_key_outlined,
                          title: 'SSH Jump Host',
                          subtitle: 'Server that creates the secure tunnel',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Focus(
                                onFocusChange: (hasFocus) {
                                  // Auto-fill with 'root' when field loses focus and is empty
                                  if (!hasFocus && _sshUserController.text.isEmpty) {
                                    _sshUserController.text = 'root';
                                  }
                                },
                                child: TextFormField(
                                  controller: _sshUserController,
                                  decoration: InputDecoration(
                                    labelText: 'SSH User',
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[400]
                                          : null,
                                    ),
                                    hintText: 'root',
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      size: 20,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    filled: true,
                                    fillColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[900]
                                        : Colors.grey[50],
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter SSH user';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _sshHostController,
                                decoration: InputDecoration(
                                  labelText: 'SSH Host',
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[400]
                                        : null,
                                  ),
                                  hintText: 'ssh-server',
                                  prefixIcon: Icon(Icons.computer, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[900]
                                      : Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter SSH host';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildConnectionIndicator('TUNNELS TO'),

                        // Section 4: Local Access Point
                        _buildSectionHeader(
                          icon: Icons.router_outlined,
                          title: 'Local Access Point',
                          subtitle: 'Access the remote service on localhost:PORT',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedLocalHost,
                                decoration: InputDecoration(
                                  labelText: 'Local Host',
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[400]
                                        : null,
                                  ),
                                  prefixIcon: Icon(Icons.computer, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[900]
                                      : Colors.grey[50],
                                ),
                                items: _availableLocalHosts.map((host) {
                                  String label = host;
                                  if (host == '127.0.0.1') {
                                    label = '127.0.0.1 (localhost)';
                                  } else if (host == '0.0.0.0') {
                                    label = '0.0.0.0 (all interfaces)';
                                  }
                                  return DropdownMenuItem(
                                    value: host,
                                    child: Text(label),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedLocalHost = value ?? '127.0.0.1';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _localPortController,
                                decoration: InputDecoration(
                                  labelText: 'Local Port',
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[400]
                                        : null,
                                  ),
                                  hintText: '8080',
                                  prefixIcon: Icon(Icons.router, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[900]
                                      : Colors.grey[50],
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  final port = int.tryParse(value);
                                  if (port == null || port < 1 || port > 65535) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[800]
                                      : null,
                                  foregroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[300]
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: _testConnection,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.orange[800]
                                      : Colors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Test Connection'),
                              ),
                              ElevatedButton(
                                onPressed: _saveTunnel,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.blue[700]
                                      : Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Save Tunnel'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? Colors.blue[300] : Theme.of(context).primaryColor;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: headerColor!.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: headerColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: headerColor,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionIndicator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              thickness: 1.5,
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_vert,
                    size: 16,
                    color: Theme.of(context).primaryColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).primaryColor.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1.5,
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  void _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Create a temporary tunnel config for testing
    final testTunnel = TunnelConfig(
      id: 'test-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      remoteHost: _remoteHostController.text.trim(),
      remotePort: int.parse(_remotePortController.text.trim()),
      sshUser: _sshUserController.text.trim(),
      sshHost: _sshHostController.text.trim(),
      localPort: int.parse(_localPortController.text.trim()),
      localHost: _selectedLocalHost,
    );

    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('Testing connection...'),
          ],
        ),
      ),
    );

    try {
      // Add tunnel temporarily
      await widget.tunnelService.addTunnel(testTunnel);

      // Try to connect
      final result = await widget.tunnelService.connectTunnel(testTunnel.id);

      // Disconnect and remove the test tunnel
      await widget.tunnelService.disconnectTunnel(testTunnel.id);
      await widget.tunnelService.removeTunnel(testTunnel.id);

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show result
      if (result.success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text('Connection Successful'),
              ],
            ),
            content: Text('The tunnel configuration is valid and working!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Text('Connection Failed'),
              ],
            ),
            content: Text(result.errorMessage ?? 'Unknown error occurred'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Clean up test tunnel if it exists
      try {
        await widget.tunnelService.removeTunnel(testTunnel.id);
      } catch (_) {}

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Text('Test Failed'),
            ],
          ),
          content: Text('Error testing connection: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _saveTunnel() async {
    if (_formKey.currentState!.validate()) {
      final tunnel = TunnelConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        remoteHost: _remoteHostController.text.trim(),
        remotePort: int.parse(_remotePortController.text.trim()),
        sshUser: _sshUserController.text.trim(),
        sshHost: _sshHostController.text.trim(),
        localPort: int.parse(_localPortController.text.trim()),
        localHost: _selectedLocalHost,
      );

      try {
        await widget.tunnelService.addTunnel(tunnel);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tunnel saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving tunnel: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
