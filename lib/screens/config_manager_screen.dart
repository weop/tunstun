import 'package:flutter/material.dart';
import 'dart:io';
import '../services/tunnel_service.dart';
import '../widgets/flutter_file_picker.dart';

class ConfigManagerScreen extends StatefulWidget {
  final TunnelService tunnelService;

  const ConfigManagerScreen({super.key, required this.tunnelService});

  @override
  State<ConfigManagerScreen> createState() => _ConfigManagerScreenState();
}

class _ConfigManagerScreenState extends State<ConfigManagerScreen> {
  List<Map<String, dynamic>> _availableConfigs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableConfigs();
  }

  Future<void> _loadAvailableConfigs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final configFiles = await widget.tunnelService
          .getAvailableConfigurationFiles();
      final configs = <Map<String, dynamic>>[];

      for (final filePath in configFiles) {
        final info = await widget.tunnelService.getConfigurationFileInfo(
          filePath,
        );
        if (info != null) {
          configs.add(info);
        }
      }

      setState(() {
        _availableConfigs = configs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _showErrorSnackBar('Error loading configuration files: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableConfigs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton.icon(
                  onPressed: _newConfiguration,
                  icon: const Icon(Icons.add),
                  label: const Text('New Configuration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openConfiguration,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _saveConfiguration,
                  icon: const Icon(Icons.save),
                  label: const Text('Save As'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _exportConfiguration,
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export Current'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Current configuration info
          if (widget.tunnelService.currentConfigurationFile != null)
            Card(
              margin: const EdgeInsets.all(16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Configuration:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.tunnelService.currentConfigurationFile!
                                .split('/')
                                .last,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${widget.tunnelService.tunnels.length} tunnels',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Available configurations list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _availableConfigs.isEmpty
                ? const Center(
                    child: Text(
                      'No configuration files found in the tunstun directory.\nUse "Open File" to browse for YAML files.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _availableConfigs.length,
                    itemBuilder: (context, index) {
                      final config = _availableConfigs[index];
                      final isCurrentFile =
                          widget.tunnelService.currentConfigurationFile ==
                          config['filePath'];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        color: isCurrentFile
                            ? Colors.blue.withOpacity(0.1)
                            : null,
                        child: ListTile(
                          leading: Icon(
                            Icons.description,
                            color: isCurrentFile ? Colors.blue : Colors.grey,
                          ),
                          title: Text(
                            config['fileName'],
                            style: TextStyle(
                              fontWeight: isCurrentFile
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${config['tunnelCount']} tunnels'),
                              Text(
                                'Modified: ${_formatDate(config['lastModified'])}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) =>
                                _handleConfigAction(value, config),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'load',
                                child: ListTile(
                                  leading: Icon(Icons.folder_open),
                                  title: Text('Load'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'merge',
                                child: ListTile(
                                  leading: Icon(Icons.merge_type),
                                  title: Text('Merge'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  title: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _loadConfiguration(config['filePath']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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
          Navigator.of(context).pop();
          _showSuccessSnackBar('New configuration created');
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error creating new configuration: $e');
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
        await _loadConfiguration(filePath);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error opening file: $e');
      }
    }
  }

  Future<void> _loadConfiguration(String filePath) async {
    try {
      final success = await widget.tunnelService.loadFromFile(filePath);
      if (success && mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar('Configuration loaded successfully');
      } else if (mounted) {
        _showErrorSnackBar('Failed to load configuration file');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error loading configuration: $e');
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
          _showSuccessSnackBar('Configuration saved successfully');
          _loadAvailableConfigs();
        } else if (mounted) {
          _showErrorSnackBar('Failed to save configuration');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error saving configuration: $e');
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
          _showSuccessSnackBar('Configuration exported successfully');
          _loadAvailableConfigs();
        } else if (mounted) {
          _showErrorSnackBar('Failed to export configuration');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error exporting configuration: $e');
      }
    }
  }

  Future<void> _handleConfigAction(
    String action,
    Map<String, dynamic> config,
  ) async {
    switch (action) {
      case 'load':
        await _loadConfiguration(config['filePath']);
        break;
      case 'merge':
        await _mergeConfiguration(config['filePath']);
        break;
      case 'delete':
        await _deleteConfiguration(config);
        break;
    }
  }

  Future<void> _mergeConfiguration(String filePath) async {
    try {
      final success = await widget.tunnelService.loadFromFile(
        filePath,
        mergeWithCurrent: true,
      );
      if (success && mounted) {
        _showSuccessSnackBar('Configuration merged successfully');
      } else if (mounted) {
        _showErrorSnackBar('Failed to merge configuration');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error merging configuration: $e');
      }
    }
  }

  Future<void> _deleteConfiguration(Map<String, dynamic> config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Configuration'),
        content: Text(
          'Delete "${config['fileName']}"?\nThis action cannot be undone.',
        ),
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
        final file = File(config['filePath']);
        await file.delete();
        if (mounted) {
          _showSuccessSnackBar('Configuration file deleted');
          _loadAvailableConfigs();
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error deleting file: $e');
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
