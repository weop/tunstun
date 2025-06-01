import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tunnel_config.dart';
import '../services/tunnel_service.dart';

class EditTunnelScreen extends StatefulWidget {
  final TunnelService tunnelService;
  final TunnelConfig tunnel;

  const EditTunnelScreen({
    super.key,
    required this.tunnelService,
    required this.tunnel,
  });

  @override
  State<EditTunnelScreen> createState() => _EditTunnelScreenState();
}

class _EditTunnelScreenState extends State<EditTunnelScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _remoteHostController;
  late final TextEditingController _remotePortController;
  late final TextEditingController _sshUserController;
  late final TextEditingController _sshHostController;
  late final TextEditingController _localPortController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing tunnel data
    _nameController = TextEditingController(text: widget.tunnel.name);
    _remoteHostController = TextEditingController(
      text: widget.tunnel.remoteHost,
    );
    _remotePortController = TextEditingController(
      text: widget.tunnel.remotePort.toString(),
    );
    _sshUserController = TextEditingController(text: widget.tunnel.sshUser);
    _sshHostController = TextEditingController(text: widget.tunnel.sshHost);
    _localPortController = TextEditingController(
      text: widget.tunnel.localPort.toString(),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Tunnel'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.indigo.shade500,
      ),
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
                          'Edit Tunnel Configuration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Tunnel Name',
                            hintText: 'My Development Server',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a tunnel name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _remoteHostController,
                                decoration: InputDecoration(
                                  labelText: 'Remote Host',
                                  hintText: '192.168.1.100',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter remote host';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _remotePortController,
                                decoration: InputDecoration(
                                  labelText: 'Remote Port',
                                  hintText: '80',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _sshUserController,
                                decoration: InputDecoration(
                                  labelText: 'SSH User',
                                  hintText: 'vi',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter SSH user';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _sshHostController,
                                decoration: InputDecoration(
                                  labelText: 'SSH Host',
                                  hintText: 'ssh-server',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
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
                        TextFormField(
                          controller: _localPortController,
                          decoration: InputDecoration(
                            labelText: 'Local Port',
                            hintText: '8080',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter local port';
                            }
                            final port = int.tryParse(value);
                            if (port == null || port < 1 || port > 65535) {
                              return 'Invalid port (1-65535)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: _updateTunnel,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Update Tunnel'),
                            ),
                          ],
                        ),
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

  void _updateTunnel() async {
    if (_formKey.currentState!.validate()) {
      final updatedTunnel = TunnelConfig(
        id: widget.tunnel.id, // Keep the same ID
        name: _nameController.text.trim(),
        remoteHost: _remoteHostController.text.trim(),
        remotePort: int.parse(_remotePortController.text.trim()),
        sshUser: _sshUserController.text.trim(),
        sshHost: _sshHostController.text.trim(),
        localPort: int.parse(_localPortController.text.trim()),
        isConnected: false, // Reset connection status after update
      );

      try {
        await widget.tunnelService.updateTunnel(updatedTunnel);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tunnel updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating tunnel: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
