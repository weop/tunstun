import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FlutterFilePicker {
  static Future<String?> pickFile({
    required BuildContext context,
    String title = 'Select File',
    List<String> allowedExtensions = const ['yaml', 'yml'],
  }) async {
    return await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => FilePickerScreen(
          title: title,
          allowedExtensions: allowedExtensions,
          mode: FilePickerMode.open,
        ),
      ),
    );
  }

  static Future<String?> saveFile({
    required BuildContext context,
    String title = 'Save File',
    String fileName = 'tunnels.yaml',
    List<String> allowedExtensions = const ['yaml', 'yml'],
  }) async {
    return await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => FilePickerScreen(
          title: title,
          allowedExtensions: allowedExtensions,
          mode: FilePickerMode.save,
          defaultFileName: fileName,
        ),
      ),
    );
  }
}

enum FilePickerMode { open, save }

class FilePickerScreen extends StatefulWidget {
  final String title;
  final List<String> allowedExtensions;
  final FilePickerMode mode;
  final String? defaultFileName;

  const FilePickerScreen({
    super.key,
    required this.title,
    required this.allowedExtensions,
    required this.mode,
    this.defaultFileName,
  });

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  Directory? _currentDirectory;
  List<FileSystemEntity> _entities = [];
  bool _isLoading = true;
  final TextEditingController _fileNameController = TextEditingController();
  String? _selectedFilePath;

  @override
  void initState() {
    super.initState();
    if (widget.mode == FilePickerMode.save && widget.defaultFileName != null) {
      _fileNameController.text = widget.defaultFileName!;
    }
    _loadInitialDirectory();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialDirectory() async {
    try {
      // Start with tunstun configuration directory, fallback to documents, then home
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final tunstunDir = Directory('${documentsDir.path}/tunstun');
        if (await tunstunDir.exists()) {
          await _navigateToDirectory(tunstunDir);
          return;
        }
      } catch (e) {
        // Documents not accessible, try home/tunstun
        final homeDir = Directory(Platform.environment['HOME'] ?? '/home');
        final tunstunDir = Directory('${homeDir.path}/tunstun');
        if (await tunstunDir.exists()) {
          await _navigateToDirectory(tunstunDir);
          return;
        }
      }

      // Fallback to Documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      await _navigateToDirectory(documentsDir);
    } catch (e) {
      // Final fallback to home directory
      final homeDir = Directory(Platform.environment['HOME'] ?? '/home');
      await _navigateToDirectory(homeDir);
    }
  }

  Future<void> _navigateToDirectory(Directory directory) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final entities = await directory.list().toList();

