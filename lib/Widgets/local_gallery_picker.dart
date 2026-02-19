import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

/// LocalGalleryPicker is a dialog widget that displays all locally saved media
/// This includes images and videos captured or downloaded through the app
/// Users can select multiple items to add to a post
class LocalGalleryPicker extends StatefulWidget {
  /// Callback when user completes selection
  /// Returns list of selected XFile objects
  final Function(List<XFile>) onSelectionComplete;

  const LocalGalleryPicker({
    super.key,
    required this.onSelectionComplete,
  });

  @override
  State<LocalGalleryPicker> createState() => _LocalGalleryPickerState();
}

class _LocalGalleryPickerState extends State<LocalGalleryPicker> {
  // ========== STATE VARIABLES ==========
  /// List of all media files in the local gallery
  List<File> _galleryFiles = [];

  /// Set of selected file paths (for quick lookup of selected items)
  final Set<String> _selectedPaths = {};

  /// Whether the gallery is currently loading from storage
  bool _isLoading = true;

  /// Error message if gallery couldn't load
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load gallery files when widget initializes
    _loadGalleryFiles();
  }

  /// Loads all media files from the app's local gallery directory
  /// The gallery directory is at: documents/atlas_gallery
  /// Sorts files by modification time (newest first)
  Future<void> _loadGalleryFiles() async {
    try {
      setState(() => _isLoading = true);

      // Get the app's documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final galleryDir = Directory('${appDir.path}/atlas_gallery');

      // Check if gallery directory exists
      if (!await galleryDir.exists()) {
        setState(() {
          _galleryFiles = [];
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }

      // List all files in the gallery directory
      final files = galleryDir
          .listSync()
          .whereType<File>()
          .map((entity) => File(entity.path))
          .toList();

      // Sort by modification time (newest first)
      files.sort((a, b) {
        final aTime = a.lastModifiedSync();
        final bTime = b.lastModifiedSync();
        return bTime.compareTo(aTime);
      });

      setState(() {
        _galleryFiles = files;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading gallery: $e';
      });
    }
  }

  /// Converts selected file paths to XFile objects
  /// XFile is used for compatibility with image_picker
  List<XFile> _getSelectedXFiles() {
    return _selectedPaths
        .map((path) => XFile(path))
        .toList();
  }

  /// Checks if a file is an image based on its extension
  bool _isImage(String filePath) {
    final ext = filePath.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif');
  }

  /// Gets a thumbnail widget for displaying the media
  /// Shows different widgets for images vs videos
  Widget _buildMediaThumbnail(File file) {
    final fileName = file.path.split('/').last;
    final isImage = _isImage(fileName);

    if (isImage) {
      // Display image thumbnail
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported),
          );
        },
      );
    } else {
      // Display video thumbnail with play icon
      return Container(
        color: Colors.grey[800],
        child: const Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 40,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select from Saved Media'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // Done button - only enabled if something is selected
            if (_selectedPaths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      // Return selected files
                      widget.onSelectionComplete(_getSelectedXFiles());
                    },
                    icon: const Icon(Icons.check),
                    label: Text(
                      'Add (${_selectedPaths.length})',
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(_errorMessage!),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadGalleryFiles,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _galleryFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No saved media yet',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Take photos or videos to see them here',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : // Grid of media thumbnails
                    GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _galleryFiles.length,
                        itemBuilder: (context, index) {
                          final file = _galleryFiles[index];
                          final isSelected = _selectedPaths.contains(file.path);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                // Toggle selection
                                if (isSelected) {
                                  _selectedPaths.remove(file.path);
                                } else {
                                  _selectedPaths.add(file.path);
                                }
                              });
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Media thumbnail
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.blue,
                                            width: 3,
                                          )
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildMediaThumbnail(file),
                                  ),
                                ),
                                // Selection overlay
                                if (isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.blue,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
