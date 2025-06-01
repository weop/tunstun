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
        title: const Text('New Tunnel'),
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
                          'New Tunnel Configuration',
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
                              onPressed: _saveTunnel,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Save Tunnel'),
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