      // Sort: directories first, then files, alphabetically
      entities.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      setState(() {
        _currentDirectory = directory;
        _entities = entities;
        _isLoading = false;
        _selectedFilePath = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing directory: $e')),
        );
      }
    }
  }

  bool _isFileAllowed(String fileName) {
    if (widget.allowedExtensions.isEmpty) return true;

    final extension = fileName.toLowerCase().split('.').last;
    return widget.allowedExtensions.contains(extension);
  }

  void _selectFile(File file) {
    if (!_isFileAllowed(file.path.split('/').last)) return;

    setState(() {
      _selectedFilePath = file.path;
      if (widget.mode == FilePickerMode.save) {
        _fileNameController.text = file.path.split('/').last;
      }
    });
  }

  void _confirmSelection() {
    if (widget.mode == FilePickerMode.open) {
      if (_selectedFilePath != null) {
        Navigator.of(context).pop(_selectedFilePath);
      }
    } else {
      // Save mode
      final fileName = _fileNameController.text.trim();
      if (fileName.isNotEmpty) {
        final filePath = '${_currentDirectory!.path}/$fileName';
        Navigator.of(context).pop(filePath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          // Current path bar
          Container(
            padding: const EdgeInsets.all(8.0),
            color: colorScheme.surfaceVariant,
            child: Row(
              children: [
                Icon(Icons.folder, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentDirectory?.path ?? 'Loading...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Home button
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () async {
                    final homeDir = Directory(
                      Platform.environment['HOME'] ?? '/home',
                    );
                    await _navigateToDirectory(homeDir);
                  },
                  tooltip: 'Home',
                ),
                // Tunstun directory button
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () async {
                    try {
                      // Try Documents/tunstun first
                      try {
                        final documentsDir =
                            await getApplicationDocumentsDirectory();
                        final tunstunDir = Directory(
                          '${documentsDir.path}/tunstun',
                        );
                        if (await tunstunDir.exists()) {
                          await _navigateToDirectory(tunstunDir);
                          return;
                        }
                      } catch (e) {
                        // Fallback to home/tunstun
                        final homeDir = Directory(
                          Platform.environment['HOME'] ?? '/home',
                        );
                        final tunstunDir = Directory('${homeDir.path}/tunstun');
                        if (await tunstunDir.exists()) {
                          await _navigateToDirectory(tunstunDir);
                          return;
                        }
                      }

                      // If tunstun directory doesn't exist, show error
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tunstun configuration directory not found',
                          ),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cannot access tunstun directory: $e'),
                        ),
                      );
                    }
                  },
                  tooltip: 'Tunstun Config',
                ),
                // Documents button
                IconButton(
                  icon: const Icon(Icons.description),
                  onPressed: () async {
                    try {
                      final documentsDir =
                          await getApplicationDocumentsDirectory();
                      await _navigateToDirectory(documentsDir);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Cannot access Documents: $e')),
                      );
                    }
                  },
                  tooltip: 'Documents',
                ),
              ],
            ),
          ),

          // File list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount:
                        _entities.length +
                        (_currentDirectory?.parent != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Parent directory entry
                      if (_currentDirectory?.parent != null && index == 0) {
                        return ListTile(
                          leading: Icon(
                            Icons.arrow_upward,
                            color: colorScheme.secondary,
                          ),
                          title: Text('..', style: theme.textTheme.bodyLarge),
                          subtitle: Text(
                            'Parent directory',
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () =>
                              _navigateToDirectory(_currentDirectory!.parent!),
                        );
                      }

                      final actualIndex = _currentDirectory?.parent != null
                          ? index - 1
                          : index;
                      final entity = _entities[actualIndex];
                      final isDirectory = entity is Directory;
                      final fileName = entity.path.split('/').last;
                      final isAllowed = isDirectory || _isFileAllowed(fileName);
                      final isSelected =
                          !isDirectory && _selectedFilePath == entity.path;

                      return ListTile(
                        leading: Icon(
                          isDirectory ? Icons.folder : Icons.description,
                          color: isDirectory
                              ? colorScheme.primary
                              : isAllowed
                              ? colorScheme.secondary
                              : colorScheme.outline,
                        ),
                        title: Text(
                          fileName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isAllowed
                                ? colorScheme.onSurface
                                : colorScheme.outline,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          isDirectory
                              ? 'Directory'
                              : _getFileSize(entity as File),
                          style: theme.textTheme.bodySmall,
                        ),
                        selected: isSelected,
                        selectedTileColor: colorScheme.primaryContainer
                            .withOpacity(0.3),
                        onTap: isDirectory
                            ? () => _navigateToDirectory(entity as Directory)
                            : isAllowed
                            ? () => _selectFile(entity as File)
                            : null,
                      );
                    },
                  ),
          ),

          // Save mode: filename input
          if (widget.mode == FilePickerMode.save)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  Text('File name: ', style: theme.textTheme.bodyMedium),
                  Expanded(
                    child: TextField(
                      controller: _fileNameController,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        isDense: true,
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.primary),
                        ),
                      ),
                      onSubmitted: (_) => _confirmSelection(),
                    ),
                  ),
                ],
              ),
            ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: widget.mode == FilePickerMode.open
                      ? (_selectedFilePath != null ? _confirmSelection : null)
                      : (_fileNameController.text.trim().isNotEmpty
                            ? _confirmSelection
                            : null),
                  child: Text(
                    widget.mode == FilePickerMode.open ? 'Open' : 'Save',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFileSize(File file) {
    try {
      final size = file.lengthSync();
      if (size < 1024) return '$size B';
      if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return 'Unknown size';
    }
  }
}
